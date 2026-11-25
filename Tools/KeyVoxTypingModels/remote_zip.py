"""Reads single members of a large remote ZIP archive with HTTP byte-range requests, so a
few files can be taken from an archive without downloading all of it."""

import struct
import urllib.request
import zlib
from dataclasses import dataclass

_TAIL_BYTES = 1 << 20


@dataclass(frozen=True)
class Member:
    name: str
    compression: int
    crc32: int
    compressed_size: int
    uncompressed_size: int
    local_header_offset: int


def _read_range(url: str, start: int, end: int) -> bytes:
    request = urllib.request.Request(url, headers={"Range": f"bytes={start}-{end}"})
    with urllib.request.urlopen(request) as response:
        if response.status != 206:
            raise RuntimeError(f"{url}: server ignored the byte range (status {response.status})")
        data = response.read()
    if len(data) != end - start + 1:
        raise RuntimeError(f"{url}: expected {end - start + 1} bytes, received {len(data)}")
    return data


def _zip64_values(extra: bytes, wanted: list[str]) -> dict[str, int]:
    position = 0
    while position + 4 <= len(extra):
        header_id, size = struct.unpack_from("<HH", extra, position)
        if header_id == 1:
            values = struct.unpack_from(f"<{size // 8}Q", extra, position + 4)
            return dict(zip(wanted, values))
        position += 4 + size
    raise RuntimeError("ZIP64 sizes missing from central directory entry")


def catalog(url: str, archive_size: int) -> dict[str, Member]:
    """Every member of the archive, by name, from its central directory."""
    tail_start = max(0, archive_size - _TAIL_BYTES)
    tail = _read_range(url, tail_start, archive_size - 1)
    end_at = tail.rfind(b"PK\x05\x06")
    if end_at < 0:
        raise RuntimeError("end-of-central-directory record not found")
    _, _, _, _, entry_count, directory_size, directory_offset = struct.unpack_from(
        "<4s4H2L", tail, end_at)
    if entry_count == 0xFFFF or directory_offset == 0xFFFFFFFF:
        locator_at = tail.rfind(b"PK\x06\x07", 0, end_at)
        if locator_at < 0:
            raise RuntimeError("ZIP64 locator not found")
        _, _, zip64_offset, _ = struct.unpack_from("<4sLQL", tail, locator_at)
        record = struct.unpack_from("<4sQ2H2L4Q", tail, zip64_offset - tail_start)
        if record[0] != b"PK\x06\x06":
            raise RuntimeError("ZIP64 end record not found")
        entry_count, directory_size, directory_offset = record[7], record[8], record[9]
    if directory_offset < tail_start:
        tail = _read_range(url, directory_offset, archive_size - 1)
        tail_start = directory_offset

    members = {}
    position = directory_offset - tail_start
    for _ in range(entry_count):
        values = struct.unpack_from("<4s6H3L5H2L", tail, position)
        if values[0] != b"PK\x01\x02":
            raise RuntimeError(f"bad central directory entry at {position}")
        compression = values[4]
        compressed, uncompressed = values[8], values[9]
        name_length, extra_length, comment_length = values[10], values[11], values[12]
        offset = values[16]
        name_start = position + 46
        name = tail[name_start:name_start + name_length].decode("utf-8")
        extra = tail[name_start + name_length:name_start + name_length + extra_length]
        wanted = [field for field, value in (
            ("uncompressed", uncompressed), ("compressed", compressed), ("offset", offset)
        ) if value == 0xFFFFFFFF]
        if wanted:
            found = _zip64_values(extra, wanted)
            uncompressed = found.get("uncompressed", uncompressed)
            compressed = found.get("compressed", compressed)
            offset = found.get("offset", offset)
        members[name] = Member(name, compression, values[7], compressed, uncompressed, offset)
        position = name_start + name_length + extra_length + comment_length
    return members


def read_member(url: str, member: Member) -> bytes:
    """The member's uncompressed bytes."""
    header = _read_range(url, member.local_header_offset, member.local_header_offset + 29)
    values = struct.unpack_from("<4s5H3L2H", header, 0)
    if values[0] != b"PK\x03\x04":
        raise RuntimeError(f"{member.name}: local file header missing")
    payload_start = member.local_header_offset + 30 + values[9] + values[10]
    payload = _read_range(url, payload_start, payload_start + member.compressed_size - 1)
    if member.compression == 8:
        data = zlib.decompress(payload, -15)
    elif member.compression == 0:
        data = payload
    else:
        raise RuntimeError(f"{member.name}: unsupported compression {member.compression}")
    if len(data) != member.uncompressed_size:
        raise RuntimeError(f"{member.name}: size {len(data)} != {member.uncompressed_size}")
    if zlib.crc32(data) != member.crc32:
        raise RuntimeError(f"{member.name}: CRC-32 mismatch")
    return data

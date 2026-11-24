"""The exported weight files' layout, shared by the writer and the reader.

A file is: 4-byte magic, uint32 version, uint32 config count, that many uint32 config
values, uint32 tensor count, then per tensor a uint16 name length, the ASCII name, a uint8
rank, and rank uint32 dimensions; then every tensor's fp16 values in table order,
row-major. All integers and values are little-endian."""

import struct
from pathlib import Path

import numpy as np

ENCODER_MAGIC = b"KVSW"
DECODER_MAGIC = b"KVSD"
VERSION = 1
ENCODER_FILE = "swipe_encoder.kvsw"
DECODER_FILE = "swipe_decoder.kvsd"


def write_tensor_file(path: Path, magic: bytes, config: list[int], tensors: list[tuple[str, np.ndarray]]) -> None:
    header = magic + struct.pack("<2I", VERSION, len(config)) + struct.pack(f"<{len(config)}I", *config)
    header += struct.pack("<I", len(tensors))
    for name, array in tensors:
        encoded = name.encode("ascii")
        header += struct.pack("<H", len(encoded)) + encoded + struct.pack("<B", array.ndim)
        header += struct.pack(f"<{array.ndim}I", *array.shape)
    with open(path, "wb") as file:
        file.write(header)
        for _, array in tensors:
            file.write(np.ascontiguousarray(array, dtype="<f2").tobytes())


def read_tensor_file(path: Path, magic: bytes) -> tuple[list[int], dict[str, np.ndarray]]:
    """The config values and float32 copies of the fp16 tensors."""
    data = path.read_bytes()
    if data[:4] != magic:
        raise ValueError(f"{path} is not a {magic.decode()} file")
    version, count = struct.unpack_from("<2I", data, 4)
    if version != VERSION:
        raise ValueError(f"unsupported version {version}")
    offset = 12
    config = list(struct.unpack_from(f"<{count}I", data, offset))
    offset += 4 * count
    (tensor_count,) = struct.unpack_from("<I", data, offset)
    offset += 4
    table = []
    for _ in range(tensor_count):
        (length,) = struct.unpack_from("<H", data, offset)
        name = data[offset + 2:offset + 2 + length].decode("ascii")
        offset += 2 + length
        (rank,) = struct.unpack_from("<B", data, offset)
        table.append((name, struct.unpack_from(f"<{rank}I", data, offset + 1)))
        offset += 1 + 4 * rank
    tensors = {}
    for name, shape in table:
        size = int(np.prod(shape))
        tensors[name] = np.frombuffer(data, dtype="<f2", count=size, offset=offset).astype(np.float32).reshape(shape)
        offset += 2 * size
    return config, tensors

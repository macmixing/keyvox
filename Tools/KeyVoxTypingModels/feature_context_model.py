"""The word and word-pair counts the rankers are trained with, in the KVLM0001 format the
keyboard's context model began as: a header, then sorted word hashes with a log count, then
sorted word-pair hashes with a log count and a log probability."""

import math
import struct

MAGIC = b"KVLM0001"
HEADER = struct.Struct("<8sQII")
UNIGRAM_ENTRY = struct.Struct("<QB")
BIGRAM_ENTRY = struct.Struct("<QBB")


def fnv1a64_bytes(data):
    value = 14695981039346656037
    for byte in data:
        value ^= byte
        value = (value * 1099511628211) & 0xFFFFFFFFFFFFFFFF
    return value


def word_hash(word):
    return fnv1a64_bytes(word.encode("utf-8"))


def pair_hash(previous, candidate):
    return fnv1a64_bytes(previous.encode("utf-8") + b"\xff" + candidate.encode("utf-8"))


def encode_log_count(count):
    return max(0, min(255, round(math.log1p(count) / 16.0 * 255)))


def encode_log_probability(count, denominator):
    value = math.log((count + 0.25) / (denominator + 1.0))
    return max(0, min(255, round((value + 16.0) / 16.0 * 255)))


def write(path, total_tokens, unigram_rows, bigram_rows):
    with path.open("wb") as target:
        target.write(HEADER.pack(MAGIC, total_tokens, len(unigram_rows), len(bigram_rows)))
        for row in unigram_rows:
            target.write(UNIGRAM_ENTRY.pack(*row))
        for row in bigram_rows:
            target.write(BIGRAM_ENTRY.pack(*row))


class FeatureContextModel:
    def __init__(self, path):
        self.data = path.read_bytes()
        magic, self.total_tokens, self.unigram_count, self.bigram_count = HEADER.unpack_from(
            self.data)
        if magic != MAGIC:
            raise ValueError(f"unexpected context model magic: {magic!r}")
        self.unigram_offset = HEADER.size
        self.bigram_offset = self.unigram_offset + self.unigram_count * UNIGRAM_ENTRY.size

    @staticmethod
    def _lookup(data, offset, count, entry, wanted):
        low = 0
        high = count
        while low < high:
            middle = (low + high) // 2
            key = struct.unpack_from("<Q", data, offset + middle * entry.size)[0]
            if key < wanted:
                low = middle + 1
            else:
                high = middle
        if low >= count:
            return None
        row = entry.unpack_from(data, offset + low * entry.size)
        return row if row[0] == wanted else None

    def unigram(self, word):
        row = self._lookup(self.data, self.unigram_offset, self.unigram_count,
                           UNIGRAM_ENTRY, word_hash(word))
        if row is None:
            return 0.0, math.log(1.0 / max(1, self.total_tokens))
        log_count = row[1] / 255.0 * 16.0
        count = math.expm1(log_count)
        return log_count, math.log((count + 1.0) / max(1, self.total_tokens))

    def bigram(self, previous, candidate):
        row = self._lookup(self.data, self.bigram_offset, self.bigram_count,
                           BIGRAM_ENTRY, pair_hash(previous, candidate))
        if row is None:
            return 0.0, math.log(0.25), 0.0
        return row[1] / 255.0 * 16.0, row[2] / 255.0 * 16.0 - 16.0, 1.0

"""Reads what `Tools/KeyVoxLanguageModel` built for a typing language, linked into a data directory
as `sources/language-build`, for every language but English:

- `built/vocabulary.txt`, the language's words with their capitals, which the dictionary holds in
  lowercase, and `built/common_vocabulary.txt`, its common part, which is never corrected, as
  SCOWL's sizes 60 and 50 are English's;
- `sentences/<source>.txt`, each source's sentences, a line of lowercase words each, which the typo
  simulator types (`simulation_sentences.py`);
- `vocabulary.txt` and `counts.npz`, the words, word pairs, and three-word sequences of every
  source's sentences as `count_ngrams.py` counted them, which the dictionary's probabilities and
  the rankers' word and word-pair counts are made from.

`Counts.leave_out` takes sentences back out of the counts: every line of every source that is one
of them, counted as `count_ngrams.py` counted it, so the counts are those of the other sentences.
A pair or sequence's key packs its words' ids, `ID_BITS` bits each, the first word highest; a
sentence begins with the sentence-start marker, the vocabulary's last id, and a word outside the
vocabulary breaks pairs and sequences."""

import sys
from collections import Counter

import numpy as np

# As Tools/KeyVoxLanguageModel/count_ngrams.py packs them.
ID_BITS = 21
ID_MASK = (1 << ID_BITS) - 1
SENTENCE_START = "<s>"


def words_of(path):
    """The words of a vocabulary file, a word a line, in lowercase."""
    with path.open(encoding="utf-8") as lines:
        return [line.rstrip("\n").lower() for line in lines if line.strip()]


def dictionary_words(paths, language):
    """The language's vocabulary in lowercase: the words the dictionary holds."""
    return {word for word in words_of(paths.language_build / "built" / "vocabulary.txt")
            if language.valid_word(word)}


def common_words(paths):
    """The vocabulary's common part in lowercase."""
    return set(words_of(paths.language_build / "built" / "common_vocabulary.txt"))


def sentence_paths(paths):
    return sorted((paths.language_build / "sentences").glob("*.txt"))


def sentences(paths, source):
    """The words of each of a source's sentences."""
    with (paths.language_build / "sentences" / f"{source}.txt").open(encoding="utf-8") as lines:
        for line in lines:
            yield line.split()


class Counts:
    """The language build's counts, as arrays: each word's count by id, and each pair's and
    sequence's key and count, keys sorted."""

    def __init__(self, paths):
        build = paths.language_build
        self.words = [line.rstrip("\n") for line in
                      (build / "vocabulary.txt").open(encoding="utf-8")]
        if self.words[-1] != SENTENCE_START:
            raise ValueError(f"{build / 'vocabulary.txt'}: its last word is not {SENTENCE_START}")
        self.ids = {word: index for index, word in enumerate(self.words[:-1])}
        self.sentence_start = len(self.words) - 1
        with np.load(build / "counts.npz") as counts:
            self.total_tokens = int(counts["total_tokens"])
            self.word_counts = counts["word_counts"].copy()
            self.pair_keys = counts["pair_keys"]
            self.pair_counts = counts["pair_counts"].copy()
            self.triple_keys = counts["triple_keys"]
            self.triple_counts = counts["triple_counts"].copy()

    def leave_out(self, paths, left_out):
        """Takes every line of every source whose words, joined by spaces, are in `left_out` out of
        the counts. Returns how many lines it took out."""
        words = Counter()
        pairs = Counter()
        triples = Counter()
        lines = tokens = 0
        for path in sentence_paths(paths):
            with path.open(encoding="utf-8") as source:
                for line in source:
                    line = line.rstrip("\n")
                    if line not in left_out:
                        continue
                    lines += 1
                    sentence = line.split()
                    tokens += len(sentence)
                    words.update(word for word in sentence if word in self.ids)
                    ids = [self.sentence_start] + [self.ids.get(word, -1) for word in sentence]
                    for first, second in zip(ids, ids[1:]):
                        if first >= 0 and second >= 0:
                            pairs[(first << ID_BITS) | second] += 1
                    for first, second, third in zip(ids, ids[1:], ids[2:]):
                        if first >= 0 and second >= 0 and third >= 0:
                            triples[(first << 2 * ID_BITS) | (second << ID_BITS) | third] += 1
        self.total_tokens -= tokens
        for word, count in words.items():
            self.word_counts[self.ids[word]] -= count
        self.pair_counts = self._subtract(self.pair_keys, self.pair_counts, pairs)
        self.triple_counts = self._subtract(self.triple_keys, self.triple_counts, triples)
        print(f"left {lines:,} lines, {tokens:,} words, out of the counts", file=sys.stderr)
        return lines

    @staticmethod
    def _subtract(keys, counts, taken):
        if not taken:
            return counts
        wanted = np.fromiter(taken.keys(), dtype=np.uint64, count=len(taken))
        amounts = np.fromiter(taken.values(), dtype=np.int64, count=len(taken))
        positions = np.searchsorted(keys, wanted)
        if np.any(positions >= len(keys)) or np.any(keys[np.minimum(positions, len(keys) - 1)] != wanted):
            raise ValueError("a left-out sentence holds a pair or sequence the counts lack")
        counts[positions] -= amounts
        if np.any(counts[positions] < 0):
            raise ValueError("a left-out sentence was taken out more often than it was counted")
        return counts

    def word_count(self, word):
        index = self.ids.get(word)
        return int(self.word_counts[index]) if index is not None else 0

    def pairs(self):
        """Each counted pair as first word id, second word id, count."""
        return (self.pair_keys >> np.uint64(ID_BITS)).astype(np.int64), \
            (self.pair_keys & np.uint64(ID_MASK)).astype(np.int64), self.pair_counts

    def triples(self):
        """Each counted sequence as first, second, and third word ids, count."""
        keys = self.triple_keys
        return (keys >> np.uint64(2 * ID_BITS)).astype(np.int64), \
            ((keys >> np.uint64(ID_BITS)) & np.uint64(ID_MASK)).astype(np.int64), \
            (keys & np.uint64(ID_MASK)).astype(np.int64), self.triple_counts

    def id_mask(self, words):
        """A boolean array over ids, true for the ids of `words`; never for the sentence start."""
        mask = np.zeros(len(self.words), dtype=bool)
        for word in words:
            index = self.ids.get(word)
            if index is not None:
                mask[index] = True
        return mask

"""Writes the word and word-pair counts the rankers are trained with to
`<data_dir>/work/feature_context_800k.bin`.

Counts every dictionary word, and the 800,000 word pairs of dictionary words that score best
on count and likelihood together, in Tatoeba and OASST1, leaving out the sentences ITE
typists copied. The keyboard reads the same features from its own context model at run
time; this file only stands in for it while training.

With `--leave-out-simulation-sentences`, the sentences the typo simulator types are left out
too, for rankers trained on simulated typing (`simulation_sentences.py`)."""

import argparse
import math
import re
from collections import Counter
from pathlib import Path

import feature_context_model
from paths import DataPaths
from simulation_sentences import is_simulation_sentence
from sources import ite_path, oasst1_path, tatoeba_path
from text_sources import OASST1_WEIGHT, ite_sentences, oasst1_messages, tatoeba_sentences
from words import tokenize

BIGRAM_CAP = 800_000


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("--leave-out-simulation-sentences", action="store_true")
    arguments = parser.parse_args()
    data_dir = arguments.data_dir
    paths = DataPaths(data_dir)

    vocabulary = {line.split("\t", 1)[0] for line in
                  paths.dictionary_unigrams.read_text(encoding="utf-8").splitlines()}
    excluded = set()
    for sentence in ite_sentences(ite_path(data_dir, "processed2020/english/sentences.csv")):
        normalized = " ".join(tokenize(sentence))
        if normalized:
            excluded.add(normalized)

    unigrams = Counter()
    bigrams = Counter()
    contexts = Counter()
    totals = Counter()

    def observe(tokens, weight=1):
        totals["sentences"] += weight
        totals["tokens"] += len(tokens) * weight
        for token in tokens:
            if token in vocabulary:
                unigrams[token] += weight
        for previous, candidate in zip(tokens, tokens[1:]):
            if previous in vocabulary and candidate in vocabulary:
                contexts[previous] += weight
                bigrams[(previous, candidate)] += weight

    def observe_text(text, weight=1):
        tokens = tokenize(text)
        joined = " ".join(tokens)
        if (2 <= len(tokens) <= 40 and joined not in excluded
                and not (arguments.leave_out_simulation_sentences
                         and is_simulation_sentence(joined))):
            observe(tokens, weight)

    for sentence in tatoeba_sentences(tatoeba_path(data_dir)):
        observe_text(sentence)
    for message in oasst1_messages(oasst1_path(data_dir)):
        for fragment in re.split(r"[.!?\n]+", message):
            observe_text(fragment, OASST1_WEIGHT)

    ranked = []
    for (previous, candidate), count in bigrams.items():
        denominator = contexts[previous]
        conditional = count / max(1, denominator)
        utility = math.log1p(count) + 0.35 * math.log(max(conditional, 1e-12))
        ranked.append((utility, count, previous, candidate, denominator))
    ranked.sort(key=lambda item: (-item[0], -item[1], item[2], item[3]))

    unigram_rows = []
    unigram_words = {}
    for word in sorted(vocabulary):
        hashed = feature_context_model.word_hash(word)
        if unigram_words.setdefault(hashed, word) != word:
            raise RuntimeError(f"word hash collision: {unigram_words[hashed]!r} and {word!r}")
        unigram_rows.append((hashed, feature_context_model.encode_log_count(unigrams[word])))
    unigram_rows.sort()

    bigram_rows = []
    pair_words = {}
    for _, count, previous, candidate, denominator in ranked[:BIGRAM_CAP]:
        hashed = feature_context_model.pair_hash(previous, candidate)
        pair = (previous, candidate)
        if pair_words.setdefault(hashed, pair) != pair:
            raise RuntimeError(f"pair hash collision: {pair_words[hashed]!r} and {pair!r}")
        bigram_rows.append((hashed, feature_context_model.encode_log_count(count),
                            feature_context_model.encode_log_probability(count, denominator)))
    bigram_rows.sort()

    paths.work.mkdir(parents=True, exist_ok=True)
    feature_context_model.write(paths.feature_context_model, totals["tokens"],
                                unigram_rows, bigram_rows)
    print(f"tokens={totals['tokens']} sentences_weighted={totals['sentences']} "
          f"unigrams={len(unigram_rows)} observed_bigrams={len(bigrams)} "
          f"bigrams={len(bigram_rows)}")


if __name__ == "__main__":
    main()

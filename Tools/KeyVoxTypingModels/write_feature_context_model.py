"""Writes the word and word-pair counts the rankers are trained with to
`<data_dir>/work/feature_context_800k.bin`.

Counts every dictionary word, and the 800,000 word pairs of dictionary words that score best
on count and likelihood together, in Tatoeba and OASST1, leaving out the sentences ITE
typists copied. The keyboard reads the same features from its own context model at run
time; this file only stands in for it while training.

With `--leave-out-simulation-sentences`, the sentences the typo simulator types are left out
too, for rankers trained on simulated typing (`simulation_sentences.py`).

For another language than English, the counts are its language build's (`language_build.py`), of
every source, and the simulation sentences are always left out, as its rankers learn from
simulated typing alone."""

import argparse
import math
import re
from collections import Counter
from pathlib import Path

import numpy as np

import feature_context_model
import language_build
from paths import DataPaths
from simulation_sentences import is_simulation_sentence, simulation_sentences
from sources import ite_path, oasst1_path, tatoeba_path
from text_sources import OASST1_WEIGHT, ite_sentences, oasst1_messages, tatoeba_sentences
from typing_languages import add_language_arguments, language_from
from words import tokenize

BIGRAM_CAP = 800_000


def utility(count, denominator):
    """How well a word pair scores on count and likelihood together."""
    conditional = count / max(1, denominator)
    return math.log1p(count) + 0.35 * math.log(max(conditional, 1e-12))


def english_counts(paths, vocabulary, leave_out_simulation_sentences):
    """The dictionary words' counts, the counted word pairs, best first, as (utility, count,
    previous word, word, previous word's count as a pair's first word), the tokens counted, and
    what was counted, from Tatoeba and OASST1."""
    data_dir = paths.root
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
                and not (leave_out_simulation_sentences and is_simulation_sentence(joined))):
            observe(tokens, weight)

    for sentence in tatoeba_sentences(tatoeba_path(data_dir)):
        observe_text(sentence)
    for message in oasst1_messages(oasst1_path(data_dir)):
        for fragment in re.split(r"[.!?\n]+", message):
            observe_text(fragment, OASST1_WEIGHT)

    ranked = []
    for (previous, candidate), count in bigrams.items():
        denominator = contexts[previous]
        ranked.append((utility(count, denominator), count, previous, candidate, denominator))
    ranked.sort(key=lambda item: (-item[0], -item[1], item[2], item[3]))
    return (unigrams, ranked, totals["tokens"],
            f"sentences_weighted={totals['sentences']} observed_bigrams={len(bigrams)}")


def language_build_counts(paths, language, vocabulary):
    """As `english_counts`, from the language build's counts less the simulation sentences, the
    best `BIGRAM_CAP` pairs only."""
    counts = language_build.Counts(paths)
    left_out = {" ".join(tokens) for tokens in simulation_sentences(paths, language)}
    counts.leave_out(paths, left_out)
    unigrams = Counter({word: counts.word_count(word) for word in vocabulary})
    in_dictionary = counts.id_mask(vocabulary)
    first, second, pair_counts = counts.pairs()
    keep = in_dictionary[first] & in_dictionary[second] & (pair_counts > 0)
    first, second, pair_counts = first[keep], second[keep], pair_counts[keep]
    contexts = np.bincount(first, weights=pair_counts, minlength=len(counts.words)).astype(np.int64)
    denominators = contexts[first]
    utilities = (np.log1p(pair_counts)
                 + 0.35 * np.log(np.maximum(pair_counts / np.maximum(1, denominators), 1e-12)))
    words = counts.words
    rank = np.empty(len(words), dtype=np.int64)
    rank[sorted(range(len(words)), key=words.__getitem__)] = np.arange(len(words))
    order = np.lexsort((rank[second], rank[first], -pair_counts, -utilities))[:BIGRAM_CAP]
    ranked = [(float(utilities[row]), int(pair_counts[row]), words[first[row]], words[second[row]],
               int(denominators[row])) for row in order]
    return unigrams, ranked, counts.total_tokens, f"observed_bigrams={len(pair_counts)}"


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("--leave-out-simulation-sentences", action="store_true")
    add_language_arguments(parser)
    arguments = parser.parse_args()
    paths = DataPaths(arguments.data_dir)
    language = language_from(arguments)

    vocabulary = {line.split("\t", 1)[0] for line in
                  paths.dictionary_unigrams.read_text(encoding="utf-8").splitlines()}
    if language.uses_english_text:
        unigrams, ranked, tokens, counted = english_counts(
            paths, vocabulary, arguments.leave_out_simulation_sentences)
    else:
        unigrams, ranked, tokens, counted = language_build_counts(paths, language, vocabulary)

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
    feature_context_model.write(paths.feature_context_model, tokens, unigram_rows, bigram_rows)
    print(f"tokens={tokens} {counted} unigrams={len(unigram_rows)} bigrams={len(bigram_rows)}")


if __name__ == "__main__":
    main()

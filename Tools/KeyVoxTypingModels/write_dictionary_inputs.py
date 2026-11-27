"""Writes the word list and n-gram list the LatinIME dictionary is compiled from.

For English, every SCOWL size-60 American word is in the dictionary, with a probability from how
often Tatoeba and OASST1 use it, and the sentences ITE typists copied are left out of the counts.
For another language, every word of its language build's vocabulary is, in lowercase, with a
probability from the build's counts of all its sources (`language_build.py`), and the simulation
sentences the rankers are measured on, buckets 8-9 (`simulation_sentences.held_out_sentences`),
are left out of the counts. Word pairs and three-word sequences seen at least twice keep the three
likeliest next words of each context, for the most frequent contexts, up to 160,000 pairs and
60,000 sequences.

`dictionary_unigrams.tsv` and `dictionary_ngrams.tsv` hold every word and sequence so chosen,
for the steps that read the dictionary's words. The dictionary is compiled from
`dictionary_kept_unigrams.tsv` and `dictionary_kept_ngrams.tsv`: the same, less the words
`offensive_words.py` matches and every word pair and three-word sequence holding one, so every
other entry is as it would be with them."""

import argparse
import heapq
import math
import re
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np

import language_build
from offensive_words import letter_form, read_matcher
from paths import DataPaths
from simulation_sentences import held_out_sentences
from sources import ite_path, oasst1_path, tatoeba_path
from text_sources import OASST1_WEIGHT, ite_sentences, oasst1_messages, tatoeba_sentences
from training_sets import TEST_BUCKETS
from typing_languages import add_language_arguments, language_from
from words import WHOLE_WORD, tokenize

ENCODING_SCALER = 8.58923700372
MAXIMUM_BIGRAMS = 160_000
MAXIMUM_TRIGRAMS = 60_000


def normalized_sentence(text):
    return " ".join(tokenize(text))


def encode_probability(raw_probability):
    if raw_probability <= 0:
        return 0
    return max(1, min(255, round(255 + math.log2(raw_probability) * ENCODING_SCALER)))


def select_context_top_ngrams(counter, context_counter, minimum_count, limit,
                              max_targets_per_context=3):
    heaps = defaultdict(list)
    for ngram, count in counter.items():
        if count < minimum_count:
            continue
        context = ngram[:-1]
        item = (count, ngram[-1])
        heap = heaps[context]
        if len(heap) < max_targets_per_context:
            heapq.heappush(heap, item)
        elif item > heap[0]:
            heapq.heapreplace(heap, item)
    contexts = sorted(heaps, key=lambda context: (-context_counter[context], context))
    selected = []
    for context in contexts:
        entries = sorted(heaps[context], reverse=True)
        if len(selected) + len(entries) > limit:
            continue
        denominator_for_context = context_counter[context]
        for count, target in entries:
            probability = encode_probability(count / denominator_for_context)
            selected.append((context + (target,), probability, count))
    return selected


def english_ngrams(paths):
    """The English dictionary's words, ranked, and its chosen word pairs and sequences, from SCOWL,
    Tatoeba, and OASST1, with the counts printed."""
    data_dir = paths.root
    vocabulary = {
        word.casefold() for word in paths.dictionary_words.read_text(encoding="utf-8").splitlines()
        if WHOLE_WORD.fullmatch(word) and "’" not in word
    }
    evaluation_sentences = {
        normalized_sentence(sentence)
        for sentence in ite_sentences(ite_path(data_dir, "processed2020/english/sentences.csv"))
    }

    unigrams = Counter()
    bigrams = Counter()
    trigrams = Counter()
    totals = Counter()

    def observe(tokens, weight=1):
        filtered = [token for token in tokens if token in vocabulary]
        if len(filtered) < 2:
            return
        totals["sentences"] += weight
        totals["tokens"] += len(filtered) * weight
        for token in filtered:
            unigrams[token] += weight
        for pair in zip(filtered, filtered[1:]):
            bigrams[pair] += weight
        for triple in zip(filtered, filtered[1:], filtered[2:]):
            trigrams[triple] += weight

    def observe_text(text, weight=1):
        normalized = normalized_sentence(text)
        if normalized and normalized not in evaluation_sentences:
            tokens = normalized.split()
            if 2 <= len(tokens) <= 40:
                observe(tokens, weight)

    for sentence in tatoeba_sentences(tatoeba_path(data_dir)):
        observe_text(sentence)
    for message in oasst1_messages(oasst1_path(data_dir)):
        for fragment in re.split(r"[.!?\n]+", message):
            observe_text(fragment, OASST1_WEIGHT)

    ranked_unigrams = ranked_by_count(vocabulary, unigrams, totals["tokens"])

    bigram_contexts = Counter()
    trigram_contexts = Counter()
    for (first, _), count in bigrams.items():
        bigram_contexts[(first,)] += count
    for (first, second, _), count in trigrams.items():
        trigram_contexts[(first, second)] += count
    selected_bigrams = select_context_top_ngrams(bigrams, bigram_contexts, 2, MAXIMUM_BIGRAMS)
    selected_trigrams = select_context_top_ngrams(trigrams, trigram_contexts, 2, MAXIMUM_TRIGRAMS)
    counted = (f"sentence_weight={totals['sentences']} token_weight={totals['tokens']} "
               f"observed_unigrams={len(unigrams)} observed_bigrams={len(bigrams)} "
               f"observed_trigrams={len(trigrams)}")
    return vocabulary, ranked_unigrams, selected_bigrams, selected_trigrams, counted


def ranked_by_count(vocabulary, unigrams, tokens):
    """The words with their encoded probabilities and counts, likeliest first."""
    ranked = []
    denominator = tokens + len(vocabulary)
    for word in vocabulary:
        count = unigrams[word]
        ranked.append((word, encode_probability((count + 1) / denominator), count))
    ranked.sort(key=lambda item: (-item[1], -item[2], item[0]))
    return ranked


def select_counted_top_ngrams(counts, contexts, targets, ngram_counts, minimum_count, limit,
                              max_targets_per_context=3):
    """`select_context_top_ngrams` over a language build's counts: `contexts`, a tuple of word-id
    arrays, oldest word first, and `targets` and `ngram_counts`, arrays in the order of the counts'
    keys, so that rows of a context are together. Words are compared as strings, as there."""
    if not len(targets):
        return []
    words = counts.words
    rank = np.empty(len(words), dtype=np.int64)
    rank[sorted(range(len(words)), key=words.__getitem__)] = np.arange(len(words))
    differs = np.zeros(len(targets), dtype=bool)
    differs[0] = True
    for context in contexts:
        differs[1:] |= context[1:] != context[:-1]
    starts = np.flatnonzero(differs)
    group = np.cumsum(differs) - 1
    totals = np.add.reduceat(ngram_counts, starts)

    candidate = np.flatnonzero(ngram_counts >= minimum_count)
    order = candidate[np.lexsort((-rank[targets[candidate]], -ngram_counts[candidate],
                                  group[candidate]))]
    ordered_groups = group[order]
    first_of_group = np.ones(len(order), dtype=bool)
    first_of_group[1:] = ordered_groups[1:] != ordered_groups[:-1]
    group_start = np.maximum.accumulate(np.where(first_of_group, np.arange(len(order)), 0))
    kept = order[np.arange(len(order)) - group_start < max_targets_per_context]

    kept_groups = np.unique(group[kept])
    context_starts = starts[kept_groups]
    context_order = kept_groups[np.lexsort(
        tuple(rank[context[context_starts]] for context in reversed(contexts))
        + (-totals[kept_groups],))]
    entries_by_group = {}
    for row in kept:
        entries_by_group.setdefault(int(group[row]), []).append(row)

    selected = []
    for context_group in context_order:
        entries = entries_by_group[int(context_group)]
        if len(selected) + len(entries) > limit:
            continue
        denominator_for_context = int(totals[context_group])
        start = starts[context_group]
        context_words = tuple(words[context[start]] for context in contexts)
        for row in entries:
            count = int(ngram_counts[row])
            selected.append((context_words + (words[targets[row]],),
                             encode_probability(count / denominator_for_context), count))
        if len(selected) == limit:
            break
    return selected


def language_build_ngrams(paths, language):
    """Another language's dictionary words, ranked, and its chosen word pairs and sequences, from
    its language build, with the counts printed."""
    vocabulary = language_build.dictionary_words(paths, language)
    counts = language_build.Counts(paths)
    counts.leave_out(paths, held_out_sentences(paths, language, TEST_BUCKETS))
    unigrams = {word: counts.word_count(word) for word in vocabulary}
    tokens = sum(unigrams.values())
    ranked_unigrams = ranked_by_count(vocabulary, unigrams, tokens)

    in_dictionary = counts.id_mask(vocabulary)
    first, second, pair_counts = counts.pairs()
    keep = in_dictionary[first] & in_dictionary[second]
    selected_bigrams = select_counted_top_ngrams(
        counts, (first[keep],), second[keep], pair_counts[keep], 2, MAXIMUM_BIGRAMS)
    del first, second, pair_counts, keep
    oldest, older, newest, triple_counts = counts.triples()
    keep = in_dictionary[oldest] & in_dictionary[older] & in_dictionary[newest]
    selected_trigrams = select_counted_top_ngrams(
        counts, (oldest[keep], older[keep]), newest[keep], triple_counts[keep], 2,
        MAXIMUM_TRIGRAMS)
    counted = (f"token_weight={tokens} observed_unigrams={sum(1 for c in unigrams.values() if c)}")
    return vocabulary, ranked_unigrams, selected_bigrams, selected_trigrams, counted


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("data_dir", type=Path)
    add_language_arguments(parser)
    arguments = parser.parse_args()
    paths = DataPaths(arguments.data_dir)
    language = language_from(arguments)

    if language.uses_english_text:
        vocabulary, ranked_unigrams, selected_bigrams, selected_trigrams, counted = \
            english_ngrams(paths)
    else:
        vocabulary, ranked_unigrams, selected_bigrams, selected_trigrams, counted = \
            language_build_ngrams(paths, language)

    offensive = read_matcher(paths.offensive_words)

    def is_kept(words):
        return offensive is None or not any(offensive.fullmatch(letter_form(word))
                                            for word in words)

    unigram_lines = [((word,), f"{word}\t{probability}\n") for word, probability, _ in ranked_unigrams]
    ngram_lines = [((previous, word), f"{word}\t{probability}\t{previous}\n")
                   for (previous, word), probability, _ in selected_bigrams]
    ngram_lines += [((older, previous, word), f"{word}\t{probability}\t{previous}\t{older}\n")
                    for (older, previous, word), probability, _ in selected_trigrams]
    paths.work.mkdir(parents=True, exist_ok=True)
    for lines, every, kept in ((unigram_lines, paths.dictionary_unigrams, paths.dictionary_kept_unigrams),
                               (ngram_lines, paths.dictionary_ngrams, paths.dictionary_kept_ngrams)):
        every.write_text("".join(line for _, line in lines), encoding="utf-8")
        kept.write_text("".join(line for words, line in lines if is_kept(words)), encoding="utf-8")
    left_out = sum(1 for words, _ in unigram_lines if not is_kept(words))

    print(f"vocabulary={len(vocabulary)} left_out={left_out} {counted} "
          f"bigrams={len(selected_bigrams)} trigrams={len(selected_trigrams)}")


if __name__ == "__main__":
    main()

"""Writes the word list and n-gram list the LatinIME dictionary is compiled from.

Every SCOWL size-60 American word is in the dictionary, with a probability from how often
Tatoeba and OASST1 use it. Word pairs and three-word sequences seen at least twice keep the
three likeliest next words of each context, for the most frequent contexts, up to 160,000
pairs and 60,000 sequences. Sentences ITE typists copied are left out of the counts."""

import argparse
import heapq
import math
import re
from collections import Counter, defaultdict
from pathlib import Path

from paths import DataPaths
from sources import ite_path, oasst1_path, tatoeba_path
from text_sources import OASST1_WEIGHT, ite_sentences, oasst1_messages, tatoeba_sentences
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


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("data_dir", type=Path)
    data_dir = parser.parse_args().data_dir
    paths = DataPaths(data_dir)

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

    ranked_unigrams = []
    denominator = totals["tokens"] + len(vocabulary)
    for word in vocabulary:
        count = unigrams[word]
        probability = encode_probability((count + 1) / denominator)
        ranked_unigrams.append((word, probability, count))
    ranked_unigrams.sort(key=lambda item: (-item[1], -item[2], item[0]))

    bigram_contexts = Counter()
    trigram_contexts = Counter()
    for (first, _), count in bigrams.items():
        bigram_contexts[(first,)] += count
    for (first, second, _), count in trigrams.items():
        trigram_contexts[(first, second)] += count
    selected_bigrams = select_context_top_ngrams(bigrams, bigram_contexts, 2, MAXIMUM_BIGRAMS)
    selected_trigrams = select_context_top_ngrams(trigrams, trigram_contexts, 2, MAXIMUM_TRIGRAMS)

    paths.work.mkdir(parents=True, exist_ok=True)
    with paths.dictionary_unigrams.open("w", encoding="utf-8") as target:
        for word, probability, _ in ranked_unigrams:
            target.write(f"{word}\t{probability}\n")
    with paths.dictionary_ngrams.open("w", encoding="utf-8") as target:
        for (previous, word), probability, _ in selected_bigrams:
            target.write(f"{word}\t{probability}\t{previous}\n")
        for (older, previous, word), probability, _ in selected_trigrams:
            target.write(f"{word}\t{probability}\t{previous}\t{older}\n")

    print(f"vocabulary={len(vocabulary)} sentence_weight={totals['sentences']} "
          f"token_weight={totals['tokens']} observed_unigrams={len(unigrams)} "
          f"observed_bigrams={len(bigrams)} observed_trigrams={len(trigrams)} "
          f"bigrams={len(selected_bigrams)} trigrams={len(selected_trigrams)}")


if __name__ == "__main__":
    main()

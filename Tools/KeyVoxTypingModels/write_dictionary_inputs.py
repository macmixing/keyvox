"""Writes the word list and n-gram list the LatinIME dictionary is compiled from.

Every SCOWL size-60 American word is in the dictionary, with a probability from how often
Tatoeba and OASST1 use it. Word pairs and three-word sequences seen at least twice keep the
three likeliest next words of each context, for the most frequent contexts, up to 160,000
pairs and 60,000 sequences. Sentences ITE typists copied are left out of the counts.

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

from offensive_words import letter_form, read_matcher
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

    offensive = read_matcher(paths.offensive_words)

    def is_kept(words):
        return not any(offensive.fullmatch(letter_form(word)) for word in words)

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

    print(f"vocabulary={len(vocabulary)} left_out={left_out} sentence_weight={totals['sentences']} "
          f"token_weight={totals['tokens']} observed_unigrams={len(unigrams)} "
          f"observed_bigrams={len(bigrams)} observed_trigrams={len(trigrams)} "
          f"bigrams={len(selected_bigrams)} trigrams={len(selected_trigrams)}")


if __name__ == "__main__":
    main()

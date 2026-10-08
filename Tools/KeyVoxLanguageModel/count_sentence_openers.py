"""Counts, for each source, the words that open sentences: every sentence's first word, and
the first word of a sentence after a given previous sentence, for the suggestion bar where
a sentence begins.

A previous sentence is told apart by how it ended (".", "?", "!", or a line break), by its
first and last words, and by every word in it: `word_pairs` counts how often a word in the
previous sentence, under its ending, comes before each opener, and `word_sentences` how many
previous sentences with that ending held the word, so a word's pull on the next sentence's
opener can be measured. Words are counted only after a sentence that ended with a mark: a
bare line break mostly breaks lists and code rather than messages. A question is followed by
what answers it, so a question asked right after another is not counted as following it. Pairs seen fewer than `MINIMUM_PAIR_COUNT` times, or for an
opener outside the source's `KEPT_OPENERS` most common, are dropped.

One text in ten, chosen by a hash of the text, is held out and kept whole for measuring, so
a measurement never sees text the counts came from. Writes `<data_dir>/openers/<source>.pkl`
with `openers`, `contexts`, `word_pairs`, `word_sentences`, and `held_out`.
"""

import argparse
import pickle
import zlib
from collections import Counter, defaultdict
from pathlib import Path

from extract_sentences import READERS
from normalize import LINE_BREAK, sentences_with_endings
from sources import SOURCES

QUESTION = "?"
# One text in this many is held out for measuring.
HELD_OUT_EVERY = 10
KEPT_OPENERS = 1000
MINIMUM_PAIR_COUNT = 2


def is_held_out(text: str) -> bool:
    return zlib.crc32(text.encode("utf-8")) % HELD_OUT_EVERY == 0


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("data_dir", type=Path)
    arguments = parser.parse_args()

    output_directory = arguments.data_dir / "openers"
    output_directory.mkdir(parents=True, exist_ok=True)
    for source in SOURCES:
        openers: Counter[str] = Counter()
        # (ending, previous first word, previous last word) -> next sentence's first word
        contexts: defaultdict[tuple[str, str, str], Counter[str]] = defaultdict(Counter)
        # (previous ending, word in the previous sentence, next sentence's first word)
        word_pairs: Counter[tuple[str, str, str]] = Counter()
        # (previous ending, word in the previous sentence)
        word_sentences: Counter[tuple[str, str]] = Counter()
        # (ending, previous first word, previous last word, previous words, next first word)
        held_out: list[tuple[str, str, str, tuple[str, ...], str]] = []
        for text in READERS[source.name](arguments.data_dir / "sources" / source.name):
            hold = is_held_out(text)
            previous = None
            for words, ending in sentences_with_endings(text):
                if previous is not None and not (previous[1] == QUESTION and ending == QUESTION):
                    previous_words, previous_ending = previous
                    context = (previous_ending, previous_words[0], previous_words[-1])
                    present = set(previous_words)
                    if hold:
                        held_out.append((*context, tuple(sorted(present)), words[0]))
                    else:
                        contexts[context][words[0]] += 1
                        if previous_ending != LINE_BREAK:
                            word_sentences.update((previous_ending, word) for word in present)
                            word_pairs.update((previous_ending, word, words[0]) for word in present)
                if not hold:
                    openers[words[0]] += 1
                previous = (words, ending) if ending else None

        kept = {word for word, _ in openers.most_common(KEPT_OPENERS)}
        word_pairs = Counter({
            pair: count for pair, count in word_pairs.items()
            if count >= MINIMUM_PAIR_COUNT and pair[2] in kept
        })
        with open(output_directory / f"{source.name}.pkl", "wb") as output:
            pickle.dump({
                "openers": openers,
                "contexts": dict(contexts),
                "word_pairs": word_pairs,
                "word_sentences": word_sentences,
                "held_out": held_out,
            }, output)
        pairs = sum(sum(counter.values()) for counter in contexts.values())
        print(
            f"{source.name}: {sum(openers.values())} sentences, {pairs} sentence pairs, "
            f"{len(word_pairs)} word pairs kept, {len(held_out)} held out",
            flush=True,
        )


if __name__ == "__main__":
    main()

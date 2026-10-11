"""Writes the words that most often follow each common word, for the suggestion bar to offer
while the user picks its words in a row: the bundled dictionary keeps only a few next words per
word ("the" -> same, most, world), so always picking from the bar runs out of new words and walks
the same ones again (PredictionComputer).

Followers are counted in count_ngrams.py's word pairs, among the dictionary's words (SCOWL), with
the sentence starts transcripts bring in taken off (followers.py) and without a word following
itself, which transcripts count where a speaker stutters ("the the"). Each line is a word, a tab,
and its followers as `word:log P(word | context)`, likeliest first.
"""

import argparse
from pathlib import Path

import numpy as np

from followers import followers_line, grouped, written_sentence_ends

ID_BITS = 21
ID_MASK = np.uint64((1 << ID_BITS) - 1)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("scowl_words", type=Path, help="the dictionary's word list, from scowl_words.sh")
    parser.add_argument("output", type=Path)
    parser.add_argument("--written", action="append", help="written source in <data_dir>/sentences, without .txt")
    parser.add_argument("--contexts", type=int, default=3000, help="most common words kept as contexts")
    parser.add_argument("--followers", type=int, default=12, help="followers kept per context")
    arguments = parser.parse_args()

    vocabulary = (arguments.data_dir / "vocabulary.txt").read_text(encoding="utf-8").splitlines()
    dictionary = {line.strip().lower() for line in arguments.scowl_words.read_text(encoding="utf-8").splitlines()}
    known = np.array([word in dictionary and any(character.isalpha() for character in word) for word in vocabulary])
    contexts = [index for index in range(len(vocabulary)) if known[index]][:arguments.contexts]
    is_context = np.zeros(len(vocabulary), dtype=bool)
    is_context[contexts] = True

    written = [arguments.data_dir / "sentences" / f"{name}.txt" for name in arguments.written or ["oasst2", "tatoeba"]]
    uses, endings, openers = written_sentence_ends(written)
    opener_total = sum(openers.values())
    opener_shares = np.array([openers.get(word, 0) / opener_total for word in vocabulary])

    counts = np.load(arguments.data_dir / "counts.npz")
    pairs = counts["pair_keys"]
    first = (pairs >> np.uint64(ID_BITS)).astype(np.int64)
    second = (pairs & ID_MASK).astype(np.int64)
    weights = counts["pair_counts"]
    in_context = is_context[first]
    first, second, weights = first[in_context], second[in_context], weights[in_context]
    context_ids, context_totals = grouped(first, weights)
    followed = known[second] & (second != first)
    pair_keys, pair_counts = grouped((first[followed] << ID_BITS) | second[followed], weights[followed])
    pair_contexts = pair_keys >> ID_BITS
    pair_followers = pair_keys & ((1 << ID_BITS) - 1)

    lines = []
    for index in sorted(range(len(context_ids)), key=lambda index: vocabulary[context_ids[index]]):
        context = context_ids[index]
        word = vocabulary[context]
        ending_share = endings[word] / uses[word] if uses[word] else 0.0
        rows = slice(*np.searchsorted(pair_contexts, [context, context + 1]))
        line = followers_line(word, pair_followers[rows], pair_counts[rows], float(context_totals[index]),
                              opener_shares, ending_share, vocabulary, arguments.followers)
        if line.rstrip("\n").endswith("\t") is False:
            lines.append(line)
    arguments.output.write_text("".join(lines), encoding="utf-8")
    print(f"{len(lines)} contexts, {arguments.output.stat().st_size} bytes")


if __name__ == "__main__":
    main()

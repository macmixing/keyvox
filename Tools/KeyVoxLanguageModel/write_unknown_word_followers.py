"""Writes the words the suggestion bar offers right after a word the keyboard's dictionary does
not know, such as a name, a brand, or a word the user taught it: what most often follows such a
word, after each common word before it, so "We need ___" offers "to" and "I use ___" offers
"to", "and", and "for", as the system keyboard does (Tools/AppleKeyboardBaseline).

A word is unknown when SCOWL, the word list the dictionary comes from, lacks it. Followers are
counted in count_ngrams.py's sequences of a context word, an unknown word, and a dictionary
word. Transcripts mark no sentence ends, so there an unknown word that ends a sentence is
followed by the next sentence's first word. The written sources (`--written`), which do mark
them, tell how often an unknown word ends a sentence and which words start one; that many
sentence starts are taken off each context's counts before followers are ranked.

Each line is a context, a tab, and its followers as `word:log P(word | context, unknown word)`,
likeliest first. The context is the word before the unknown word, `<s>` where the unknown word
starts a sentence, or `*` for any word before it, which comes first.
"""

import argparse
import math
from collections import Counter
from pathlib import Path

import numpy as np

from normalize import SENTENCE_START

ID_BITS = 21
ID_MASK = np.uint64((1 << ID_BITS) - 1)
ANY_CONTEXT = "*"


def grouped(keys: np.ndarray, counts: np.ndarray):
    unique, inverse = np.unique(keys, return_inverse=True)
    return unique, np.bincount(inverse, weights=counts)


def written_sentence_ends(paths: list[Path], is_unknown) -> tuple[float, Counter]:
    """How often an unknown word ends a written sentence, and how often each word starts one."""
    unknown_words = 0
    unknown_endings = 0
    openers: Counter = Counter()
    for path in paths:
        with open(path, encoding="utf-8") as sentences:
            for sentence in sentences:
                words = sentence.split()
                if not words:
                    continue
                openers[words[0]] += 1
                unknown = [is_unknown(word) for word in words]
                unknown_words += sum(unknown)
                unknown_endings += unknown[-1]
    return unknown_endings / max(unknown_words, 1), openers


def followers_line(context: str, follower_ids: np.ndarray, follower_counts: np.ndarray, total: float,
                   opener_shares: np.ndarray, ending_share: float, vocabulary: list[str], limit: int) -> str:
    """Followers after taking off the sentence starts `total` uses would bring in transcripts."""
    adjusted = follower_counts - ending_share * total * opener_shares[follower_ids]
    kept_total = total * (1 - ending_share)
    order = [index for index in np.argsort(-adjusted, kind="stable") if adjusted[index] > 0][:limit]
    pairs = " ".join(f"{vocabulary[follower_ids[index]]}:{math.log(adjusted[index] / kept_total):.3f}" for index in order)
    return f"{context}\t{pairs}\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("scowl_words", type=Path, help="the dictionary's word list, from scowl_words.sh")
    parser.add_argument("output", type=Path)
    parser.add_argument("--written", action="append", help="written source in <data_dir>/sentences, without .txt")
    parser.add_argument("--contexts", type=int, default=3000, help="words before kept, most counted first")
    parser.add_argument("--followers", type=int, default=6, help="followers kept per context")
    parser.add_argument("--minimum", type=int, default=50, help="sequences a context needs")
    arguments = parser.parse_args()

    vocabulary = (arguments.data_dir / "vocabulary.txt").read_text(encoding="utf-8").splitlines()
    sentence_start = vocabulary.index(SENTENCE_START)
    dictionary = {line.strip().lower() for line in arguments.scowl_words.read_text(encoding="utf-8").splitlines()}

    def is_unknown(word: str) -> bool:
        return any(character.isalpha() for character in word) and word not in dictionary

    has_letter = np.array([any(character.isalpha() for character in word) for word in vocabulary])
    known = np.array([word in dictionary for word in vocabulary]) & has_letter
    unknown = ~known & has_letter
    unknown[sentence_start] = False
    known[sentence_start] = False
    context_allowed = known.copy()
    context_allowed[sentence_start] = True

    written = [arguments.data_dir / "sentences" / f"{name}.txt" for name in arguments.written or ["oasst2", "tatoeba"]]
    ending_share, openers = written_sentence_ends(written, is_unknown)
    opener_total = sum(openers.values())
    opener_shares = np.array([openers.get(word, 0) / opener_total for word in vocabulary])

    counts = np.load(arguments.data_dir / "counts.npz")
    triples = counts["triple_keys"]
    with_unknown = unknown[((triples >> np.uint64(ID_BITS)) & ID_MASK).astype(np.int64)]
    triples, weights = triples[with_unknown], counts["triple_counts"][with_unknown]
    before = (triples >> np.uint64(2 * ID_BITS)).astype(np.int64)
    after = (triples & ID_MASK).astype(np.int64)
    allowed = context_allowed[before]
    before, after, weights = before[allowed], after[allowed], weights[allowed]

    context_ids, context_totals = grouped(before, weights)
    followed = known[after]
    pair_keys, pair_counts = grouped((before[followed] << ID_BITS) | after[followed], weights[followed])
    pair_contexts = pair_keys >> ID_BITS
    pair_followers = pair_keys & ((1 << ID_BITS) - 1)

    pairs = counts["pair_keys"]
    first = (pairs >> np.uint64(ID_BITS)).astype(np.int64)
    second = (pairs & ID_MASK).astype(np.int64)
    after_any = unknown[first]
    any_total = float(counts["pair_counts"][after_any].sum())
    any_followed = after_any & known[second]
    any_ids, any_counts = grouped(second[any_followed], counts["pair_counts"][any_followed])

    eligible = np.flatnonzero(context_totals >= arguments.minimum)
    kept = eligible[np.argsort(-context_totals[eligible], kind="stable")[:arguments.contexts]]
    lines = [followers_line(ANY_CONTEXT, any_ids, any_counts, any_total, opener_shares, ending_share,
                            vocabulary, arguments.followers)]
    for index in sorted(kept, key=lambda index: vocabulary[context_ids[index]]):
        context = context_ids[index]
        rows = slice(*np.searchsorted(pair_contexts, [context, context + 1]))
        lines.append(followers_line(vocabulary[context], pair_followers[rows], pair_counts[rows],
                                    float(context_totals[index]), opener_shares, ending_share,
                                    vocabulary, arguments.followers))
    arguments.output.write_text("".join(lines), encoding="utf-8")
    print(f"unknown words end {ending_share:.1%} of their written sentences; "
          f"{len(lines) - 1} contexts, {arguments.output.stat().st_size} bytes")


if __name__ == "__main__":
    main()

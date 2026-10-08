"""Writes the suggestion bar's sentence-opener model: what the keyboard scores the words
that may open a sentence by, from the sentence before it.

Each opener's score is its log likelihood after the previous sentence's ending, plus a boost
for the previous sentence's first word under that ending, plus a boost for each word in the
previous sentence under that ending. A boost is how much likelier the opener is with that word
than without it (log P(opener | word) / P(opener)), shrunk toward none by `--strength`
sentences so a word seen a few times barely moves it. The first word's boosts, scaled by
`--first-weight`, only bring openers forward, never push one back, so a first word common to
many sentences ("can" in "Can you...?") never outweighs who the sentence was about, and never
favor that word itself. Only a word that refers to a person or thing
carries over, and only into an opener that stands for one: a pronoun opens the next sentence
again, as "they" makes "They" likelier (scaled by `--repeat-weight`), and a noun or another
pronoun pulls the pronoun that refers back to it, as "man" makes "He" likelier (scaled by
`--word-weight`). Which words those are comes from `--word-kinds`, each word's lexical class
written by tag_word_kinds.swift. At most `--per-word` boosts are kept per word, each only when
it moves an opener by at least `--floor`. The bar shows the three best-scoring openers.

Each source's counts from count_sentence_openers.py are weighted (`--weight source=w`), and
its word evidence may be weighted apart (`--word-source source=w`): a word's pull on the next
sentence's opener is a ratio within the sources, so a source whose openers are of the wrong
style can still show which words pull which openers. A
bare line break gets no ending of its own and so the general openers: in the sources it
mostly breaks lists and code rather than messages.

Held-out texts are scored by how often the next sentence's first word is among the three;
with `--apple`, the three are compared with Apple's suggestion bars for the same text.

The defaults were tuned against Apple's suggestion bars after 136 sentences, captured with
Tools/AppleKeyboardBaseline, for words shared with Apple, for Apple's habit of offering a word
from the sentence just typed, and for how many different bars it shows. The bundled model
was written with `--weight youtube-commons=0 --weight oasst2=0.3 --weight tatoeba=10`.

The output must match `SentenceOpeners` in KeyVoxPredictiveKeyboard. Each line is a kind,
a key, a tab, and `word:value` pairs:
    ending <period|question|exclamation|*>   every opener with its log likelihood
    first <ending> <first word>              boosts for the previous sentence's first word
    word <ending> <word>                     boosts for a word in the previous sentence
"""

import argparse
import json
import math
import pickle
from collections import Counter, defaultdict
from pathlib import Path

from normalize import LINE_BREAK, sentences_with_endings

ANY = "*"
ENDING_NAMES = {".": "period", "?": "question", "!": "exclamation"}
_BAR_SLOTS = 3
# Lexical classes, as tag_word_kinds.swift writes them, of the words that refer to people or
# things, and of the openers that stand for them.
REFERRING_KINDS = {"Noun", "Pronoun", "Determiner"}
STANDING_IN_KINDS = {"Pronoun"}


def weighted_sources(sources: dict, weights: dict[str, float], word_weights: dict[str, float]):
    """The sources' counts summed by weight: openers and contexts by `weights`, and the word
    evidence (with the next sentences' openers it is measured against) by `word_weights`."""
    openers: Counter = Counter()
    contexts: defaultdict = defaultdict(Counter)
    word_pairs: Counter = Counter()
    word_sentences: Counter = Counter()
    word_openers: defaultdict = defaultdict(Counter)
    for name, counts in sources.items():
        weight = weights.get(name, 1.0)
        word_weight = word_weights.get(name, weight)
        for (ending, first, _), following in counts["contexts"].items():
            if ending == LINE_BREAK:
                continue
            target = contexts[(ending, first)]
            for word, count in following.items():
                if weight > 0:
                    target[word] += count * weight
                if word_weight > 0:
                    word_openers[ending][word] += count * word_weight
        if weight > 0:
            for word, count in counts["openers"].items():
                openers[word] += count * weight
        if word_weight > 0:
            for pair, count in counts["word_pairs"].items():
                word_pairs[pair] += count * word_weight
            for word, count in counts["word_sentences"].items():
                word_sentences[word] += count * word_weight
    return openers, {key: value for key, value in contexts.items() if value}, word_pairs, word_sentences, word_openers


def boosts(following: Counter, total: float, expected: dict[str, float], strength: float,
           scale: float, floor: float, limit: int, same_word: str | None = None,
           same_word_scale: float = 0) -> dict[str, float]:
    """Each opener's scaled log ratio of its likelihood given the evidence, smoothed toward
    the expected likelihood, to the expected likelihood: the strongest `limit` of at least
    `floor`. The opener `same_word`, the evidence's own word, is scaled by `same_word_scale`
    instead and kept apart from the limit."""
    moved = []
    kept_same_word = {}
    for word, count in following.items():
        if word not in expected:
            continue
        given = (count + strength * expected[word]) / (total + strength)
        ratio = math.log(given / expected[word])
        if word == same_word:
            if abs(same_word_scale * ratio) >= floor:
                kept_same_word[word] = same_word_scale * ratio
        elif abs(scale * ratio) >= floor:
            moved.append((word, scale * ratio))
    moved.sort(key=lambda item: (-abs(item[1]), item[0]))
    return kept_same_word | dict(moved[:limit])


class OpenerModel:
    def __init__(self, sources: dict, weights: dict[str, float], word_weights: dict[str, float],
                 kinds: dict[str, str], arguments):
        openers, contexts, word_pairs, word_sentences, word_openers = weighted_sources(sources, weights, word_weights)
        vocabulary = [word for word, _ in openers.most_common(arguments.openers)]
        total = sum(openers[word] for word in vocabulary)
        general = {word: openers[word] / total for word in vocabulary}

        by_ending: defaultdict = defaultdict(Counter)
        for (ending, _), following in contexts.items():
            by_ending[ending].update(following)
        self.endings = {ANY: general}
        for ending, following in by_ending.items():
            ending_total = sum(following.values())
            self.endings[ending] = {
                word: (following.get(word, 0) + arguments.strength * general[word]) / (ending_total + arguments.strength)
                for word in vocabulary
            }

        self.first = {}
        for (ending, first), following in contexts.items():
            first_total = sum(following.values())
            if first_total >= arguments.minimum:
                others = Counter({word: count for word, count in following.items() if word != first})
                moved = boosts(others, first_total, self.endings[ending], arguments.strength,
                               arguments.first_weight, arguments.floor, arguments.per_word)
                moved = {word: boost for word, boost in moved.items() if boost > 0}
                if moved:
                    self.first[(ending, first)] = moved

        # A word's evidence is measured against the openers of the same sources' next sentences
        # after the same ending.
        expected = {}
        for ending, following in word_openers.items():
            ending_total = sum(following[word] for word in vocabulary)
            expected[ending] = {word: following[word] / ending_total for word in vocabulary if following[word] > 0}
        standing_in = {word for word in vocabulary if kinds.get(word) in STANDING_IN_KINDS}
        following_by_word: defaultdict = defaultdict(Counter)
        for (ending, word, opener), count in word_pairs.items():
            if kinds.get(word) in REFERRING_KINDS and opener in standing_in:
                following_by_word[(ending, word)][opener] = count
        self.words = {}
        for (ending, word), following in following_by_word.items():
            sentences = word_sentences[(ending, word)]
            if sentences >= arguments.minimum:
                moved = boosts(following, sentences, expected[ending], arguments.strength,
                               arguments.word_weight, arguments.floor, arguments.per_word,
                               same_word=word, same_word_scale=arguments.repeat_weight)
                if moved:
                    self.words[(ending, word)] = moved

    def lookup(self, ending: str | None, first: str | None, words) -> list[str]:
        """The best openers after a previous sentence that ended with `ending`; with no earlier
        sentence, or after a bare line break, the general openers."""
        known = ending in ENDING_NAMES and ending in self.endings
        scores = {word: math.log(p) for word, p in self.endings[ending if known else ANY].items()}
        if known:
            for opener, boost in self.first.get((ending, first), {}).items():
                scores[opener] += boost
            for word in set(words or ()):
                for opener, boost in self.words.get((ending, word), {}).items():
                    scores[opener] += boost
        return [word for word, _ in sorted(scores.items(), key=lambda item: (-item[1], item[0]))[:_BAR_SLOTS]]

    def lines(self) -> list[str]:
        def pairs(values: dict[str, float]) -> str:
            return " ".join(f"{word}:{value:.3f}" for word, value in values.items())

        lines = [f"ending {ENDING_NAMES.get(ending, ANY)}\t{pairs({w: math.log(p) for w, p in distribution.items()})}"
                 for ending, distribution in self.endings.items()]
        lines += [f"first {ENDING_NAMES[ending]} {first}\t{pairs(moved)}" for (ending, first), moved in self.first.items()]
        lines += [f"word {ENDING_NAMES[ending]} {word}\t{pairs(moved)}" for (ending, word), moved in self.words.items()]
        return sorted(lines)


def held_out_scores(model: OpenerModel, sources: dict) -> dict[str, tuple[float, int]]:
    scores = {}
    for name, counts in sources.items():
        held_out = counts["held_out"]
        if held_out:
            hits = sum(following in model.lookup(ending, first, words) for ending, first, _, words, following in held_out)
            scores[name] = (hits / len(held_out), len(held_out))
    return scores


def apple_comparison(model: OpenerModel, paths: list[Path]) -> tuple[float, int, int]:
    """Mean words shared with Apple's bars, and how many different bars each shows."""
    shared, ours, apple, count = 0, set(), set(), 0
    for path in paths:
        for probe in json.loads(path.read_text(encoding="utf-8")):
            bar = [word.lower().replace("’", "'") for word in probe["bar"]]
            sentences = list(sentences_with_endings(probe.get("text") or ""))
            if sentences and sentences[-1][1]:
                words, ending = sentences[-1]
                predicted = model.lookup(ending, words[0], words)
            else:
                predicted = model.lookup(None, None, None)
            shared += len(set(predicted) & set(bar))
            ours.add(tuple(sorted(predicted)))
            apple.add(tuple(sorted(bar)))
            count += 1
    return shared / count, len(ours), len(apple)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--weight", action="append", default=[], help="source=weight")
    parser.add_argument("--word-source", action="append", default=[],
                        help="source=weight for the word evidence, if not the source's --weight")
    parser.add_argument("--openers", type=int, default=300)
    parser.add_argument("--strength", type=float, default=100)
    parser.add_argument("--minimum", type=float, default=20)
    parser.add_argument("--first-weight", type=float, default=0.5)
    parser.add_argument("--word-weight", type=float, default=1.0)
    parser.add_argument("--repeat-weight", type=float, default=1.5)
    parser.add_argument("--floor", type=float, default=0.3)
    parser.add_argument("--per-word", type=int, default=8)
    parser.add_argument("--word-kinds", type=Path, help="default: <data_dir>/word_kinds.tsv")
    parser.add_argument("--apple", type=Path, action="append", default=[])
    arguments = parser.parse_args()

    weights = {name: float(weight) for name, _, weight in (item.partition("=") for item in arguments.weight)}
    word_weights = {name: float(weight) for name, _, weight in (item.partition("=") for item in arguments.word_source)}
    sources = {}
    for path in sorted((arguments.data_dir / "openers").glob("*.pkl")):
        with open(path, "rb") as source:
            sources[path.stem] = pickle.load(source)
    kinds_path = arguments.word_kinds or arguments.data_dir / "word_kinds.tsv"
    with open(kinds_path, encoding="utf-8") as lines:
        kinds = dict(line.rstrip("\n").split("\t") for line in lines)
    model = OpenerModel(sources, weights, word_weights, kinds, arguments)

    for name, (hits, count) in held_out_scores(model, sources).items():
        print(f"held out {name}: next sentence's first word in the bar {hits:.1%} ({count} sentences)")
    if arguments.apple:
        shared, ours, apple = apple_comparison(model, arguments.apple)
        print(f"Apple: {shared:.2f} of 3 words shared; {ours} different bars (Apple {apple})")
    lines = model.lines()
    if arguments.output:
        arguments.output.write_text("".join(f"{line}\n" for line in lines), encoding="utf-8")
    print(f"{len(lines)} lines, {len(model.words)} words with boosts")


if __name__ == "__main__":
    main()

"""The features the rankers and the action model score, in the order the keyboard's native
engine computes them: 23 per candidate word, and 14 for the decision to correct.

The engine measures words in UTF-8 bytes: lengths, edit distances, shared beginnings and endings,
first and last letters, and repeated letters are of the words' bytes, so they are here too, and a
letter outside ASCII counts as two bytes or more. Only whether a short word has a vowel is of its
letters, the language's vowels (`language.json`)."""

import math
import sys

from latinime_candidates import candidate_items, query_key
from words import damerau_osa


def candidate_features(record, candidate, score, suggestion_type, rank, context):
    typed = record["typed"].encode()
    candidate_word = candidate
    candidate = candidate.encode()
    distance = damerau_osa(typed, candidate)
    longest = max(1, len(typed), len(candidate))
    common_prefix = 0
    for left, right in zip(typed, candidate):
        if left != right:
            break
        common_prefix += 1
    common_suffix = 0
    for left, right in zip(reversed(typed), reversed(candidate)):
        if left != right:
            break
        common_suffix += 1
    unigram = context.unigram(candidate_word)
    bigram = (context.bigram(record["previous"][0], candidate_word)
              if record["previous"] else (0.0, math.log(0.25), 0.0))
    return [
        score / 1_000_000.0, float(rank), 1.0 / (rank + 1), suggestion_type,
        distance, distance / longest, len(typed), len(candidate),
        abs(len(typed) - len(candidate)), common_prefix / longest,
        common_suffix / longest, float(typed[:1] == candidate[:1]),
        float(typed[-1:] == candidate[-1:]),
        float(len(typed) == len(candidate) and distance == 1),
        float(b"'" in typed), float(b"'" in candidate),
        float(bool(record["previous"])), min(3, len(record["previous"])),
        *unigram, *bigram,
    ]


def candidate_groups(records, outputs, context, label):
    """For each record with candidates: the record, its candidates, their feature rows, and
    which candidate is the intended word.

    A record whose query the candidate cache never asked, or whose cached candidates are only
    the typed letters or two-word suggestions, is left out; how many is printed under `label`."""
    groups = []
    considered = never_asked = no_candidates = 0
    for record in records:
        considered += 1
        choices = candidate_items(record, outputs)
        if not choices:
            if query_key(record["typed"], record["previous"]) in outputs:
                no_candidates += 1
            else:
                never_asked += 1
            continue
        rows = [candidate_features(record, candidate, score, kind, rank, context)
                for rank, (candidate, score, kind) in enumerate(choices)]
        labels = [int(candidate == record["expected"]) for candidate, _, _ in choices]
        groups.append((record, choices, rows, labels))
    print(f"{label}: {considered:,} records, {len(groups):,} kept, {never_asked:,} left out as "
          f"never asked, {no_candidates:,} left out with no candidates", file=sys.stderr)
    return groups


def has_triple_repeat(word):
    """Whether three bytes in a row are the same, as the engine checks."""
    return any(word[index] == word[index - 1] == word[index - 2] for index in range(2, len(word)))


def candidate_is_actionable(record, candidate, valid_words, vowels):
    """Whether the engine lets the action model replace the typed letters with the candidate."""
    letters = record["typed"]
    typed = letters.encode()
    candidate = candidate.encode()
    if not typed or letters in valid_words or len(typed) < 2:
        return False
    if has_triple_repeat(typed):
        return False
    distance = damerau_osa(typed, candidate)
    longest = max(len(typed), len(candidate))
    if (distance >= len(candidate) or distance > 4
            or distance / max(1, longest) > 0.5):
        return False
    if len(letters) <= 4 and not any(letter in vowels for letter in letters):
        return False
    if len(typed) >= 2 and typed[-1] == typed[-2] and candidate.startswith(typed):
        return False
    return True


def action_features(ranked):
    record, choices, _, probabilities, ordering = ranked
    best = ordering[0]
    second = ordering[1] if len(ordering) > 1 else best
    candidate, latin_score, _ = choices[best]
    raw_top_score = choices[0][1]
    typed, candidate_bytes = record["typed"].encode(), candidate.encode()
    distance = damerau_osa(typed, candidate_bytes)
    longest = max(1, len(typed), len(candidate_bytes))
    return [
        probabilities[best], probabilities[second],
        probabilities[best] - probabilities[second],
        probabilities[best] / max(1e-6, probabilities[second]),
        float(best), latin_score / 1_000_000.0, raw_top_score / 1_000_000.0,
        (latin_score - raw_top_score) / 1_000_000.0,
        distance, distance / longest, len(typed), len(candidate_bytes),
        float(best == 0), float(bool(record["previous"])),
    ], candidate

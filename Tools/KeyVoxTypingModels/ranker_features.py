"""The features the rankers and the action model score, in the order the keyboard's native
engine computes them: 23 per candidate word, and 14 for the decision to correct."""

import math
import re
import sys

from latinime_candidates import candidate_items, query_key
from words import damerau_osa


def candidate_features(record, candidate, score, suggestion_type, rank, context):
    typed = record["typed"]
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
    unigram = context.unigram(candidate)
    bigram = (context.bigram(record["previous"][0], candidate)
              if record["previous"] else (0.0, math.log(0.25), 0.0))
    return [
        score / 1_000_000.0, float(rank), 1.0 / (rank + 1), suggestion_type,
        distance, distance / longest, len(typed), len(candidate),
        abs(len(typed) - len(candidate)), common_prefix / longest,
        common_suffix / longest, float(typed[:1] == candidate[:1]),
        float(typed[-1:] == candidate[-1:]),
        float(len(typed) == len(candidate) and distance == 1),
        float("'" in typed), float("'" in candidate),
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


def candidate_is_actionable(record, candidate, valid_words):
    typed = record["typed"]
    if not typed or typed in valid_words or len(typed) < 2:
        return False
    if re.search(r"(.)\1\1", typed):
        return False
    distance = damerau_osa(typed, candidate)
    longest = max(len(typed), len(candidate))
    if (distance >= len(candidate) or distance > 4
            or distance / max(1, longest) > 0.5):
        return False
    if len(typed) <= 4 and not re.search(r"[aeiouy]", typed):
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
    distance = damerau_osa(record["typed"], candidate)
    longest = max(1, len(record["typed"]), len(candidate))
    return [
        probabilities[best], probabilities[second],
        probabilities[best] - probabilities[second],
        probabilities[best] / max(1e-6, probabilities[second]),
        float(best), latin_score / 1_000_000.0, raw_top_score / 1_000_000.0,
        (latin_score - raw_top_score) / 1_000_000.0,
        distance, distance / longest, len(record["typed"]), len(candidate),
        float(best == 0), float(bool(record["previous"])),
    ], candidate

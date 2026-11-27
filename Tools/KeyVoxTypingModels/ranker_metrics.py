"""Measures trained rankers and action models on held-out records: how often the intended
word ranks first or in the top three, and how often acting at a confidence threshold fixes,
breaks, or leaves a word."""

import numpy as np

from ranker_features import action_features, candidate_is_actionable
from tree_training import rank_groups

FIXED_THRESHOLDS = (0.999, 0.9975, 0.995, 0.99, 0.98, 0.95, 0.9)


def ranking_metrics(groups, ranker):
    baseline_top1 = baseline_top3 = reranked_top1 = reranked_top3 = oracle = 0
    for _, _, labels, _, ordering in rank_groups(groups, ranker):
        oracle += int(any(labels))
        baseline_top1 += int(bool(labels) and labels[0] == 1)
        baseline_top3 += int(any(labels[:3]))
        reranked_top1 += int(bool(labels) and labels[ordering[0]] == 1)
        reranked_top3 += int(any(labels[index] for index in ordering[:3]))
    total = max(1, len(groups))
    return {
        "count": len(groups), "oracle_top8": oracle / total,
        "latinime_top1": baseline_top1 / total, "latinime_top3": baseline_top3 / total,
        "reranked_top1": reranked_top1 / total, "reranked_top3": reranked_top3 / total,
    }


def action_scores(groups, ranker, action_model, valid_words, vowels):
    prepared = []
    for ranked in rank_groups(groups, ranker):
        features, candidate = action_features(ranked)
        prepared.append((ranked[0], candidate, features))
    probabilities = (action_model.predict_proba(
        np.asarray([entry[2] for entry in prepared]))[:, 1] if prepared else [])
    results = []
    for (record, candidate, _), probability in zip(prepared, probabilities):
        if not candidate_is_actionable(record, candidate, valid_words, vowels):
            probability = -1.0
        results.append((record, candidate, float(probability)))
    return results


def typed_word_outcomes(correction_results, preserve_results, threshold, typed_words):
    """What acting at the threshold leaves of every word typed in the held-out simulation
    sentences (`write_simulated_records.py`'s `typed_words.json` counts): the share of words right
    in the end, of mistyped words fixed or changed to another word, of the mistyped words not typed
    as a word the action model never replaces fixed, and of words typed as meant changed. Only the
    typos the action model may fix and the words typed as meant that it may replace, the ones no
    dictionary or never-corrected word spells, are scored; every other word is left as typed."""
    fixed = changed = 0
    for record, candidate, probability in correction_results:
        if probability >= threshold:
            if candidate == record["expected"]:
                fixed += 1
            else:
                changed += 1
    wrongly_changed = sum(1 for _, _, probability in preserve_results if probability >= threshold)
    words = typed_words["words"]
    mistyped = typed_words["mistyped"]
    as_a_word = typed_words["mistyped_as_a_word"]
    typed_as_meant = words - mistyped
    return {
        "words": words, "mistyped": mistyped, "mistyped_as_a_word": as_a_word,
        "final_words_correct": (typed_as_meant - wrongly_changed + fixed) / max(1, words),
        "mistyped_fixed": fixed / max(1, mistyped),
        "mistyped_fixed_of_those_not_typed_as_a_word": fixed / max(1, mistyped - as_a_word),
        "mistyped_changed_to_another_word": changed / max(1, mistyped),
        "correct_words_wrongly_changed": wrongly_changed / max(1, typed_as_meant),
    }


def evaluate_actions(results, threshold, total_count):
    exact = wrong = 0
    no_action = max(0, total_count - len(results))
    for record, candidate, probability in results:
        if probability < threshold:
            no_action += 1
        elif candidate == record["expected"]:
            exact += 1
        else:
            wrong += 1
    total = max(1, total_count)
    return {"count": total_count, "correct": exact / total, "wrong": wrong / total,
            "no_action": no_action / total}

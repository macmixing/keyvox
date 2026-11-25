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


def action_scores(groups, ranker, action_model, valid_words):
    prepared = []
    for ranked in rank_groups(groups, ranker):
        features, candidate = action_features(ranked)
        prepared.append((ranked[0], candidate, features))
    probabilities = (action_model.predict_proba(
        np.asarray([entry[2] for entry in prepared]))[:, 1] if prepared else [])
    results = []
    for (record, candidate, _), probability in zip(prepared, probabilities):
        if not candidate_is_actionable(record, candidate, valid_words):
            probability = -1.0
        results.append((record, candidate, float(probability)))
    return results


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

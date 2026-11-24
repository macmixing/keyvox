"""Trains the gradient-boosted trees the keyboard runs: a ranker that scores each candidate
word, and an action model that decides whether to replace the typed letters with the
ranker's best candidate."""

import numpy as np
from sklearn.ensemble import HistGradientBoostingClassifier

from ranker_features import action_features, candidate_is_actionable


def fit_ranker(groups):
    """Trains on every candidate of the groups whose candidates include the intended word."""
    rows = []
    labels = []
    for _, _, features, group_labels in groups:
        if not any(group_labels):
            continue
        rows.extend(features)
        labels.extend(group_labels)
    model = HistGradientBoostingClassifier(
        learning_rate=0.055, max_iter=220, max_leaf_nodes=23,
        min_samples_leaf=160, l2_regularization=3.0, random_state=29,
    )
    model.fit(np.asarray(rows), np.asarray(labels))
    return model, len(labels)


def rank_groups(groups, ranker):
    """Each group with the ranker's probability for every candidate and the candidates'
    order, best first."""
    lengths = [len(group[2]) for group in groups]
    rows = [row for group in groups for row in group[2]]
    all_probabilities = (ranker.predict_proba(np.asarray(rows))[:, 1]
                         if rows else np.asarray([]))
    ranked = []
    offset = 0
    for group, length in zip(groups, lengths):
        record, choices, _, labels = group
        probabilities = all_probabilities[offset:offset + length]
        offset += length
        ordering = sorted(range(len(choices)),
                          key=lambda index: (-probabilities[index], index))
        ranked.append((record, choices, labels, probabilities, ordering))
    return ranked


def fit_action_model(correction_groups, preserve_groups, ranker, valid_words):
    """Trains on the ranker's best candidate for typos and for words typed as meant, where
    replacing the typed letters would be allowed at all."""
    rows = []
    labels = []
    for ranked in rank_groups(correction_groups + preserve_groups, ranker):
        features, candidate = action_features(ranked)
        if not candidate_is_actionable(ranked[0], candidate, valid_words):
            continue
        rows.append(features)
        labels.append(int(candidate == ranked[0]["expected"]))
    model = HistGradientBoostingClassifier(
        learning_rate=0.05, max_iter=160, max_leaf_nodes=11,
        min_samples_leaf=80, l2_regularization=4.0, random_state=31,
    )
    model.fit(np.asarray(rows), np.asarray(labels))
    return model, len(labels)

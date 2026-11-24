"""Trains the correction ranker and the action model from the cached LatinIME candidates and
writes them to `<data_dir>/work/correction_ranker.pkl.gz` and `action.pkl.gz`, with a
report of how they do on held-out sentences.

They train on the records `training_sets.correction_sets` gives: records are split by the
sentence being copied, buckets 0-4 train the ranker, bucket 5 the action model, and buckets
8-9 are held out for the report."""

import argparse
import gzip
import json
import pickle
from pathlib import Path

import latinime_candidates
from feature_context_model import FeatureContextModel
from never_corrected_words import never_corrected_words
from paths import DataPaths
from ranker_features import candidate_groups
from ranker_metrics import FIXED_THRESHOLDS, action_scores, evaluate_actions, ranking_metrics
from training_sets import correction_sets
from tree_training import fit_action_model, fit_ranker


def save(model, path):
    with gzip.open(path, "wb", compresslevel=9) as target:
        pickle.dump(model, target, protocol=pickle.HIGHEST_PROTOCOL)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("data_dir", type=Path)
    arguments = parser.parse_args()
    paths = DataPaths(arguments.data_dir)

    outputs = latinime_candidates.load(paths.correction_candidates)
    context = FeatureContextModel(paths.feature_context_model)
    protected = never_corrected_words(paths)
    sets = correction_sets(paths)

    ranker, ranker_rows = fit_ranker(
        candidate_groups(sets.ranker_typos, outputs, context, "correction ranker training"))
    action, action_rows = fit_action_model(
        candidate_groups(sets.action_typos, outputs, context, "action model training, typos"),
        candidate_groups(sets.action_preserves, outputs, context,
                         "action model training, words typed as meant"),
        ranker, protected)
    save(ranker, paths.correction_ranker_model)
    save(action, paths.action_model)

    test_corrections = candidate_groups(sets.test_typos, outputs, context, "held-out typos")
    test_preserves = candidate_groups(sets.test_preserves, outputs, context,
                                      "held-out words typed as meant")
    correction_scores = action_scores(test_corrections, ranker, action, protected)
    preserve_scores = action_scores(test_preserves, ranker, action, protected)
    external_scores = action_scores(candidate_groups(sets.external, outputs, context,
                                                     "copied-sentence and expressive words"),
                                    ranker, action, protected)
    report = {
        "ranker_training_rows": ranker_rows,
        "action_training_rows": action_rows,
        "ranking_test": ranking_metrics(test_corrections, ranker),
        "action_test": {
            str(threshold): {
                "correction": evaluate_actions(correction_scores, threshold,
                                               len(sets.test_typos)),
                "preserve": evaluate_actions(preserve_scores, threshold,
                                             len(sets.test_preserves)),
                "external_preserve": evaluate_actions(external_scores, threshold,
                                                      len(sets.external)),
            }
            for threshold in FIXED_THRESHOLDS
        },
    }
    paths.report("correction_models").parent.mkdir(parents=True, exist_ok=True)
    paths.report("correction_models").write_text(
        json.dumps(report, indent=2, sort_keys=True), encoding="utf-8")
    print(json.dumps(report, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

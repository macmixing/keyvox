"""Trains the correction ranker and the action model from the cached LatinIME candidates and
writes them to `<data_dir>/work/correction_ranker.pkl.gz` and `action.pkl.gz`, with a
report of how they do on held-out sentences.

Records are split by the sentence being copied: buckets 0-4 train the ranker, bucket 5
the action model, and buckets 8-9 are held out for the report."""

import argparse
import gzip
import json
import pickle
from pathlib import Path

import latinime_candidates
from feature_context_model import FeatureContextModel
from ite_records import (
    annotate, clean_sentence_records, expressive_records, load_section_sentences,
    plausible_corrections, read_records, sample_calibration,
)
from paths import DataPaths
from ranker_features import candidate_groups
from ranker_metrics import FIXED_THRESHOLDS, action_scores, evaluate_actions, ranking_metrics
from tree_training import fit_action_model, fit_ranker
from words import clean

RANKER_BUCKETS = {0, 1, 2, 3, 4}
ACTION_BUCKETS = {5}
TEST_BUCKETS = {8, 9}


def valid_words(paths):
    """Dictionary words and SCOWL size-50 words of every spelling, which are never corrected."""
    words = {line.split("\t", 1)[0] for line in
             paths.dictionary_unigrams.read_text(encoding="utf-8").splitlines()}
    words.update(clean(word) for word in
                 paths.protected_words.read_text(encoding="utf-8").splitlines())
    return words


def save(model, path):
    with gzip.open(path, "wb", compresslevel=9) as target:
        pickle.dump(model, target, protocol=pickle.HIGHEST_PROTOCOL)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("data_dir", type=Path)
    data_dir = parser.parse_args().data_dir
    paths = DataPaths(data_dir)

    outputs = latinime_candidates.load(paths.correction_candidates)
    context = FeatureContextModel(paths.feature_context_model)
    section_sentences = load_section_sentences(data_dir)
    protected = valid_words(paths)

    corrections = annotate(plausible_corrections(
        sample_calibration(read_records(paths.ite_split("ac_success_calibration")))
        + read_records(paths.ite_split("ac_success_holdout"))
        + read_records(paths.ite_split("ac_harm_holdout"), harm=True)
    ), section_sentences)
    preserves = annotate(read_records(paths.ite_split("preserve_calibration"))
                         + read_records(paths.ite_split("preserve_holdout")), section_sentences)
    clean_preserve, _ = clean_sentence_records(data_dir)
    external = annotate(clean_preserve + expressive_records(), section_sentences)

    ranker, ranker_rows = fit_ranker(
        candidate_groups(corrections, outputs, context, "correction ranker training",
                         RANKER_BUCKETS))
    action, action_rows = fit_action_model(
        candidate_groups(corrections, outputs, context, "action model training, typos",
                         ACTION_BUCKETS),
        candidate_groups(preserves, outputs, context, "action model training, words typed as meant",
                         ACTION_BUCKETS),
        ranker, protected)
    save(ranker, paths.correction_ranker_model)
    save(action, paths.action_model)

    test_corrections = candidate_groups(corrections, outputs, context, "held-out typos",
                                        TEST_BUCKETS)
    test_preserves = candidate_groups(preserves, outputs, context, "held-out words typed as meant",
                                      TEST_BUCKETS)
    correction_scores = action_scores(test_corrections, ranker, action, protected)
    preserve_scores = action_scores(test_preserves, ranker, action, protected)
    external_scores = action_scores(candidate_groups(external, outputs, context,
                                                     "copied-sentence and expressive words"),
                                    ranker, action, protected)
    correction_count = sum(record["bucket"] in TEST_BUCKETS for record in corrections)
    preserve_count = sum(record["bucket"] in TEST_BUCKETS for record in preserves)
    report = {
        "ranker_training_rows": ranker_rows,
        "action_training_rows": action_rows,
        "ranking_test": ranking_metrics(test_corrections, ranker),
        "action_test": {
            str(threshold): {
                "correction": evaluate_actions(correction_scores, threshold, correction_count),
                "preserve": evaluate_actions(preserve_scores, threshold, preserve_count),
                "external_preserve": evaluate_actions(external_scores, threshold, len(external)),
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

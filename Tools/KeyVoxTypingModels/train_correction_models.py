"""Trains the correction ranker and the action model from the cached LatinIME candidates and
writes them to `<data_dir>/work/correction_ranker.pkl.gz` and `action.pkl.gz`, with a
report of how they do on held-out sentences.

They train on the records `training_sets.correction_sets` gives for the language (`--language`)
and training source (`--source`, `ite` for English and `sim` for any other language unless given):
records are split by the sentence being typed, buckets 0-4 train the ranker, bucket 5 the action
model, and buckets 8-9, ITE's for English and simulated ones for any other language, are held out
for the report.

For a language trained on simulated typing alone, the report also scores, at each threshold, every
word typed in the held-out simulation sentences (`ranker_metrics.typed_word_outcomes`): the words
right in the end, the mistyped words fixed or changed to another word, and the words typed as
meant that were changed."""

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
from ranker_metrics import (
    FIXED_THRESHOLDS, action_scores, evaluate_actions, ranking_metrics, typed_word_outcomes,
)
from training_sets import SOURCES, TEST_BUCKETS, correction_sets, training_source
from tree_training import fit_action_model, fit_ranker
from typing_languages import add_language_arguments, language_from


def save(model, path):
    with gzip.open(path, "wb", compresslevel=9) as target:
        pickle.dump(model, target, protocol=pickle.HIGHEST_PROTOCOL)


def held_out_typed_words(paths):
    """How many words the held-out simulation sentences were typed with, and how many mistyped."""
    buckets = json.loads(paths.simulated_typed_words.read_text(encoding="utf-8"))["buckets"]
    return {name: sum(buckets[str(bucket)][name] for bucket in TEST_BUCKETS)
            for name in ("words", "mistyped", "mistyped_as_a_word")}


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("--source", choices=SOURCES,
                        help="the training source (default: ite for English, sim otherwise)")
    add_language_arguments(parser)
    arguments = parser.parse_args()
    paths = DataPaths(arguments.data_dir)
    language = language_from(arguments)
    vowels = language.vowels

    outputs = latinime_candidates.load(paths.correction_candidates)
    context = FeatureContextModel(paths.feature_context_model)
    protected = never_corrected_words(paths, language)
    sets = correction_sets(paths, training_source(arguments.source, language), language)

    ranker, ranker_rows = fit_ranker(
        candidate_groups(sets.ranker_typos, outputs, context, "correction ranker training"))
    action, action_rows = fit_action_model(
        candidate_groups(sets.action_typos, outputs, context, "action model training, typos"),
        candidate_groups(sets.action_preserves, outputs, context,
                         "action model training, words typed as meant"),
        ranker, protected, vowels)
    save(ranker, paths.correction_ranker_model)
    save(action, paths.action_model)

    test_corrections = candidate_groups(sets.test_typos, outputs, context, "held-out typos")
    test_preserves = candidate_groups(sets.test_preserves, outputs, context,
                                      "held-out words typed as meant")
    correction_scores = action_scores(test_corrections, ranker, action, protected, vowels)
    preserve_scores = action_scores(test_preserves, ranker, action, protected, vowels)
    external_scores = action_scores(candidate_groups(sets.external, outputs, context,
                                                     "copied-sentence and expressive words"),
                                    ranker, action, protected, vowels)
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
    if not language.uses_english_text:
        typed_words = held_out_typed_words(paths)
        report["held_out_words"] = {
            str(threshold): typed_word_outcomes(correction_scores, preserve_scores, threshold,
                                                typed_words)
            for threshold in FIXED_THRESHOLDS
        }
    paths.report("correction_models").parent.mkdir(parents=True, exist_ok=True)
    paths.report("correction_models").write_text(
        json.dumps(report, indent=2, sort_keys=True), encoding="utf-8")
    print(json.dumps(report, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

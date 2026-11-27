"""Trains the completion ranker, which scores candidates while a word is still being typed,
and writes it to `<data_dir>/work/completion_ranker.pkl.gz` with a held-out report.

Trains on the records `training_sets.completion_sets` gives for the language (`--language`) and
training source (`--source`, `ite` for English and `sim` for any other language unless given):
every ITE typist's accepted word completions, simulated ones, or both, each the letters typed so
far, the word picked, and the words before it, with LatinIME's candidates for them from
`cache_completion_candidates.py`. Records are split by the sentence being typed: buckets 0-7
train, and buckets 8-9, ITE's for English and simulated ones for any other language, are held
out."""

import argparse
import gzip
import json
import pickle
from pathlib import Path

import latinime_candidates
from feature_context_model import FeatureContextModel
from paths import DataPaths
from ranker_features import candidate_groups
from ranker_metrics import ranking_metrics
from training_sets import SOURCES, completion_sets, training_source
from tree_training import fit_ranker
from typing_languages import add_language_arguments, language_from


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("--source", choices=SOURCES,
                        help="the training source (default: ite for English, sim otherwise)")
    add_language_arguments(parser)
    arguments = parser.parse_args()
    paths = DataPaths(arguments.data_dir)
    language = language_from(arguments)

    training, held_out = completion_sets(paths, training_source(arguments.source, language),
                                         language)
    outputs = latinime_candidates.load(paths.completion_candidates)
    context = FeatureContextModel(paths.feature_context_model)
    ranker, training_rows = fit_ranker(candidate_groups(
        training, outputs, context, "completion ranker training"))
    test = candidate_groups(held_out, outputs, context, "held-out completions")
    with gzip.open(paths.completion_ranker_model, "wb", compresslevel=9) as target:
        pickle.dump(ranker, target, protocol=pickle.HIGHEST_PROTOCOL)

    report = {
        "records": len(training) + len(held_out), "training_rows": training_rows,
        "test_groups": len(test), "sentence_disjoint_test": ranking_metrics(test, ranker),
    }
    paths.report("completion_ranker").parent.mkdir(parents=True, exist_ok=True)
    paths.report("completion_ranker").write_text(
        json.dumps(report, indent=2, sort_keys=True), encoding="utf-8")
    print(json.dumps(report, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

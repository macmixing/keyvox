"""Trains the completion ranker, which scores candidates while a word is still being typed,
and writes it to `<data_dir>/work/completion_ranker.pkl.gz` with a held-out report.

Trains on every typist's accepted ITE word completions: the letters typed so far, the word
the typist picked, and the words before it, with LatinIME's candidates for them from
`cache_completion_candidates.py`. Records are split by the sentence being
copied: buckets 0-7 train, 8-9 are held out."""

import argparse
import gzip
import json
import pickle
from pathlib import Path

import latinime_candidates
from feature_context_model import FeatureContextModel
from ite_records import annotate, completion_records, load_section_sentences
from paths import DataPaths
from ranker_features import candidate_groups
from ranker_metrics import ranking_metrics
from tree_training import fit_ranker

TRAIN_BUCKETS = {0, 1, 2, 3, 4, 5, 6, 7}
TEST_BUCKETS = {8, 9}


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("data_dir", type=Path)
    data_dir = parser.parse_args().data_dir
    paths = DataPaths(data_dir)

    records = annotate(completion_records(data_dir), load_section_sentences(data_dir))
    outputs = latinime_candidates.load(paths.completion_candidates)
    context = FeatureContextModel(paths.feature_context_model)
    ranker, training_rows = fit_ranker(candidate_groups(records, outputs, context, TRAIN_BUCKETS))
    test = candidate_groups(records, outputs, context, TEST_BUCKETS)
    with gzip.open(paths.completion_ranker_model, "wb", compresslevel=9) as target:
        pickle.dump(ranker, target, protocol=pickle.HIGHEST_PROTOCOL)

    report = {
        "records": len(records), "training_rows": training_rows,
        "test_groups": len(test), "sentence_disjoint_test": ranking_metrics(test, ranker),
    }
    paths.report("completion_ranker").parent.mkdir(parents=True, exist_ok=True)
    paths.report("completion_ranker").write_text(
        json.dumps(report, indent=2, sort_keys=True), encoding="utf-8")
    print(json.dumps(report, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

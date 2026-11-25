"""Asks the compiled dictionary for its candidates for every correction query the correction
ranker and action model are trained and checked on, and caches the answers in
`<data_dir>/work/correction_candidates.pkl.gz`.

The queries are a fifth of the calibration typists' autocorrections, the held-out typists'
autocorrections, every word typists left alone, every word of the copied sentences, and
expressive words, in that order."""

import argparse
from pathlib import Path

import latinime_candidates
from ite_records import (
    clean_sentence_records, expressive_records, plausible_corrections, read_records,
    sample_calibration,
)
from paths import DataPaths


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("data_dir", type=Path)
    data_dir = parser.parse_args().data_dir
    paths = DataPaths(data_dir)

    calibration = sample_calibration(plausible_corrections(
        read_records(paths.ite_split("ac_success_calibration"))))
    correction_holdout = plausible_corrections(read_records(paths.ite_split("ac_success_holdout")))
    preserve_calibration = read_records(paths.ite_split("preserve_calibration"))
    preserve_holdout = read_records(paths.ite_split("preserve_holdout"))
    clean_preserve, _ = clean_sentence_records(data_dir)
    keys = latinime_candidates.unique_queries([
        calibration, correction_holdout, preserve_calibration, preserve_holdout,
        clean_preserve, expressive_records(),
    ])
    outputs = latinime_candidates.run_suggestions(
        paths.suggestion_reader, paths.dictionary, keys, paths.correction_queries)
    latinime_candidates.save(outputs, paths.correction_candidates)
    print(f"cached {len(outputs):,} queries in {paths.correction_candidates}")


if __name__ == "__main__":
    main()

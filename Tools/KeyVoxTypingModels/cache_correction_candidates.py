"""Asks the compiled dictionary for its candidates for every correction query the correction
ranker and action model are trained and checked on, and caches the answers in
`<data_dir>/work/correction_candidates.pkl.gz`.

The queries are those of every record `training_sets.correction_sets` gives for the training
source (`--source`, `ite` unless given): the typos and words typed as meant the ranker and the
action model train on, ITE's held-out ones, every word of the copied sentences, and expressive
words, in that order, each asked in a LatinIME session of its own. With `--as-bundled` they are
instead the queries the bundled rankers learned from (`bundled_queries.py`), asked in one
shared session, so the build rebuilds the bundled rankers."""

import argparse
from pathlib import Path

import bundled_queries
import latinime_candidates
from paths import DataPaths
from training_sets import SOURCES, correction_sets


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("--source", choices=SOURCES, default="ite")
    parser.add_argument("--as-bundled", action="store_true",
                        help="ask the queries the bundled rankers learned from, in one session")
    arguments = parser.parse_args()
    paths = DataPaths(arguments.data_dir)

    if arguments.as_bundled:
        if arguments.source != "ite":
            parser.error("--as-bundled asks the queries of ITE's typing; leave --source out")
        collections = bundled_queries.correction_queries(paths)
    else:
        collections = correction_sets(paths, arguments.source).all_records()
    keys = latinime_candidates.unique_queries(collections)
    outputs = latinime_candidates.run_suggestions(
        paths.suggestion_reader, paths.dictionary, keys, paths.correction_queries,
        shared_session=arguments.as_bundled)
    latinime_candidates.save(outputs, paths.correction_candidates)
    print(f"cached {len(outputs):,} queries in {paths.correction_candidates}")


if __name__ == "__main__":
    main()

"""Asks the compiled dictionary for its candidates for every word completion the completion
ranker is trained and checked on, `training_sets.completion_sets`, and caches the answers in
`<data_dir>/work/completion_candidates.pkl.gz`."""

import argparse
from pathlib import Path

import latinime_candidates
from paths import DataPaths
from training_sets import completion_sets


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("data_dir", type=Path)
    arguments = parser.parse_args()
    paths = DataPaths(arguments.data_dir)

    keys = latinime_candidates.unique_queries(completion_sets(paths))
    outputs = latinime_candidates.run_suggestions(
        paths.suggestion_reader, paths.dictionary, keys, paths.completion_queries)
    latinime_candidates.save(outputs, paths.completion_candidates)
    print(f"cached {len(outputs):,} queries in {paths.completion_candidates}")


if __name__ == "__main__":
    main()

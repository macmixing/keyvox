"""Asks the compiled dictionary for its candidates for every word completion the completion
ranker is trained and checked on, and caches the answers in
`<data_dir>/work/completion_candidates.pkl.gz`."""

import argparse
from pathlib import Path

import latinime_candidates
from ite_records import completion_records
from paths import DataPaths


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("data_dir", type=Path)
    data_dir = parser.parse_args().data_dir
    paths = DataPaths(data_dir)

    keys = latinime_candidates.unique_queries([completion_records(data_dir)])
    outputs = latinime_candidates.run_suggestions(
        paths.suggestion_reader, paths.dictionary, keys, paths.completion_queries)
    latinime_candidates.save(outputs, paths.completion_candidates)
    print(f"cached {len(outputs):,} queries in {paths.completion_candidates}")


if __name__ == "__main__":
    main()

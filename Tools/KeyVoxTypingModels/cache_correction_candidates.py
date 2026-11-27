"""Asks the compiled dictionary for its candidates for every correction query the correction
ranker and action model are trained and checked on, and caches the answers in
`<data_dir>/work/correction_candidates.pkl.gz`.

The queries are those of every record `training_sets.correction_sets` gives for the language
(`--language`) and training source (`--source`, `ite` for English and `sim` for any other language
unless given): the typos and words typed as meant the ranker and the action model train on, the
held-out ones, and for English every word of the copied sentences and expressive words, in that
order, each asked in a LatinIME session of its own on the language's letter keys. With
`--as-bundled` they are instead the queries the bundled rankers learned from
(`bundled_queries.py`), asked in one shared session of the dictionary as counted, with the words
`offensive_words.py` matches, as they learned from it, so the build rebuilds the bundled
rankers."""

import argparse
from pathlib import Path

import bundled_queries
import latinime_candidates
from paths import DataPaths
from training_sets import SOURCES, correction_sets, training_source
from typing_languages import add_language_arguments, language_from


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("--source", choices=SOURCES,
                        help="the training source (default: ite for English, sim otherwise)")
    parser.add_argument("--as-bundled", action="store_true",
                        help="ask the queries the bundled rankers learned from, in one session")
    add_language_arguments(parser)
    arguments = parser.parse_args()
    paths = DataPaths(arguments.data_dir)
    language = language_from(arguments)

    if arguments.as_bundled:
        if arguments.source not in (None, "ite") or not language.uses_english_text:
            parser.error("--as-bundled asks the queries of English ITE typing; leave --source "
                         "and --language out")
        collections = bundled_queries.correction_queries(paths)
    else:
        source = training_source(arguments.source, language)
        collections = correction_sets(paths, source, language).all_records()
    keys = latinime_candidates.unique_queries(collections)
    outputs = latinime_candidates.run_suggestions(
        paths.suggestion_reader,
        paths.counted_dictionary if arguments.as_bundled else paths.dictionary, keys,
        paths.correction_queries, language.letter_rows(), shared_session=arguments.as_bundled)
    latinime_candidates.save(outputs, paths.correction_candidates)
    print(f"cached {len(outputs):,} queries in {paths.correction_candidates}")


if __name__ == "__main__":
    main()

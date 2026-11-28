"""Asks the compiled dictionary for its candidates for every word completion the completion
ranker is trained and checked on, `training_sets.completion_sets` for the language
(`--language`) and training source (`--source`, `ite` for English and `sim` for any other language
unless given), each asked in a LatinIME session of its own on the language's letter keys, and
caches the answers in `<data_dir>/work/completion_candidates.pkl.gz`. With `--as-bundled` it asks
the queries the bundled ranker learned from (`bundled_queries.py`) in one shared session of the
dictionary as counted, with the words `offensive_words.py` matches, instead, as it learned from
it, so the build rebuilds the bundled ranker. Another language's queries are asked of its
dictionary as counted too, so the words it leaves out leave its ranker as it would be without
them."""

import argparse
from pathlib import Path

import bundled_queries
import latinime_candidates
from paths import DataPaths
from training_sets import SOURCES, completion_sets, training_source
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
        collections = bundled_queries.completion_queries(paths)
    else:
        collections = completion_sets(paths, training_source(arguments.source, language),
                                      language)
    keys = latinime_candidates.unique_queries(collections)
    outputs = latinime_candidates.run_suggestions(
        paths.suggestion_reader,
        paths.counted_dictionary if arguments.as_bundled or not language.uses_english_text
        else paths.dictionary, keys,
        paths.completion_queries, language.letter_rows(), shared_session=arguments.as_bundled)
    latinime_candidates.save(outputs, paths.completion_candidates)
    print(f"cached {len(outputs):,} queries in {paths.completion_candidates}")


if __name__ == "__main__":
    main()

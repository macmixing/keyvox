"""The queries the July 2026 candidate caches asked LatinIME, in the order they asked them, which
the bundled rankers learned from. The caches ask them with `--as-bundled`, through one shared
session as July's did, so a build rebuilds the bundled rankers byte for byte.

They are not the records the trainers read (`training_sets.py`): the correction queries are a
fifth of the calibration typists' autocorrections sampled after keeping the plausible ones, the
held-out typists' right autocorrections, every word typed as meant, every word of the copied
sentences, and expressive words, and they leave out the held-out typists' wrong
autocorrections. "How the bundled rankers were trained" in the README counts what that leaves
out."""

from ite_records import (
    clean_sentence_records, completion_records, expressive_records, plausible_corrections,
    read_records, sample_calibration,
)


def correction_queries(paths):
    """The record collections whose queries the July correction cache asked, in its order."""
    clean_preserve, _ = clean_sentence_records(paths.root)
    return [
        sample_calibration(plausible_corrections(
            read_records(paths.ite_split("ac_success_calibration")))),
        plausible_corrections(read_records(paths.ite_split("ac_success_holdout"))),
        read_records(paths.ite_split("preserve_calibration")),
        read_records(paths.ite_split("preserve_holdout")),
        clean_preserve,
        expressive_records(),
    ]


def completion_queries(paths):
    """The record collections whose queries the July completion cache asked, in its order."""
    return [completion_records(paths.root)]

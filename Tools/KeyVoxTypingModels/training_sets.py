"""The records the correction ranker, the action model, and the completion ranker train and are
measured on, for a training source: ITE's typing (`ite`), simulated typing (`sim`, from
`write_simulated_records.py`), or both (`sim+ite`). The candidate caches ask LatinIME for exactly
these records, so every record a trainer reads has its candidates.

Records are split into ten buckets by the sentence being typed: the correction ranker trains on
buckets 0-4, the action model on bucket 5, and the completion ranker on 0-7. Whatever the
training source, English's are measured on ITE's buckets 8-9.

Another language has no ITE typing: its rankers train on simulated typing alone and are measured
on its simulated buckets 8-9, whose sentences its dictionary and the rankers' word counts leave
out (`simulation_sentences.py`)."""

from dataclasses import dataclass

from ite_records import (
    annotate, clean_sentence_records, completion_records, correction_records, expressive_records,
    load_section_sentences, plausible_corrections, preserve_records, read_records, stable_bucket,
)

SOURCES = ("ite", "sim", "sim+ite")
CORRECTION_RANKER_BUCKETS = frozenset(range(5))
ACTION_BUCKETS = frozenset({5})
COMPLETION_RANKER_BUCKETS = frozenset(range(8))
TEST_BUCKETS = frozenset({8, 9})


@dataclass(frozen=True)
class CorrectionSets:
    ranker_typos: list
    action_typos: list
    action_preserves: list
    test_typos: list
    test_preserves: list
    # Every word of the sentences ITE typists copied, typed correctly, and expressive words.
    external: list

    def all_records(self):
        return [self.ranker_typos, self.action_typos, self.action_preserves, self.test_typos,
                self.test_preserves, self.external]


def in_buckets(records, buckets):
    return [record for record in records if record["bucket"] in buckets]


def simulated(paths, name):
    """The simulated records, each in the bucket of its sentence."""
    records = read_records(paths.simulated_records(name))
    for record in records:
        record["bucket"] = stable_bucket(record["participant"])
    return records


def uses(source, part):
    if source not in SOURCES:
        raise ValueError(f"unknown training source {source!r}; use one of {', '.join(SOURCES)}")
    return part in source.split("+")


def training_source(source, language):
    """The training source: the one asked for, or by default `ite` for English and `sim` for any
    other language, which has only simulated typing."""
    if language.uses_english_text:
        return source or "ite"
    if source not in (None, "sim"):
        raise SystemExit(f"{language.identifier} has no ITE typing; its rankers train on "
                         "simulated typing alone (--source sim)")
    return "sim"


def correction_sets(paths, source, language):
    if not language.uses_english_text:
        typos = plausible_corrections(simulated(paths, "corrections"))
        preserves = simulated(paths, "preserves")
        return CorrectionSets(
            ranker_typos=in_buckets(typos, CORRECTION_RANKER_BUCKETS),
            action_typos=in_buckets(typos, ACTION_BUCKETS),
            action_preserves=in_buckets(preserves, ACTION_BUCKETS),
            test_typos=in_buckets(typos, TEST_BUCKETS),
            test_preserves=in_buckets(preserves, TEST_BUCKETS),
            external=[],
        )
    section_sentences = load_section_sentences(paths.root)
    ite_typos = annotate(correction_records(paths), section_sentences)
    ite_preserves = annotate(preserve_records(paths), section_sentences)
    clean_preserve, _ = clean_sentence_records(paths.root)
    typos = []
    preserves = []
    if uses(source, "ite"):
        typos += ite_typos
        preserves += ite_preserves
    if uses(source, "sim"):
        typos += plausible_corrections(simulated(paths, "corrections"))
        preserves += simulated(paths, "preserves")
    return CorrectionSets(
        ranker_typos=in_buckets(typos, CORRECTION_RANKER_BUCKETS),
        action_typos=in_buckets(typos, ACTION_BUCKETS),
        action_preserves=in_buckets(preserves, ACTION_BUCKETS),
        test_typos=in_buckets(ite_typos, TEST_BUCKETS),
        test_preserves=in_buckets(ite_preserves, TEST_BUCKETS),
        external=annotate(clean_preserve + expressive_records(), section_sentences),
    )


def completion_sets(paths, source, language):
    """The completion ranker's training records and the held-out ones: ITE's for English, the
    simulated ones of the held-out buckets for any other language."""
    if not language.uses_english_text:
        completions = simulated(paths, "completions")
        return (in_buckets(completions, COMPLETION_RANKER_BUCKETS),
                in_buckets(completions, TEST_BUCKETS))
    ite = annotate(completion_records(paths.root), load_section_sentences(paths.root))
    training = []
    if uses(source, "ite"):
        training += in_buckets(ite, COMPLETION_RANKER_BUCKETS)
    if uses(source, "sim"):
        training += in_buckets(simulated(paths, "completions"), COMPLETION_RANKER_BUCKETS)
    return training, in_buckets(ite, TEST_BUCKETS)

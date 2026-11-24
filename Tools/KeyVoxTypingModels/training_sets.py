"""The records the correction ranker, the action model, and the completion ranker train and are
measured on. The candidate caches ask LatinIME for exactly these records, so every record a
trainer reads has its candidates.

Records are split into ten buckets by the sentence being typed: the correction ranker trains on
buckets 0-4, the action model on bucket 5, and the completion ranker on 0-7. They are measured
on buckets 8-9."""

from dataclasses import dataclass

from ite_records import (
    annotate, clean_sentence_records, completion_records, correction_records, expressive_records,
    load_section_sentences, preserve_records,
)

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


def correction_sets(paths):
    section_sentences = load_section_sentences(paths.root)
    typos = annotate(correction_records(paths), section_sentences)
    preserves = annotate(preserve_records(paths), section_sentences)
    clean_preserve, _ = clean_sentence_records(paths.root)
    return CorrectionSets(
        ranker_typos=in_buckets(typos, CORRECTION_RANKER_BUCKETS),
        action_typos=in_buckets(typos, ACTION_BUCKETS),
        action_preserves=in_buckets(preserves, ACTION_BUCKETS),
        test_typos=in_buckets(typos, TEST_BUCKETS),
        test_preserves=in_buckets(preserves, TEST_BUCKETS),
        external=annotate(clean_preserve + expressive_records(), section_sentences),
    )


def completion_sets(paths):
    """The completion ranker's training records and its held-out ones."""
    records = annotate(completion_records(paths.root), load_section_sentences(paths.root))
    return in_buckets(records, COMPLETION_RANKER_BUCKETS), in_buckets(records, TEST_BUCKETS)

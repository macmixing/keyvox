"""The sentences the typo simulator types, picked by a hash of their words, each once.

For English: one in ten of the Tatoeba sentences and OASST1 message fragments the counts are made
from, read and split as `write_feature_context_model.py` reads them, and never a sentence ITE
typists copied. For another language: one in `simulation_share` of the sentences of its language
build's `simulation_sources` (`typing_languages.py`), the sources written with care.

The counts the rankers train with leave out the sentences ITE typists copied, so a typed word's
context is as new to them as it is to the keyboard. Trained on simulated typing, they leave out
these sentences the same way (`write_feature_context_model.py --leave-out-simulation-sentences`).

Every sentence's records are in the bucket of its section, `sim<index>`, `index` being its place
in this order (`training_sets.py`). Another language's rankers are measured on the sentences of the
held-out buckets, so its dictionary leaves those out of its counts too (`held_out_sentences`), as
English's leaves out the sentences ITE typists copied."""

import hashlib
import re

import language_build
from ite_records import stable_bucket
from sources import ite_path, oasst1_path, tatoeba_path
from text_sources import ite_sentences, oasst1_messages, tatoeba_sentences
from words import tokenize

SHARE = 10
OASST1_FRAGMENT_END = re.compile(r"[.!?\n]+")
FEWEST_WORDS = 2
MOST_WORDS = 40


def is_simulation_sentence(words, share=SHARE):
    """Whether the sentence, its words joined by spaces, is one the simulator types."""
    return int(hashlib.sha256(f"simulation\t{words}".encode()).hexdigest()[:8], 16) % share == 0


def section(index):
    """The section of the simulation sentence at `index`."""
    return f"sim{index}"


def simulation_sentences(paths, language):
    """Each simulation sentence's words, once each, in the order the sources give them."""
    if language.uses_english_text:
        yield from _english_sentences(paths.root)
        return
    seen = set()
    for source in language.simulation_sources:
        for tokens in language_build.sentences(paths, source):
            joined = " ".join(tokens)
            if (FEWEST_WORDS <= len(tokens) <= MOST_WORDS and joined not in seen
                    and is_simulation_sentence(joined, language.simulation_share)):
                seen.add(joined)
                yield tokens


def held_out_sentences(paths, language, buckets):
    """The simulation sentences in `buckets`, their words joined by spaces."""
    return {" ".join(tokens) for index, tokens in enumerate(simulation_sentences(paths, language))
            if stable_bucket(section(index)) in buckets}


def _english_sentences(data_dir):
    copied = {" ".join(tokenize(sentence)) for sentence in
              ite_sentences(ite_path(data_dir, "processed2020/english/sentences.csv"))}
    seen = set()

    def picked(text):
        tokens = tokenize(text)
        joined = " ".join(tokens)
        if (FEWEST_WORDS <= len(tokens) <= MOST_WORDS and joined not in copied
                and joined not in seen and is_simulation_sentence(joined)):
            seen.add(joined)
            return tokens
        return None

    for sentence in tatoeba_sentences(tatoeba_path(data_dir)):
        if tokens := picked(sentence):
            yield tokens
    for message in oasst1_messages(oasst1_path(data_dir)):
        for fragment in OASST1_FRAGMENT_END.split(message):
            if tokens := picked(fragment):
                yield tokens

"""The English sentences the typo simulator types: one in ten of the Tatoeba sentences and OASST1
message fragments the counts are made from, read and split as `write_feature_context_model.py`
reads them, picked by a hash of their words, and never a sentence ITE typists copied.

The counts the rankers train with leave out the sentences ITE typists copied, so a typed word's
context is as new to them as it is to the keyboard. Trained on simulated typing, they leave out
these sentences the same way (`write_feature_context_model.py --leave-out-simulation-sentences`)."""

import hashlib
import re

from sources import ite_path, oasst1_path, tatoeba_path
from text_sources import ite_sentences, oasst1_messages, tatoeba_sentences
from words import tokenize

SHARE = 10
OASST1_FRAGMENT_END = re.compile(r"[.!?\n]+")


def is_simulation_sentence(words):
    """Whether the sentence, its words joined by spaces, is one the simulator types."""
    return int(hashlib.sha256(f"simulation\t{words}".encode()).hexdigest()[:8], 16) % SHARE == 0


def simulation_sentences(data_dir):
    """Each simulation sentence's words, once each, in the order the sources give them."""
    copied = {" ".join(tokenize(sentence)) for sentence in
              ite_sentences(ite_path(data_dir, "processed2020/english/sentences.csv"))}
    seen = set()

    def picked(text):
        tokens = tokenize(text)
        joined = " ".join(tokens)
        if (2 <= len(tokens) <= 40 and joined not in copied and joined not in seen
                and is_simulation_sentence(joined)):
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

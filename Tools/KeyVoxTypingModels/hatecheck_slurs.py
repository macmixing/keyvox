"""Reads the slurs of a language's Multilingual HateCheck test cases (`sources.MULTILINGUAL_HATECHECK`),
by the group each one targets.

Each `slur_h` case is a hateful sentence built from a template around one slur, tagged with the group
the slur targets (`target_ident`). A case whose template marks its slur, `[SLR_S]` for a singular and
`[SLR_P]` for a plural, gives the slur as the words the placeholder stands for. Every other case
shares its template (`templ_id`) with the cases of the template's other slurs, so its slur is its
word where those cases differ most: an article or adjective before it differs only with the slur's
gender. A word that is part of a slur of several words a template gives is that slur's, not a slur of
its own. Each case gives its slur in the form its sentence writes it, so the forms, plurals included,
are the source's own."""

import csv
import re
from collections import defaultdict

SLUR_FUNCTIONALITY = "slur_h"
PLACEHOLDER = re.compile(r"\\\[SLR_[SP]\\\]")
# A word of a case: its letters, apostrophes, and hyphens, without the punctuation around it.
EDGE = re.compile(r"^[^\w'’-]+|[^\w'’-]+$")


def words_of(sentence):
    return [EDGE.sub("", token) for token in sentence.split()]


def templated_slurs(template, sentence):
    """The words a template's slur placeholders stand for in the sentence, or None if it does not
    fit the template."""
    expression = "^" + PLACEHOLDER.sub("(.+?)", re.escape(template)) + "$"
    match = re.match(expression, sentence)
    return [value.strip() for value in match.groups()] if match else None


def slurs(path):
    """Each target group's slurs, as written in the cases: {group, case-folded: {slur}}."""
    with path.open(newline="", encoding="utf-8") as source:
        cases = [row for row in csv.DictReader(source) if row["functionality"] == SLUR_FUNCTIONALITY]
    found = defaultdict(set)
    by_template = defaultdict(list)
    for case in cases:
        group = case["target_ident"].strip().casefold()
        written = templated_slurs(case["case_templ"], case["test_case"]) \
            if "[SLR_" in case["case_templ"] else None
        if written is not None:
            found[group].update(written)
        else:
            by_template[case["templ_id"]].append((group, words_of(case["test_case"])))

    for template_cases in by_template.values():
        lengths = defaultdict(list)
        for group, words in template_cases:
            lengths[len(words)].append((group, words))
        aligned = max(lengths.values(), key=len)
        if len(aligned) < 2:
            continue
        variety = [len({words[index] for _, words in aligned}) for index in range(len(aligned[0][1]))]
        position = max(range(len(variety)), key=lambda index: (variety[index], index))
        if variety[position] < 2:
            continue
        for group, words in aligned:
            found[group].add(words[position])
    for group, written in found.items():
        parts = {word for slur in written if " " in slur for word in slur.split()}
        found[group] = {slur for slur in written if slur not in parts}
    return dict(found)

"""Writes a typing language's swipe vocabulary: the words people write that its dictionary
lacks, so a swipe can decode to them. One word per line, its spelling, a tab, and its
probability on the dictionary's scale (0 to 255, already log-scaled), likeliest first.

A word here is a swipe form, as a swipe draws it: its letters only, case and accents folded,
but for a letter the keyboard has a key of its own for, which keeps its accents (the swipe
model's `letter_form`). Every form `count_swipe_words.py` counted that no
dictionary word spells is a candidate, and these rules, in this order, leave one out:

1. offensive: a pattern of `--leave-out` matches it whole, a word the dictionary leaves out too
   (for English, `Tools/KeyVoxTypingModels/offensive_words.py` writes them).
2. letters: a letter of it is no letter key of the language's keyboard.
3. one source: fewer than two sources write it as a word on its own.
4. joined: most of the times it is written, it is joined to other letters or digits in one run
   without spaces (`normalize.joined_words`), so it is a piece of a longer token, such as a
   URL, a hyphenated word, or code.
5. misspelling: a dictionary form one edit away (a letter left out, added, changed, or two
   neighbors swapped) is written on its own at least MISSPELLING_RATIO times as often as the
   candidate is, unless the language's spelling list (for English, SCOWL's size 80 in
   every spelling) lists it, or the written sources write it with capitals more often than in
   lowercase in the middle of a sentence, as a name or an acronym, while a misspelling of a
   lowercase word is lowercase.

Every form left is kept, ranked by how often the sources write it on their own. Each is
written in its most common spelling, with its likeliest capitals when the written sources
write that spelling as a name (`names.is_written_as_name`: often enough, nearly always with a
capital in the middle of a sentence), unless those capitals are in a row and not a measured
spelling, as `write_capitalized_spellings.py` leaves acronyms lowercase. Its probability is
the median the dictionary gives its words that the sources write on their own about as often
(within PROBABILITY_BAND of the count), so an added word ranks as a dictionary word as common
would.

Then come the words the language's swipe dataset had people swipe (`count_swiped_words.py`),
from sentences written with care, which the sources write too rarely for the rules above. Each
form of them that no dictionary word spells and the list does not already hold is a candidate,
and these rules, in this order, leave one out:

1. offensive: as above.
2. letters: as above.
3. one swipe: fewer than MINIMUM_SWIPES records swipe it.
4. misspelling: as above, counting how often the sources write the form on their own (none for
   most of them, so a dictionary form one edit away that the sources write at all leaves it out),
   with the same exceptions, the capitals being the dataset's sentences' in the middle of a
   sentence.

The rules above for one source and for joined words count the sources' texts, which do not
hold these words, and a word the dataset writes joined is the whole word
a person swipes. Every form left is kept, after the sources' words, ranked by how many records
swipe it. Each is written in its most common spelling without the punctuation around it, with
its likeliest capitals when the dataset's sentences write that spelling with capitals more often
than in lowercase in the middle of a sentence, unless those capitals are in a row and not a
measured spelling, as above. Its probability is the lowest the sources' words get, the
dictionary's for the words written about as rarely as the rarest of them.

Every candidate is written to `<data_dir>/swipe_vocabulary_report.tsv` with its counts and
the rule that left it out, or its rank, spelling, and probability, and for a form the
misspelling rule would leave out, which exception kept it; a form the swipe dataset swipes
also has how many records swipe it and the outcome of the rules for its words, and a form only
the swipe dataset has is listed with no source."""

import argparse
import re
import statistics
import unicodedata
from bisect import bisect_left, bisect_right
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path

from count_swiped_words import OUTPUT_NAME as SWIPED_NAME
from count_swipe_words import OUTPUT_NAME as COUNTS_NAME
from languages import LANGUAGES, language_argument
from names import is_written_as_name
from write_capitalized_spellings import (
    has_capitals_in_a_row,
    keeps_capitals_in_a_row,
    read_measured_spellings,
)

MINIMUM_SOURCES = 2
MINIMUM_SWIPES = 2
MISSPELLING_RATIO = 50
PROBABILITY_BAND = 2 ** 0.25
REPORT_NAME = "swipe_vocabulary_report.tsv"

KEPT = "kept"
OFFENSIVE = "offensive"


def swipe_form(word: str, keys: str) -> str:
    """`word`'s letters, case folded, with the accents of every letter but `keys` folded."""
    form = []
    for character in unicodedata.normalize("NFC", word.casefold()):
        if character in keys:
            form.append(character)
        else:
            form.extend(letter for letter in unicodedata.normalize("NFD", character)
                        if unicodedata.category(letter)[0] == "L")
    return "".join(form)


@dataclass
class Candidate:
    form: str
    # Per source, how often it is written as a word on its own.
    counts: list[int]
    # How often it is written joined to other letters or digits, in every source.
    joined: int = 0
    # Its lowercase spellings by how often they are written.
    spellings: Counter = field(default_factory=Counter)
    # In the written sources, away from where a sentence or quotation begins: each lowercase
    # spelling written in lowercase, and each spelling with capitals.
    lowercase: Counter = field(default_factory=Counter)
    capitalized: Counter = field(default_factory=Counter)

    @property
    def on_its_own(self) -> int:
        return sum(self.counts)

    @property
    def written(self) -> int:
        return self.on_its_own + self.joined


@dataclass
class SwipedForm:
    form: str
    # Its lowercase spellings by how many records swipe them.
    spellings: Counter = field(default_factory=Counter)
    # In the middle of a sentence: each lowercase spelling written in lowercase, and each
    # spelling with capitals.
    lowercase: Counter = field(default_factory=Counter)
    capitalized: Counter = field(default_factory=Counter)

    @property
    def swiped(self) -> int:
        return self.spellings.total()


def read_counts(path: Path, dictionary_forms: set[str], keys: str):
    """The candidates by form, the sources' names, and how often the sources write each
    dictionary form on its own, counted as a candidate's count is."""
    candidates: dict[str, Candidate] = {}
    dictionary_counts: Counter[str] = Counter()
    with open(path, encoding="utf-8") as rows:
        header = rows.readline().rstrip("\n").split("\t")
        sources = header[1:-2:2]
        for row in rows:
            fields = row.rstrip("\n").split("\t")
            word, numbers = fields[0], [int(value) for value in fields[1:-2]]
            form = swipe_form(word, keys)
            if not form:
                continue
            counts, joined = numbers[0::2], numbers[1::2]
            if form in dictionary_forms:
                dictionary_counts[form] += sum(counts) - sum(joined)
                continue
            candidate = candidates.setdefault(form, Candidate(form, [0] * len(sources)))
            for index, (count, together) in enumerate(zip(counts, joined)):
                candidate.counts[index] += count - together
            candidate.joined += sum(joined)
            candidate.spellings[word] += sum(counts)
            candidate.lowercase[word] += int(fields[-2])
            for item in filter(None, fields[-1].split(",")):
                spelling, count = item.rsplit(":", 1)
                candidate.capitalized[spelling] += int(count)
    return candidates, sources, dictionary_counts


def read_swiped(path: Path, dictionary_forms: set[str], keys: str) -> dict[str, SwipedForm]:
    """The swipe dataset's forms that no dictionary word spells."""
    swiped: dict[str, SwipedForm] = {}
    with open(path, encoding="utf-8") as rows:
        rows.readline()
        for row in rows:
            spelling, records, in_the_middle = row.rstrip("\n").split("\t")
            form = swipe_form(spelling, keys)
            if not form or form in dictionary_forms:
                continue
            item = swiped.setdefault(form, SwipedForm(form))
            lowered = spelling.lower()
            item.spellings[lowered] += int(records)
            if spelling == lowered:
                item.lowercase[lowered] += int(in_the_middle)
            else:
                item.capitalized[spelling] += int(in_the_middle)
    return swiped


def one_edit_forms(form: str, letters: str):
    splits = [(form[:index], form[index:]) for index in range(len(form) + 1)]
    for left, right in splits:
        if right:
            yield left + right[1:]
            for letter in letters:
                if letter != right[0]:
                    yield left + letter + right[1:]
        if len(right) > 1:
            yield left + right[1] + right[0] + right[2:]
        for letter in letters:
            yield left + letter + right


def is_written_with_capitals(candidate: Candidate | SwipedForm) -> bool:
    """Whether the written sources write it with capitals more often than in lowercase in the
    middle of a sentence; a misspelling of a lowercase word is written in lowercase."""
    return candidate.capitalized.total() > candidate.lowercase.total()


def misspelled_word(form: str, on_its_own: int, letters: str, dictionary_counts: Counter[str]) -> str | None:
    """The dictionary form one edit away written on its own at least MISSPELLING_RATIO times as
    often as `form`, which the sources write on its own `on_its_own` times, if one is."""
    count, word = max((dictionary_counts[edit], edit) for edit in one_edit_forms(form, letters))
    return word if count > 0 and count >= MISSPELLING_RATIO * on_its_own else None


def misspelling_outcome(form, on_its_own, written, letters, dictionary_counts, spelling_forms) -> str:
    """KEPT, with the exception that kept the form from the misspelling rule, if one did, or
    the dictionary word it misspells; `written` holds how it is written with capitals."""
    word = misspelled_word(form, on_its_own, letters, dictionary_counts)
    if word is None:
        return KEPT
    if form in spelling_forms:
        return f"{KEPT}, in the spelling list"
    if is_written_with_capitals(written):
        return f"{KEPT}, written with capitals"
    return f"misspelling of {word}"


def outcome_of(candidate, letters, dictionary_counts, spelling_forms) -> str:
    """The rule that leaves the candidate out, or KEPT, with the exception that kept it from
    the misspelling rule, if one did."""
    if any(letter not in letters for letter in candidate.form):
        return "letters"
    if sum(1 for count in candidate.counts if count > 0) < MINIMUM_SOURCES:
        return "one source"
    if candidate.joined * 2 > candidate.written:
        return "joined"
    return misspelling_outcome(candidate.form, candidate.on_its_own, candidate, letters, dictionary_counts,
                               spelling_forms)


def swiped_outcome_of(swiped: SwipedForm, on_its_own, letters, dictionary_counts, spelling_forms) -> str:
    """The rule that leaves a form of the swipe dataset out, or KEPT, as `outcome_of`; the
    sources write it on its own `on_its_own` times."""
    if any(letter not in letters for letter in swiped.form):
        return "letters"
    if swiped.swiped < MINIMUM_SWIPES:
        return "one swipe"
    return misspelling_outcome(swiped.form, on_its_own, swiped, letters, dictionary_counts, spelling_forms)


def written_spelling(candidate: Candidate, measured: set[str]) -> str:
    spelling = min(candidate.spellings, key=lambda word: (-candidate.spellings[word], word))
    capitals = {written: count for written, count in candidate.capitalized.items() if written.lower() == spelling}
    written_with_capitals = sum(capitals.values())
    if capitals and is_written_as_name(written_with_capitals + candidate.lowercase[spelling], written_with_capitals):
        written = min(capitals, key=lambda word: (-capitals[word], word))
        if not has_capitals_in_a_row(written) or keeps_capitals_in_a_row(written, measured):
            return written
    return spelling


def swiped_spelling(swiped: SwipedForm, measured: set[str]) -> str:
    spelling = min(swiped.spellings, key=lambda word: (-swiped.spellings[word], word))
    capitals = {written: count for written, count in swiped.capitalized.items() if written.lower() == spelling}
    if sum(capitals.values()) > swiped.lowercase[spelling]:
        written = min(capitals, key=lambda word: (-capitals[word], word))
        if not has_capitals_in_a_row(written) or keeps_capitals_in_a_row(written, measured):
            return written
    return spelling


class DictionaryScale:
    """The dictionary's probabilities by how often the sources write its words."""

    def __init__(self, probabilities: dict[str, int], dictionary_counts: Counter[str]):
        pairs = sorted((dictionary_counts[form], probability) for form, probability in probabilities.items()
                       if dictionary_counts[form] > 0)
        self.counts = [count for count, _ in pairs]
        self.probabilities = [probability for _, probability in pairs]

    def probability(self, count: int) -> int:
        low = bisect_left(self.counts, count / PROBABILITY_BAND)
        high = bisect_right(self.counts, count * PROBABILITY_BAND)
        if low == high:
            raise ValueError(f"no dictionary word is written about {count} times")
        return round(statistics.median(self.probabilities[low:high]))


def read_dictionary(path: Path, keys: str) -> dict[str, int]:
    """Each dictionary form's highest probability, from the dictionary's word list."""
    probabilities: dict[str, int] = {}
    with open(path, encoding="utf-8") as rows:
        for row in rows:
            word, probability = row.rstrip("\n").split("\t")[:2]
            form = swipe_form(word, keys)
            if form:
                probabilities[form] = max(probabilities.get(form, 0), int(probability))
    return probabilities


def read_spelling_forms(path: Path, keys: str) -> set[str]:
    with open(path, encoding="utf-8") as words:
        return {swipe_form(word.strip(), keys) for word in words if word.strip()}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    language_argument(parser)
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("dictionary", type=Path,
                        help="the dictionary's words and probabilities, a word and a tab and a probability a line "
                             "(Tools/KeyVoxTypingModels writes English's as work/dictionary_unigrams.tsv)")
    parser.add_argument("spelling_list", type=Path,
                        help="words spelled right in every spelling (for English, SCOWL's size 80, every spelling)")
    parser.add_argument("output", type=Path)
    parser.add_argument("--leave-out", type=Path,
                        help="the words to leave out, a regular expression a word's swipe form must match whole a line "
                             "(Tools/KeyVoxTypingModels writes English's as work/offensive_words.txt)")
    arguments = parser.parse_args()
    language = LANGUAGES[arguments.language]
    letters = language.letter_keys()
    measured = read_measured_spellings(language.measured_spellings) if language.measured_spellings else set()

    probabilities = read_dictionary(arguments.dictionary, letters)
    candidates, sources, dictionary_counts = read_counts(arguments.data_dir / COUNTS_NAME, set(probabilities), letters)
    swiped = read_swiped(arguments.data_dir / SWIPED_NAME, set(probabilities), letters)
    spelling_forms = read_spelling_forms(arguments.spelling_list, letters)
    scale = DictionaryScale(probabilities, dictionary_counts)

    lines = arguments.leave_out.read_text(encoding="utf-8").splitlines() if arguments.leave_out else []
    offensive = re.compile("|".join(f"(?:{line})" for line in lines if line)) if any(lines) else None

    def is_offensive(form: str) -> bool:
        return offensive is not None and offensive.fullmatch(form) is not None

    outcome = {form: OFFENSIVE if is_offensive(form) else outcome_of(candidate, letters, dictionary_counts, spelling_forms)
               for form, candidate in candidates.items()}
    ranked = sorted((form for form, rule in outcome.items() if rule.startswith(KEPT)),
                    key=lambda form: (-candidates[form].on_its_own, form))
    rank = {form: number for number, form in enumerate(ranked, 1)}
    entries = {form: (written_spelling(candidates[form], measured), scale.probability(candidates[form].on_its_own))
               for form in ranked}
    rows = [entries[form] for form in ranked]

    swiped_outcome = {form: OFFENSIVE if is_offensive(form) else swiped_outcome_of(item, candidates[form].on_its_own if form in candidates else 0,
                                              letters, dictionary_counts, spelling_forms)
                      for form, item in swiped.items() if not outcome.get(form, "").startswith(KEPT)}
    swiped_ranked = sorted((form for form, rule in swiped_outcome.items() if rule.startswith(KEPT)),
                           key=lambda form: (-swiped[form].swiped, form))
    lowest = min(probability for _, probability in rows)
    for form in swiped_ranked:
        rank[form] = len(rank) + 1
        entries[form] = (swiped_spelling(swiped[form], measured), lowest)
    rows += [entries[form] for form in swiped_ranked]
    arguments.output.write_text("".join(f"{spelling}\t{probability}\n" for spelling, probability in rows),
                                encoding="utf-8")

    report_path = arguments.data_dir / REPORT_NAME
    with open(report_path, "w", encoding="utf-8") as report:
        report.write("\t".join(["form", "outcome", "rank", "spelling", "probability", "written on its own",
                                *sources, "joined", "written lowercase", "written with capitals",
                                "spellings", "swiped", "swiped outcome", "swiped spellings"]) + "\n")
        listed = {**candidates, **{form: Candidate(form, [0] * len(sources)) for form in swiped
                                   if form not in candidates}}
        for form in sorted(listed, key=lambda form: (-listed[form].written, form)):
            candidate = listed[form]
            item = swiped.get(form, SwipedForm(form))
            report.write("\t".join([
                form, outcome.get(form, "no source"), str(rank.get(form, "")), *map(str, entries.get(form, ("", ""))),
                str(candidate.on_its_own), *map(str, candidate.counts), str(candidate.joined),
                str(candidate.lowercase.total()), str(candidate.capitalized.total()),
                ",".join(f"{word}:{count}" for word, count in candidate.spellings.most_common(3)),
                str(item.swiped), swiped_outcome.get(form, ""),
                ",".join(f"{word}:{count}" for word, count in item.spellings.most_common(3)),
            ]) + "\n")

    removed = Counter(rule.split(" of ")[0] for rule in outcome.values())
    print(f"{arguments.output}: {len(rows)} words; {len(ranked)} of {len(candidates)} candidate forms; "
          + ", ".join(f"{rule}: {count}" for rule, count in sorted(removed.items())))
    removed = Counter(rule.split(" of ")[0] for rule in swiped_outcome.values())
    print(f"{len(swiped_ranked)} of {len(swiped_outcome)} swiped forms; "
          + ", ".join(f"{rule}: {count}" for rule, count in sorted(removed.items())))


if __name__ == "__main__":
    main()

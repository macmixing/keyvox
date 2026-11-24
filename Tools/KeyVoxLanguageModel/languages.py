"""What each typing language's data is built from, and the build rules that differ between
languages: its sources in the order they are read, how much of each is used, how its text is
split into words, which sources its sentence openers are weighted toward, how its words get
their kinds, and which word lists its vocabulary comes from.

A build is named by its language (`en`) or by a language and a variant (`de-bundestag`),
which shares its language's rules and adds sources. The rules the keyboard reads at run time,
such as the words always written with capitals, come from the language's `language.json` in
the package once the language ships there.
"""

import json
import sys
from dataclasses import dataclass, field
from pathlib import Path

from normalize import DEFAULT_RULES, TextRules
from sources import (
    ENGLISH_YOUTUBE_COMMONS,
    GRAMMALECTE,
    OPEN_DISCOURSE,
    RLA_ES,
    SMS_88MIL,
    UD_SPANISH_ANCORA,
    Source,
    latinime_word_list,
    oasst2,
    tatoeba,
    wikidata_forms,
    wildchat,
    yodas2,
    youtube_commons,
)

PREDICTIVE_DATA = Path(__file__).resolve().parents[2] / "Packages/KeyVoxPredictiveKeyboard/Sources/KeyVoxPredictiveKeyboard/PredictiveData"
MEASURED_SPELLINGS = Path(__file__).with_name("measured_spellings.txt")


@dataclass(frozen=True)
class SourceUse:
    source: Source
    # The share of the source's texts read, chosen by a hash of each text.
    share: float = 1.0


@dataclass(frozen=True)
class LexiconVocabulary:
    """A vocabulary built by write_vocabulary.py from a keyboard word list, with each word's
    capitals settled by the lexicons and, where given, its spelling checked."""
    word_list: Source
    lexicons: tuple[Source, ...]
    # "lexicon": a lowercase word must be a lexicon form, or one joined to an elided form
    # ("l'" + "équipe"); "hunspell": a lowercase word must pass the Hunspell dictionary.
    spelling_check: str | None = None
    spelling_dictionary: Source | None = None


@dataclass(frozen=True)
class AppleTaggerKinds:
    """Word kinds from Apple's NaturalLanguage tagger (tag_word_kinds.swift) over the language's
    written sentences, in `tagger_language` when given, else as the tagger detects it. With
    `elided_host`, a word joined to an elided article or preposition takes the class of the word
    it is joined to."""
    tagger_language: str | None = None
    elided_host: bool = False
    sentences: tuple[str, ...] = ("tatoeba", "oasst2")


@dataclass(frozen=True)
class TreebankKinds:
    """Word kinds from a Universal Dependencies treebank (write_treebank_word_kinds.py)."""
    treebank: Source


@dataclass(frozen=True)
class Language:
    identifier: str
    sources: tuple[SourceUse, ...]
    word_kinds: AppleTaggerKinds | TreebankKinds
    # None: the SCOWL word list (scowl_words.sh), sizes 60 and 50.
    vocabulary: LexiconVocabulary | None = None
    text_rules: TextRules = DEFAULT_RULES
    # Drop a text another source, or the same one, already gave.
    deduplicate: bool = False
    # write_sentence_openers.py's --weight for each source; unlisted sources weigh 1.
    opener_weights: dict[str, float] = field(default_factory=dict)
    # Spellings with capitals in a row the system keyboard was measured writing as spelled.
    measured_spellings: Path | None = None

    def source(self, name: str) -> Source:
        return next(use.source for use in self.sources if use.source.name == name)

    def always_capitalized_words(self) -> tuple[str, ...]:
        """The words the keyboard always writes with capitals, from the language's
        language.json in the package, or none before the language ships there."""
        path = PREDICTIVE_DATA / self.identifier / "language.json"
        if not path.exists():
            return ()
        return tuple(json.loads(path.read_text(encoding="utf-8"))["alwaysCapitalizedWords"])


# Speech has no typed sentence openers, and the written sources outweigh the chat ones the
# way the bundled English openers were tuned.
_OPENER_WEIGHTS = {
    "youtube-commons": 0.0, "yodas2": 0.0, "open-discourse": 0.0,
    "oasst2": 0.3, "wildchat": 0.3, "88milsms": 0.3, "tatoeba": 10.0,
}
# Speeches are formal and outnumber the conversational text, so the variant reads a share.
_BUNDESTAG_SHARE = 0.25


def _text_rules(quotation_marks: str, sentence_opening_marks: str = "") -> TextRules:
    return TextRules(composed=True, sentence_opening_marks=sentence_opening_marks, quotation_marks=quotation_marks)


_GERMAN_SOURCES = (
    SourceUse(tatoeba("deu", "e16c57e695bfeccccb455c305d262c5cbe2aa74a5c1e1edb725d53cf907309ac")),
    SourceUse(oasst2("de")),
    SourceUse(wildchat("de", "3f42a1c3a096fe9a3778a010e862dd2afe6ce2e65a03bb528950acf1db693723")),
    SourceUse(yodas2("de", "945147eeccc849c75c44aca2e2e605379db0702bac59972bc797778640918691")),
    SourceUse(youtube_commons("de", "9f6c6dffead0f80292cd66e5a57b7b028459b44552e963d67d57007c10df5d2a")),
)
_GERMAN = dict(
    identifier="de",
    word_kinds=AppleTaggerKinds(tagger_language="de"),
    vocabulary=LexiconVocabulary(
        word_list=latinime_word_list("de", "07ae553cd55f9901412065bad7617379908ed5f2a701d226ffde85a9b8ffd5c0"),
        lexicons=(wikidata_forms("de", "7a52e72e6da01d13ca3a75c1b7515163957a0f8c763e5ded53d147f5510de843"),),
    ),
    # CLDR's German quotation marks.
    text_rules=_text_rules("„“‚‘"),
    deduplicate=True,
    opener_weights=_OPENER_WEIGHTS,
)

LANGUAGES = {
    "en": Language(
        identifier="en",
        sources=(
            SourceUse(ENGLISH_YOUTUBE_COMMONS),
            SourceUse(oasst2("en")),
            SourceUse(tatoeba("eng")),
        ),
        word_kinds=AppleTaggerKinds(),
        opener_weights={"youtube-commons": 0.0, "oasst2": 0.3, "tatoeba": 10.0},
        measured_spellings=MEASURED_SPELLINGS,
    ),
    "de": Language(sources=_GERMAN_SOURCES, **_GERMAN),
    "de-bundestag": Language(
        sources=_GERMAN_SOURCES + (SourceUse(OPEN_DISCOURSE, share=_BUNDESTAG_SHARE),),
        **_GERMAN,
    ),
    "es": Language(
        identifier="es",
        sources=(
            SourceUse(tatoeba("spa", "7872d2e66debfd8e73e96cc9bca9560a32cc914aee9c820649d7d3d5e7353f48")),
            SourceUse(oasst2("es")),
            SourceUse(wildchat("es", "51879119a9833839f0df37a686bab04481e9ad843d3223ad409682fd7d1e190f")),
            SourceUse(yodas2("es", "4321d1697dad1a5d6c5c3e74a35625eb0aa806b2f00097a4805330916dccd9a2")),
            SourceUse(youtube_commons("es", "d5c9a41b78d993568b5d2edb54d689d3a38aa8f75fc4751e5e3b36118a8ecb53")),
        ),
        word_kinds=TreebankKinds(UD_SPANISH_ANCORA),
        vocabulary=LexiconVocabulary(
            word_list=latinime_word_list("es", "889ad52bce2933e2a30a0560b8d5a76f5334500e776a7db7c7cb3e9e79fc2652"),
            lexicons=(wikidata_forms("es", "15827ccb68d187ae72a1b7f1e443b9a301ba9c3645d8397aaefa4acf5a407fb5"),),
            spelling_check="hunspell",
            spelling_dictionary=RLA_ES,
        ),
        # CLDR's Spanish quotation marks; "¿" and "¡" open a question or exclamation.
        text_rules=_text_rules("«»“”", sentence_opening_marks="¿¡"),
        deduplicate=True,
        opener_weights=_OPENER_WEIGHTS,
    ),
    "fr": Language(
        identifier="fr",
        sources=(
            SourceUse(tatoeba("fra", "c9e91cc5a0640db7bfc4423fadf3985db42df08dafce4983d4c6b8c2cf7a4d3d")),
            SourceUse(oasst2("fr")),
            SourceUse(wildchat("fr", "3c8aeb1a9d17c01bf7685bb3a6591052c8f80a5e8ac2e64b058bc81f7f484705")),
            SourceUse(SMS_88MIL),
            SourceUse(yodas2("fr", "d2ec6e4f733a42e733ff057973dfe70126fc36a00ce6875aa90ff5c60cfcd153")),
            SourceUse(youtube_commons("fr", "1fd31ecb170ae31d7e13b7c6c134fcd22afd2cde53badeaa15a85db6a0ff8ad1")),
        ),
        word_kinds=AppleTaggerKinds(tagger_language="fr", elided_host=True),
        vocabulary=LexiconVocabulary(
            word_list=latinime_word_list("fr", "cc917a0a81acab0ea12089c2fb06b5c6be98c75f23a7605bfdbbeb698abfd65e"),
            lexicons=(
                wikidata_forms("fr", "1bcc4e65c621cc771b0ab4a287ab22ed7403b58355e4be93d2c1301f6c4d44da"),
                GRAMMALECTE,
            ),
            spelling_check="lexicon",
        ),
        # CLDR's French quotation marks.
        text_rules=_text_rules("«»“”"),
        deduplicate=True,
        opener_weights=_OPENER_WEIGHTS,
    ),
}


def language_argument(parser) -> None:
    parser.add_argument("--language", choices=sorted(LANGUAGES), default="en", help="the build (default: en)")


def main() -> None:
    """Prints a build's typing-language identifier, for build_language_data.sh."""
    print(LANGUAGES[sys.argv[1]].identifier)


if __name__ == "__main__":
    main()

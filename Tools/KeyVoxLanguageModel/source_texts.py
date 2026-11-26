"""The texts a language's build reads from each of its sources, in the language's order.

On top of what each source's reader gives:
- Tatoeba's texts that mention a name are left out. Tatoeba reuses a few invented characters
  ("Tom" opens about one English sentence in seven), which would otherwise teach the keyboard
  that sentences start with them.
- A source read in part (`SourceUse.share`) keeps the texts a hash of the text picks.
- A language that deduplicates leaves out a text an earlier source, or the same one, already
  gave, compared in lowercase with its spacing evened out.
"""

import hashlib
import zlib
from collections.abc import Iterator
from pathlib import Path

from languages import Language, SourceUse
from names import capitalized_names, mentions_any
from readers import read_source
from sources import Source
from vocabulary.lexicon_forms import capitalized_common_words

# The source whose texts are left out where they mention a name.
_NAMED_SOURCE = "tatoeba"


def _without_names(texts: list[str], language: Language, data_dir: Path) -> Iterator[str]:
    common = frozenset()
    if language.vocabulary:
        common = capitalized_common_words(data_dir, language.vocabulary.lexicons)
    names = capitalized_names(texts, language.text_rules, language.always_capitalized_words(), common)
    return (text for text in texts if not mentions_any(text, names, language.text_rules))


def _is_kept(text: str, share: float) -> bool:
    return zlib.crc32(text.encode("utf-8")) < share * (1 << 32)


def _texts(use: SourceUse, language: Language, data_dir: Path, seen: set[bytes] | None) -> Iterator[str]:
    texts = read_source(data_dir, use.source)
    if use.source.name == _NAMED_SOURCE:
        texts = _without_names(list(texts), language, data_dir)
    for text in texts:
        if use.share < 1 and not _is_kept(text, use.share):
            continue
        if seen is not None:
            key = hashlib.blake2b(" ".join(text.lower().split()).encode("utf-8"), digest_size=16).digest()
            if key in seen:
                continue
            seen.add(key)
        yield text


def source_texts(language: Language, data_dir: Path) -> Iterator[tuple[Source, Iterator[str]]]:
    """Each source with its texts; read each source's texts before the next source's."""
    seen: set[bytes] | None = set() if language.deduplicate else None
    for use in language.sources:
        yield use.source, _texts(use, language, data_dir, seen)

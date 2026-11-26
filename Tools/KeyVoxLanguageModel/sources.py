"""The text and word lists the KeyVox language data is built from, pinned to exact versions,
with each source's license and the attribution it requires.

A file with a URL is downloaded by download_sources.py. A file without one is prepared from
its upstream source as the README's "Preparing the multilingual sources" describes; a file
with a SHA-256 is checked against it before a build reads it."""

from dataclasses import dataclass


@dataclass(frozen=True)
class SourceFile:
    url: str | None
    name: str
    sha256: str | None = None


@dataclass(frozen=True)
class Source:
    # The folder under <data_dir>/sources, and the name of the source's sentences and counts.
    name: str
    files: tuple[SourceFile, ...]
    license: str
    license_url: str
    attribution: str
    # How readers.py reads the files, and the language code the source's rows are marked with.
    reader: str = ""
    code: str = ""
    # Where the files without a URL are prepared from.
    upstream: str = ""


_YOUTUBE_REVISION = "9addbabbfcd7409acbcd11a3b59ec2aef6da7eb0"
_OASST2_REVISION = "179dd21fc55192153d94adb0e0ce8f69e222bf75"
_WILDCHAT_REVISION = "c827c6df8fcf008219ffaffa4d1dd77491099367"
_YODAS2_REVISION = "631fc446cb1a41ee93a1d390a167c6e08c2597a3"
_LATINIME_REVISION = "127336e9f29d69607eab55982324b210279ae8c5"
_ANCORA_TAG = "r2.19"
# Each YouTube-Commons file holds about 13 million words of native English transcripts.
_YOUTUBE_FILE_COUNT = 40

_YOUTUBE_LICENSE = dict(
    license="CC BY 4.0",
    license_url="https://creativecommons.org/licenses/by/4.0/",
    attribution=(
        "Based on YouTube-Commons by PleIAs: transcripts of videos their creators "
        "published under the Creative Commons Attribution license, each credited to "
        "its channel in the dataset."
    ),
)
_OASST2_LICENSE = dict(
    license="Apache License 2.0",
    license_url="https://www.apache.org/licenses/LICENSE-2.0",
    attribution="Based on the OpenAssistant OASST2 dataset created by the OpenAssistant contributors.",
)
_TATOEBA_LICENSE = dict(
    license="CC BY 2.0 FR",
    license_url="https://creativecommons.org/licenses/by/2.0/fr/deed.en",
    attribution="Based on sentence data contributed by the Tatoeba community.",
)

ENGLISH_YOUTUBE_COMMONS = Source(
    name="youtube-commons",
    files=tuple(
        SourceFile(
            url=(
                "https://huggingface.co/datasets/PleIAs/YouTube-Commons/resolve/"
                f"{_YOUTUBE_REVISION}/cctube_{index}.parquet"
            ),
            name=f"cctube_{index}.parquet",
        )
        for index in range(_YOUTUBE_FILE_COUNT)
    ),
    reader="youtube-commons-parquet",
    code="en",
    **_YOUTUBE_LICENSE,
)


def oasst2(code: str) -> Source:
    return Source(
        name="oasst2",
        files=(
            SourceFile(
                url=(
                    "https://huggingface.co/datasets/OpenAssistant/oasst2/resolve/"
                    f"{_OASST2_REVISION}/2023-11-05_oasst2_ready.messages.jsonl.gz"
                ),
                name="oasst2_ready.messages.jsonl.gz",
            ),
        ),
        reader="oasst2",
        code=code,
        **_OASST2_LICENSE,
    )


def tatoeba(code: str, sha256: str | None = None) -> Source:
    """Tatoeba's sentences in the language with ISO 639-3 code `code`. Tatoeba republishes its
    exports weekly at the same address, so a pinned SHA-256 tells when the export changed."""
    return Source(
        name="tatoeba",
        files=(
            SourceFile(
                url=f"https://downloads.tatoeba.org/exports/per_language/{code}/{code}_sentences.tsv.bz2",
                name=f"{code}_sentences.tsv.bz2",
                sha256=sha256,
            ),
        ),
        reader="tatoeba",
        code=code,
        **_TATOEBA_LICENSE,
    )


def youtube_commons(code: str, sha256: str) -> Source:
    """Transcripts in the language a video was spoken in, prepared from every YouTube-Commons
    file."""
    return Source(
        name="youtube-commons",
        files=(SourceFile(url=None, name=f"multilingual/{code}_original_transcripts.jsonl.zst", sha256=sha256),),
        reader="youtube-commons-jsonl",
        code=code,
        upstream=f"https://huggingface.co/datasets/PleIAs/YouTube-Commons at {_YOUTUBE_REVISION}",
        **_YOUTUBE_LICENSE,
    )


def yodas2(code: str, sha256: str) -> Source:
    """Captions written by hand for videos (the manual-caption shard `<code>000`)."""
    return Source(
        name="yodas2",
        files=(SourceFile(url=None, name=f"{code}_manual_captions.jsonl.zst", sha256=sha256),),
        reader="yodas2",
        code=code,
        upstream=f"https://huggingface.co/datasets/espnet/yodas2 at {_YODAS2_REVISION}",
        license="CC BY 3.0",
        license_url="https://creativecommons.org/licenses/by/3.0/",
        attribution=(
            "Based on YODAS2 by Li et al. (ESPnet): manual captions of videos published under "
            "Creative Commons licenses."
        ),
    )


def wildchat(code: str, sha256: str) -> Source:
    """What people wrote to a chat assistant: every user turn detected as the language."""
    return Source(
        name="wildchat",
        files=(SourceFile(url=None, name=f"{code}_user_turns.jsonl", sha256=sha256),),
        reader="wildchat",
        code=code,
        upstream=f"https://huggingface.co/datasets/allenai/WildChat-4.8M at {_WILDCHAT_REVISION}",
        license="ODC-By 1.0",
        license_url="https://opendatacommons.org/licenses/by/1-0/",
        attribution="Based on the WildChat-4.8M dataset by the Allen Institute for AI (Zhao et al., 2024).",
    )


SMS_88MIL = Source(
    name="88milsms",
    files=(
        SourceFile(
            url="https://repository.ortolang.fr/api/content/comere/v3.3/cmr-88milsms/cmr-88milsms-tei-v1.xml",
            name="cmr-88milsms-tei-v1.xml",
            sha256="947123c1ba5ba9dde98fde30813957bb7a7a3f709209816dc38157ca1e6cc404",
        ),
    ),
    reader="88milsms",
    code="fr",
    license="CC BY 4.0",
    license_url="https://creativecommons.org/licenses/by/4.0/",
    attribution=(
        "Based on 88milSMS (Panckhurst et al., CoMeRe corpus, ORTOLANG): text messages "
        "collected in Montpellier, France, in 2011."
    ),
)

OPEN_DISCOURSE = Source(
    name="open-discourse",
    files=(
        SourceFile(
            url=None,
            name="de_bundestag_speeches.jsonl.zst",
            sha256="a14f3bb4b7b4e6484af0e776ad71df0c7056cd89cfd15b753af3002a01276523",
        ),
    ),
    reader="open-discourse",
    code="de",
    upstream="https://doi.org/10.7910/DVN/FIKIBO, version 4.0, speeches.feather",
    license="CC0 1.0",
    license_url="https://creativecommons.org/publicdomain/zero/1.0/",
    attribution="Based on Open Discourse (Richter et al.): the speeches of the German Bundestag.",
)


def latinime_word_list(code: str, sha256: str) -> Source:
    return Source(
        name="aosp-latinime",
        files=(SourceFile(url=None, name=f"{code}_wordlist.combined.gz", sha256=sha256),),
        code=code,
        upstream=(
            "https://android.googlesource.com/platform/packages/inputmethods/LatinIME/+/"
            f"{_LATINIME_REVISION}/dictionaries/{code}_wordlist.combined.gz?format=TEXT (base64)"
        ),
        license="Apache License 2.0",
        license_url="https://www.apache.org/licenses/LICENSE-2.0",
        attribution="Copyright (c) 2008, The Android Open Source Project",
    )


def wikidata_forms(code: str, sha256: str) -> Source:
    return Source(
        name="wikidata-lexemes",
        files=(SourceFile(url=None, name=f"{code}_forms.tsv", sha256=sha256),),
        code=code,
        upstream="https://dumps.wikimedia.org/wikidatawiki/entities/20261118/wikidata-20261118-lexemes.json.gz",
        license="CC0 1.0",
        license_url="https://creativecommons.org/publicdomain/zero/1.0/",
        attribution="Based on Wikidata Lexemes.",
    )


GRAMMALECTE = Source(
    name="grammalecte",
    files=(
        SourceFile(
            url="https://www.grammalecte.net/dic/lexique-grammalecte-fr-v7.7.zip",
            name="lexique-grammalecte-fr-v7.7.zip",
            sha256="bdccf2065e252010253171000a38de84581407896b6bc60aca7d4d69dab7e4d2",
        ),
    ),
    code="fr",
    license="Mozilla Public License 2.0",
    license_url="https://www.mozilla.org/en-US/MPL/2.0/",
    attribution="Based on the Grammalecte French lexicon v7.7 by Olivier R.",
)

RLA_ES = Source(
    name="rla-es",
    files=(
        SourceFile(
            url="https://github.com/sbosio/rla-es/releases/download/v2.9/es.oxt",
            name="release-v2.9/es.oxt",
            sha256="b08a1a0e3e044697f63a67184f591f7e2c37bbb53bbfbb4780bcbd84929d6e8c",
        ),
    ),
    code="es",
    license="Mozilla Public License 1.1 or later (chosen from GPL 3+ / LGPL 3+ / MPL 1.1+)",
    license_url="https://www.mozilla.org/en-US/MPL/1.1/",
    attribution="Based on the RLA-ES Spanish spelling dictionaries v2.9 by Santiago Bosio and contributors.",
)

UD_SPANISH_ANCORA = Source(
    name="ud-spanish-ancora",
    files=tuple(
        SourceFile(
            url=(
                "https://raw.githubusercontent.com/UniversalDependencies/UD_Spanish-AnCora/"
                f"{_ANCORA_TAG}/es_ancora-ud-{part}.conllu"
            ),
            name=f"{_ANCORA_TAG}/es_ancora-ud-{part}.conllu",
            sha256=sha256,
        )
        for part, sha256 in (
            ("train", "acb96e0b3d28d8ae0288e0fb0a2d5243bd352c86bcecc0773deef5f40e612f83"),
            ("dev", "83033c89b18594a8c7d1571a0f259721714fd989974ca51bd9776bc69faba40c"),
            ("test", "4d74d95cfe5a53eacaa7adf3b7ae6ef76a7df9806fd519113e25d74c43ad2b9c"),
        )
    ),
    code="es",
    license="CC BY 4.0",
    license_url="https://creativecommons.org/licenses/by/4.0/",
    attribution=(
        "Based on UD Spanish AnCora (Taulé, Martí, and Recasens; Universal Dependencies "
        "release 2.19)."
    ),
)

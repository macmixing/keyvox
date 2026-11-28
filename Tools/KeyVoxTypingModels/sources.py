"""The inputs the English typing models are built from, pinned where the publisher allows,
with each source's license, and the paths they are stored at inside a data directory."""

from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class DownloadedFile:
    url: str
    path: str


@dataclass(frozen=True)
class ArchiveMember:
    member: str
    path: str


@dataclass(frozen=True)
class Source:
    name: str
    license: str
    license_url: str
    files: tuple[DownloadedFile, ...] = ()
    archive_url: str = ""
    archive_size: int = 0
    members: tuple[ArchiveMember, ...] = ()


_OASST1_REVISION = "fdf72ae0827c1cda404aff25b6603abec9e3399b"

# Tatoeba publishes only its current export, which is not pinned, so the models read the
# English sentences as they were in the weekly export of this time: `rewind_tatoeba.py` undoes
# every change the contribution log records after it, and checks the result against
# TATOEBA_SNAPSHOT_SHA256.
TATOEBA_CUTOFF = "2026-07-18 06:00:00"

# Whether the export shows a sentence also depends on state the contribution log does not
# record, so a few sentences were shown or hidden in the cutoff's export other than the log
# implies. These are the ones the bundled dictionary's word and word-pair probabilities point
# to; with them, the rebuilt rankers and accent overlay match the bundled ones byte for byte.
TATOEBA_HIDDEN_AT_CUTOFF = ("8802780", "11708712", "13126511", "13760010")
TATOEBA_SHOWN_AT_CUTOFF = ("300318", "757187", "12709696")

# SHA-256 of the uncompressed text of the sentences as of the cutoff, as `rewind_tatoeba.py`
# writes them: 2,031,914 sentences.
TATOEBA_SNAPSHOT_SHA256 = "83de7e31a04faea3bd48ea2a3effe89297c58b322c1087e34c07b7d811b98b04"

TATOEBA = Source(
    name="tatoeba",
    license="CC BY 2.0 FR",
    license_url="https://creativecommons.org/licenses/by/2.0/fr/deed.en",
    files=(
        DownloadedFile(
            url="https://downloads.tatoeba.org/exports/per_language/eng/eng_sentences.tsv.bz2",
            path="sources/tatoeba/eng_sentences.tsv.bz2",
        ),
        DownloadedFile(
            url="https://downloads.tatoeba.org/exports/contributions.tar.bz2",
            path="sources/tatoeba/contributions.tar.bz2",
        ),
    ),
)

OASST1 = Source(
    name="oasst1",
    license="Apache License 2.0",
    license_url="https://www.apache.org/licenses/LICENSE-2.0",
    files=(
        DownloadedFile(
            url=(
                "https://huggingface.co/datasets/OpenAssistant/oasst1/resolve/"
                f"{_OASST1_REVISION}/data/train-00000-of-00001-b42a775f407cee45.parquet"
            ),
            path="sources/oasst1/train.parquet",
        ),
    ),
)

# Only the English files the models need are read out of the archive, by byte range.
ITE = Source(
    name="ite",
    license="CC BY 4.0",
    license_url="https://creativecommons.org/licenses/by/4.0/",
    archive_url="https://zenodo.org/records/12528163/files/ite_typing_dataset.zip",
    archive_size=7_309_673_578,
    members=(
        ArchiveMember("ITE_words/ac_words_en.csv", "sources/ite/ITE_words/ac_words_en.csv"),
        ArchiveMember("ITE_words/pred_words_en.csv", "sources/ite/ITE_words/pred_words_en.csv"),
        ArchiveMember(
            "processed2020/english/sentences.csv",
            "sources/ite/processed2020/english/sentences.csv",
        ),
        ArchiveMember(
            "processed2020/english/test_sections_labeled.csv",
            "sources/ite/processed2020/english/test_sections_labeled.csv",
        ),
        ArchiveMember(
            "processed2020/english/participants_labeled.csv",
            "sources/ite/processed2020/english/participants_labeled.csv",
        ),
    ),
)

_PROFANITY_LIST_REVISION = "c27924319aa9bd6f917e3782b4f4b6604a50b652"

# The words the dictionary and the swipe vocabulary leave out (`offensive_words.py`).
PROFANITY_LIST = Source(
    name="profanity-list",
    license="MIT License",
    license_url=f"https://github.com/dsojevic/profanity-list/blob/{_PROFANITY_LIST_REVISION}/LICENSE",
    files=(
        DownloadedFile(
            url=f"https://raw.githubusercontent.com/dsojevic/profanity-list/{_PROFANITY_LIST_REVISION}/en.json",
            path="sources/profanity-list/en.json",
        ),
    ),
)

# Multilingual HateCheck's test cases, one dataset per language on Hugging Face, each pinned to a
# revision; another language's dictionary leaves out the slurs its cases tag (`hatecheck_slurs.py`,
# `offensive_words.py`).
_HATECHECK_REVISIONS = {
    "german": "5229a5cc475f36c08d03ca52f0ccb005705e60d2",
    "french": "5d3085f2129139abc10d2b58becd4d4f2978e5d5",
}
MULTILINGUAL_HATECHECK = Source(
    name="multilingual-hatecheck",
    license="CC BY 4.0",
    license_url="https://creativecommons.org/licenses/by/4.0/",
    files=tuple(
        DownloadedFile(
            url=f"https://huggingface.co/datasets/Paul/hatecheck-{dataset}/resolve/{revision}/test.csv",
            path=f"sources/multilingual-hatecheck/{dataset}.csv",
        )
        for dataset, revision in _HATECHECK_REVISIONS.items()
    ),
)

# The English typing models' sources; another language downloads only its HateCheck dataset.
SOURCES = (TATOEBA, OASST1, ITE, PROFANITY_LIST)


def tatoeba_export_path(data_dir: Path) -> Path:
    return data_dir / TATOEBA.files[0].path


def tatoeba_contributions_path(data_dir: Path) -> Path:
    return data_dir / TATOEBA.files[1].path


def tatoeba_path(data_dir: Path) -> Path:
    """The English sentences as of TATOEBA_CUTOFF, written by rewind_tatoeba.py and kept with
    the sources, since today's export may no longer rewind to them."""
    return data_dir / "sources" / "tatoeba" / "eng_sentences_at_cutoff.tsv.bz2"


def oasst1_path(data_dir: Path) -> Path:
    return data_dir / OASST1.files[0].path


def profanity_list_path(data_dir: Path, name: str = "en.json") -> Path:
    """The profanity list's file of a language's terms, such as `en.json`."""
    for file in PROFANITY_LIST.files:
        if Path(file.path).name == name:
            return data_dir / file.path
    raise KeyError(name)


def hatecheck_file(dataset: str) -> DownloadedFile:
    """The pinned file of one of Multilingual HateCheck's datasets, such as `german`."""
    for file in MULTILINGUAL_HATECHECK.files:
        if Path(file.path).stem == dataset:
            return file
    raise KeyError(dataset)


def ite_path(data_dir: Path, member: str) -> Path:
    for entry in ITE.members:
        if entry.member == member:
            return data_dir / entry.path
    raise KeyError(member)

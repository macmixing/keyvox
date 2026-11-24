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

# Tatoeba publishes only its current export, so the models read the English sentences as
# they were in the weekly export of this time: `rewind_tatoeba.py` undoes every change the
# contribution log records after it.
TATOEBA_CUTOFF = "2026-07-18 06:00:00"

# Whether the export shows a sentence also depends on state the contribution log does not
# record, so a few sentences were shown or hidden in the cutoff's export other than the log
# implies. These are the ones the bundled dictionary's word and word-pair probabilities point
# to; with them, the rebuilt rankers and accent overlay match the bundled ones byte for byte.
TATOEBA_HIDDEN_AT_CUTOFF = ("8802780", "11708712", "13126511", "13760010")
TATOEBA_SHOWN_AT_CUTOFF = ("300318", "757187", "12709696")

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

SOURCES = (TATOEBA, OASST1, ITE)


def tatoeba_export_path(data_dir: Path) -> Path:
    return data_dir / TATOEBA.files[0].path


def tatoeba_contributions_path(data_dir: Path) -> Path:
    return data_dir / TATOEBA.files[1].path


def tatoeba_path(data_dir: Path) -> Path:
    """The English sentences as of TATOEBA_CUTOFF, written by rewind_tatoeba.py."""
    return data_dir / "work" / "tatoeba_eng_sentences_at_cutoff.tsv.bz2"


def oasst1_path(data_dir: Path) -> Path:
    return data_dir / OASST1.files[0].path


def ite_path(data_dir: Path, member: str) -> Path:
    for entry in ITE.members:
        if entry.member == member:
            return data_dir / entry.path
    raise KeyError(member)

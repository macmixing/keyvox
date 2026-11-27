"""The swipe recordings the KeyVox swipe model is trained and measured on, pinned to exact
versions, with each source's license and the attribution it requires."""

from dataclasses import dataclass


@dataclass(frozen=True)
class SourceFile:
    url: str
    name: str


@dataclass(frozen=True)
class Source:
    name: str
    files: tuple[SourceFile, ...]
    license: str
    license_url: str
    attribution: str


_FUTO_REVISION = "d71bf5fd7f45b3e7c2ed2d76a21b0dbd3b4ba566"
_FUTO_FILES = (
    "LICENSE",
    "README.md",
    "train.jsonl",
    "dev.jsonl",
    "test.jsonl",
    "swipe-2/README.md",
    "swipe-2/swipe2.jsonl",
    "swipe-3/README.md",
    "swipe-3/swipe3.jsonl",
    "swipe-4/README.md",
    "swipe-4/swipe4.jsonl",
    "swipe-5/README.md",
    "swipe-5/swipe5.jsonl",
    "swipe-5/layouts/qwerty.json",
    "swipe-5/layouts/qwertz.json",
    "swipe-5/layouts/german.json",
    "swipe-5/layouts/azerty.json",
    "swipe-5/layouts/spanish.json",
    "swipe-5/layouts/clearflow.json",
    "swipe-5/layouts/dvorak.json",
    "swipe-5/layouts/kasroz.json",
)
_HOW_WE_SWIPE_FILES = (
    ("wy9q8", "metadata.tsv"),
    ("efzmp", "wordfreq.txt"),
    ("x4yjn", "swipelogs.zip"),
)

SOURCES = (
    Source(
        name="futo-swipe",
        files=tuple(
            SourceFile(
                url=(
                    "https://huggingface.co/datasets/futo-org/swipe.futo.org/resolve/"
                    f"{_FUTO_REVISION}/{name}"
                ),
                name=name,
            )
            for name in _FUTO_FILES
        ),
        license="MIT",
        license_url="https://huggingface.co/datasets/futo-org/swipe.futo.org/blob/main/LICENSE",
        attribution="Based on the swipe.futo.org dataset collected by FUTO.",
    ),
    Source(
        name="how-we-swipe",
        files=tuple(
            SourceFile(url=f"https://osf.io/download/{identifier}/", name=name)
            for identifier, name in _HOW_WE_SWIPE_FILES
        ),
        license="MIT",
        license_url="https://osf.io/sj67f/",
        attribution=(
            "Based on Leiva, Kim, Cui, Bi, and Oulasvirta, *How We Swipe: A Large-scale "
            "Shape-writing Dataset and Empirical Findings* (MobileHCI 2021)."
        ),
    ),
)

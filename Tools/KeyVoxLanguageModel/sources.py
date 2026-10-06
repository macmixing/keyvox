"""The text the KeyVox context model is built from, pinned to exact versions, with each
source's license and the attribution it requires."""

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


_YOUTUBE_REVISION = "9addbabbfcd7409acbcd11a3b59ec2aef6da7eb0"
_OASST2_REVISION = "179dd21fc55192153d94adb0e0ce8f69e222bf75"
# Each YouTube-Commons file holds about 13 million words of native English transcripts.
_YOUTUBE_FILE_COUNT = 40

SOURCES = (
    Source(
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
        license="CC BY 4.0",
        license_url="https://creativecommons.org/licenses/by/4.0/",
        attribution=(
            "Based on YouTube-Commons by PleIAs: transcripts of videos their creators "
            "published under the Creative Commons Attribution license, each credited to "
            "its channel in the dataset."
        ),
    ),
    Source(
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
        license="Apache License 2.0",
        license_url="https://www.apache.org/licenses/LICENSE-2.0",
        attribution="Based on the OpenAssistant OASST2 dataset created by the OpenAssistant contributors.",
    ),
    Source(
        name="tatoeba",
        files=(
            SourceFile(
                url="https://downloads.tatoeba.org/exports/per_language/eng/eng_sentences.tsv.bz2",
                name="eng_sentences.tsv.bz2",
            ),
        ),
        license="CC BY 2.0 FR",
        license_url="https://creativecommons.org/licenses/by/2.0/fr/deed.en",
        attribution="Based on sentence data contributed by the Tatoeba community.",
    ),
)

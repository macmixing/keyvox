"""Reads each of a language's sources and writes its text as normalized sentences, one per
line with words separated by spaces, to `<data_dir>/sentences/<source>.txt`."""

import argparse
from pathlib import Path

from languages import LANGUAGES, language_argument
from normalize import sentences
from source_texts import source_texts


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    language_argument(parser)
    parser.add_argument("data_dir", type=Path)
    arguments = parser.parse_args()
    language = LANGUAGES[arguments.language]

    output_directory = arguments.data_dir / "sentences"
    output_directory.mkdir(parents=True, exist_ok=True)
    for source, texts in source_texts(language, arguments.data_dir):
        text_count = 0
        sentence_count = 0
        word_count = 0
        with open(output_directory / f"{source.name}.txt", "w", encoding="utf-8") as output:
            for text in texts:
                text_count += 1
                for words in sentences(text, language.text_rules):
                    output.write(" ".join(words))
                    output.write("\n")
                    sentence_count += 1
                    word_count += len(words)
        print(f"{source.name}: {text_count} texts, {sentence_count} sentences, {word_count} words", flush=True)


if __name__ == "__main__":
    main()

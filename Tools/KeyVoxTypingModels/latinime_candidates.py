"""Asks the compiled LatinIME suggestion reader for the candidates of many queries at once,
and keeps the answers in a cache so the rankers can be trained without asking again."""

import gzip
import pickle
import subprocess

from letter_keys import key_for
from words import normalized

MAX_CANDIDATES = 8


def query_key(typed, previous):
    return normalized(typed), tuple(normalized(word) for word in previous[:3] if normalized(word))


def unique_queries(collections):
    """Each distinct query of the record collections, in first-seen order."""
    keys = []
    seen = set()
    for collection in collections:
        for record in collection:
            key = query_key(record["typed"], record["previous"])
            if not key[0] and not key[1]:
                continue
            if key not in seen:
                seen.add(key)
                keys.append(key)
    return keys


def row_arguments(letter_rows):
    """The suggestion reader's arguments for a layout's letter rows
    (`letter_layout.letter_rows`)."""
    arguments = []
    for letters, offset in letter_rows:
        arguments += ["--row", letters, repr(float(offset))]
    return arguments


def key_arguments(letter_rows, keys):
    """The suggestion reader's arguments giving each typed letter without a key of its own the key
    that types it (`letter_keys.key_for`)."""
    letters = {letter for row, _ in letter_rows for letter in row}
    arguments = []
    for typed in sorted({character for typed, _ in keys for character in typed} - letters):
        key = key_for(typed, letters)
        if key is not None:
            arguments += ["--key-for", typed, key]
    return arguments


def run_suggestions(reader, dictionary, keys, query_path, letter_rows, shared_session=False):
    """LatinIME's candidates for each query, deduplicated, best first, as (word, score, type), with
    the typed letters tapped on the keys of `letter_rows`, a letter without a key of its own on the
    key that types it.

    Each query searches in a session of its own, or, with `shared_session`, all in one, as the
    caches the bundled rankers learned from did (`latinime_suggestions.cpp`)."""
    with query_path.open("w", encoding="utf-8") as target:
        for typed, previous in keys:
            target.write("\t".join((typed, *previous)) + "\n")
    print(f"running {len(keys):,} queries", flush=True)
    outputs = {}
    with query_path.open(encoding="utf-8") as stdin:
        process = subprocess.Popen(
            [str(reader), str(dictionary), *(["--shared-session"] if shared_session else []),
             *row_arguments(letter_rows), *key_arguments(letter_rows, keys)],
            stdin=stdin,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1,
        )
        for line in process.stdout:
            fields = line.rstrip("\n").split("\t")
            results = []
            for position in range(1, len(fields) - 2, 3):
                results.append((normalized(fields[position]), int(fields[position + 1]),
                                int(fields[position + 2])))
            deduped = []
            observed = set()
            for result in results:
                if result[0] and result[0] not in observed:
                    observed.add(result[0])
                    deduped.append(result)
            outputs[keys[int(fields[0])]] = deduped
        stderr = process.stderr.read()
        status = process.wait()
    if status:
        raise RuntimeError(f"suggestion reader exited {status}: {stderr[-2000:]}")
    return outputs


def save(outputs, path):
    with gzip.open(path, "wb", compresslevel=3) as target:
        pickle.dump(outputs, target, protocol=pickle.HIGHEST_PROTOCOL)


def load(path):
    with gzip.open(path, "rb") as source:
        return pickle.load(source)


def candidate_items(record, outputs, remove_literal=True):
    result = outputs.get(query_key(record["typed"], record["previous"]), [])
    if remove_literal:
        result = [item for item in result if item[0] != record["typed"]]
    return [item for item in result if item[0] and " " not in item[0]][:MAX_CANDIDATES]

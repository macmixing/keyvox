"""Where each step reads and writes inside a data directory: inputs under `sources/`,
intermediate files under `work/`, the compiled native tools under `bin/`, and the files the
keyboard bundles under `built/`."""

from pathlib import Path


class DataPaths:
    def __init__(self, data_dir: Path):
        self.root = data_dir.resolve()
        self.work = self.root / "work"
        self.built = self.root / "built"
        self.bin = self.root / "bin"

    # SCOWL word lists, written by scowl_word_list.sh.
    @property
    def dictionary_words(self) -> Path:
        return self.work / "scowl-60-A.txt"

    @property
    def accented_words(self) -> Path:
        return self.work / "scowl-60-ABZCD.txt"

    @property
    def protected_words(self) -> Path:
        return self.work / "scowl-50-ABZCD.txt"

    # Dictionary inputs and the dictionary itself.
    @property
    def dictionary_unigrams(self) -> Path:
        return self.work / "dictionary_unigrams.tsv"

    @property
    def dictionary_ngrams(self) -> Path:
        return self.work / "dictionary_ngrams.tsv"

    @property
    def accent_unigrams(self) -> Path:
        return self.work / "accent_unigrams.tsv"

    @property
    def dictionary(self) -> Path:
        return self.built / "candidate_v3_dict"

    # ITE typing events split by typist.
    def ite_split(self, name: str) -> Path:
        return self.work / "ite" / f"{name}.tsv"

    # LatinIME suggestion caches.
    @property
    def correction_queries(self) -> Path:
        return self.work / "correction_queries.tsv"

    @property
    def correction_candidates(self) -> Path:
        return self.work / "correction_candidates.pkl.gz"

    @property
    def completion_queries(self) -> Path:
        return self.work / "completion_queries.tsv"

    @property
    def completion_candidates(self) -> Path:
        return self.work / "completion_candidates.pkl.gz"

    # The word and word-pair counts the rankers are trained with.
    @property
    def feature_context_model(self) -> Path:
        return self.work / "feature_context_800k.bin"

    # Trained models before export.
    @property
    def correction_ranker_model(self) -> Path:
        return self.work / "correction_ranker.pkl.gz"

    @property
    def action_model(self) -> Path:
        return self.work / "action.pkl.gz"

    @property
    def completion_ranker_model(self) -> Path:
        return self.work / "completion_ranker.pkl.gz"

    # Reports each step writes.
    def report(self, name: str) -> Path:
        return self.work / "reports" / f"{name}.json"

    # Native tools, built by build_native_tools.sh.
    @property
    def dictionary_writer(self) -> Path:
        return self.bin / "write_latinime_dictionary"

    @property
    def suggestion_reader(self) -> Path:
        return self.bin / "latinime_suggestions"

    # Bundled files.
    @property
    def correction_ranker(self) -> Path:
        return self.built / "production_ranker_800k.kvtr"

    @property
    def completion_ranker(self) -> Path:
        return self.built / "production_completion_ranker_800k.kvtr"

    @property
    def action(self) -> Path:
        return self.built / "production_action_800k.kvtr"

    @property
    def accent_overlay(self) -> Path:
        return self.built / "accent_overlay.bin"

"""Where each step reads and writes inside a data directory: inputs under `sources/`,
intermediate files under `work/`, the compiled native tools under `bin/`, and the files the
keyboard bundles under `built/`, named as in the package's typing language folders."""

from pathlib import Path


class DataPaths:
    def __init__(self, data_dir: Path):
        self.root = data_dir.resolve()
        self.work = self.root / "work"
        self.built = self.root / "built"
        self.bin = self.root / "bin"

    # What Tools/KeyVoxLanguageModel built for a language other than English, linked in
    # (language_build.py).
    @property
    def language_build(self) -> Path:
        return self.root / "sources" / "language-build"

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

    # The patterns of the words the dictionary leaves out, written by offensive_words.py.
    @property
    def offensive_words(self) -> Path:
        return self.work / "offensive_words.txt"

    # Dictionary inputs and the dictionary itself.
    @property
    def dictionary_unigrams(self) -> Path:
        return self.work / "dictionary_unigrams.tsv"

    @property
    def dictionary_ngrams(self) -> Path:
        return self.work / "dictionary_ngrams.tsv"

    # The dictionary's words and sequences less the ones offensive_words.py matches, which the
    # dictionary is compiled from.
    @property
    def dictionary_kept_unigrams(self) -> Path:
        return self.work / "dictionary_kept_unigrams.tsv"

    @property
    def dictionary_kept_ngrams(self) -> Path:
        return self.work / "dictionary_kept_ngrams.tsv"

    @property
    def accent_unigrams(self) -> Path:
        return self.work / "accent_unigrams.tsv"

    @property
    def dictionary(self) -> Path:
        return self.built / "dictionary"

    # The dictionary compiled from every word and sequence counted, with the ones
    # offensive_words.py matches, as the bundled rankers learned from it.
    @property
    def counted_dictionary(self) -> Path:
        return self.work / "counted_dictionary"

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

    # The typo simulator's measurements, fitted touch spread, and simulated records.
    @property
    def simulation(self) -> Path:
        return self.work / "simulation"

    @property
    def typing_measurements(self) -> Path:
        return self.simulation / "ite_typing.json"

    @property
    def touch_spread(self) -> Path:
        return self.simulation / "touch_spread.json"

    @property
    def typo_calibration(self) -> Path:
        return self.simulation / "typo_calibration.json"

    def simulated_records(self, name: str) -> Path:
        return self.simulation / f"{name}.tsv"

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
        return self.built / "correction_ranker.kvtr"

    @property
    def completion_ranker(self) -> Path:
        return self.built / "completion_ranker.kvtr"

    @property
    def autocorrect_decision(self) -> Path:
        return self.built / "autocorrect_decision.kvtr"

    @property
    def accent_overlay(self) -> Path:
        return self.built / "accent_overlay.bin"

    @property
    def bundled_files(self) -> tuple[Path, ...]:
        """Every built file, each at the path it has in the language folder relative to `built/`.
        LatinIME names a dictionary's files after its folder."""
        return (
            self.dictionary / "dictionary.header", self.dictionary / "dictionary.body",
            self.correction_ranker, self.completion_ranker, self.autocorrect_decision,
            self.accent_overlay,
        )

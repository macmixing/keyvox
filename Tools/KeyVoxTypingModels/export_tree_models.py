"""Exports the trained correction ranker, completion ranker, and action model to the KVTR0001
files the keyboard bundles, in `<data_dir>/built/`, and checks that each exported file
scores 10,000 random rows, many of them right at a split threshold, as the trained model
does."""

import argparse
import gzip
import json
import pickle
from pathlib import Path

import numpy as np

import portable_tree_model
from paths import DataPaths

CANDIDATE_FEATURES = 23
ACTION_FEATURES = 14


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("data_dir", type=Path)
    paths = DataPaths(parser.parse_args().data_dir)
    paths.built.mkdir(parents=True, exist_ok=True)

    models = {
        "ranker": (paths.correction_ranker_model, paths.correction_ranker, CANDIDATE_FEATURES),
        "action": (paths.action_model, paths.action, ACTION_FEATURES),
        "completion": (paths.completion_ranker_model, paths.completion_ranker,
                       CANDIDATE_FEATURES),
    }
    report = {}
    rng = np.random.default_rng(481516)
    for name, (source, target, feature_count) in models.items():
        with gzip.open(source, "rb") as file:
            model = pickle.load(file)
        portable_tree_model.write(model, target, feature_count)
        portable = portable_tree_model.PortableTreeModel(target)
        thresholds = [(int(node["feature_idx"]), float(node["num_threshold"]))
                      for iteration in model._predictors for node in iteration[0].nodes
                      if not node["is_leaf"]]
        rows = rng.normal(size=(10_000, feature_count))
        for row_index, (feature, threshold) in enumerate(thresholds[:5000]):
            rows[row_index, feature] = threshold + rng.choice((-1e-5, 0.0, 1e-5))
        expected = model.predict_proba(rows)[:, 1]
        actual = portable.predict_proba(rows)
        delta = float(np.max(np.abs(expected - actual)))
        report[name] = {
            "bytes": target.stat().st_size,
            "tree_count": len(portable.trees),
            "node_count": sum(count for _, count in portable.trees),
            "max_probability_delta": delta,
        }
        if delta > 1e-9:
            raise RuntimeError(f"{name}: exported trees disagree with the model by {delta}")
        print(f"[{name}] {target} bytes={target.stat().st_size:,} max_probability_delta={delta:.3g}")

    paths.report("tree_export").parent.mkdir(parents=True, exist_ok=True)
    paths.report("tree_export").write_text(json.dumps(report, indent=2, sort_keys=True),
                                           encoding="utf-8")


if __name__ == "__main__":
    main()

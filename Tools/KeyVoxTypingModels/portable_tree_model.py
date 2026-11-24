"""The KVTR0001 format the keyboard's native engine reads gradient-boosted trees in: a header
with the feature count, tree count, and baseline score, then each tree as a node count and
its nodes (feature, flags, left child, right child, threshold, leaf value)."""

import math
import struct

import numpy as np

MAGIC = b"KVTR0001"
HEADER = struct.Struct("<8sHHd")
TREE_HEADER = struct.Struct("<H")
NODE = struct.Struct("<BBHHdd")
LEAF_FLAG = 1
MISSING_GOES_LEFT_FLAG = 2


def write(model, path, feature_count):
    """Writes a trained binary HistGradientBoostingClassifier."""
    trees = [iteration[0] for iteration in model._predictors]
    baseline = float(model._baseline_prediction[0, 0])
    with path.open("wb") as target:
        target.write(HEADER.pack(MAGIC, feature_count, len(trees), baseline))
        for tree in trees:
            nodes = tree.nodes
            if len(nodes) > 65535:
                raise ValueError("tree is too large for the portable format")
            target.write(TREE_HEADER.pack(len(nodes)))
            for node in nodes:
                flags = (int(bool(node["is_leaf"])) * LEAF_FLAG
                         | int(bool(node["missing_go_to_left"])) * MISSING_GOES_LEFT_FLAG)
                feature = int(node["feature_idx"]) if not node["is_leaf"] else 0
                target.write(NODE.pack(
                    feature, flags, int(node["left"]), int(node["right"]),
                    float(node["num_threshold"]), float(node["value"]),
                ))


class PortableTreeModel:
    def __init__(self, path):
        self.data = path.read_bytes()
        magic, self.feature_count, tree_count, self.baseline = HEADER.unpack_from(self.data)
        if magic != MAGIC:
            raise ValueError(f"bad model magic: {magic!r}")
        self.trees = []
        offset = HEADER.size
        for _ in range(tree_count):
            node_count = TREE_HEADER.unpack_from(self.data, offset)[0]
            offset += TREE_HEADER.size
            self.trees.append((offset, node_count))
            offset += node_count * NODE.size
        if offset != len(self.data):
            raise ValueError("unexpected trailing model bytes")

    def raw_predict_one(self, features):
        total = float(self.baseline)
        for offset, node_count in self.trees:
            index = 0
            while True:
                feature, flags, left, right, threshold, value = NODE.unpack_from(
                    self.data, offset + index * NODE.size)
                if flags & LEAF_FLAG:
                    total += value
                    break
                observed = features[feature]
                if math.isnan(observed):
                    index = left if flags & MISSING_GOES_LEFT_FLAG else right
                else:
                    index = left if observed <= threshold else right
                if index >= node_count:
                    raise ValueError("tree child index is out of range")
        return total

    def predict_proba(self, rows):
        raw = np.asarray([self.raw_predict_one(row) for row in rows])
        return 1.0 / (1.0 + np.exp(-raw))

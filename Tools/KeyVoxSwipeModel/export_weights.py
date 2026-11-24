"""Writes a trained encoder as a flat little-endian file of fp16 tensors for on-device
inference. The layout of the file is described in README.md ("Exported weights").

Batch normalizations that follow a convolution are folded into it; the input
normalization, which comes before a zero-padded convolution, is written as a per-feature
scale and shift."""

import argparse
import struct
from pathlib import Path

import numpy as np
import torch

from emissions import load_encoder
from prepare_swipes import POINTS
from weights_format import EXPORTED_FILE, MAGIC, VERSION


def _fold(conv: torch.nn.Conv1d, norm: torch.nn.BatchNorm1d) -> tuple[np.ndarray, np.ndarray]:
    scale = norm.weight / torch.sqrt(norm.running_var + norm.eps)
    weight = conv.weight * scale[:, None, None]
    bias = (conv.bias - norm.running_mean) * scale + norm.bias
    return weight.numpy(), bias.numpy()


def exported_tensors(model) -> list[tuple[str, np.ndarray]]:
    model = model.cpu().eval()
    tensors = []
    with torch.no_grad():
        norm = model.input_norm
        scale = norm.weight / torch.sqrt(norm.running_var + norm.eps)
        tensors += [("input.scale", scale.numpy()), ("input.shift", (norm.bias - norm.running_mean * scale).numpy())]
        weight, bias = _fold(model.stem, model.stem_norm)
        tensors += [("stem.weight", weight), ("stem.bias", bias)]
        for number, block in enumerate(model.blocks):
            prefix = f"block{number}."
            weight, bias = _fold(block.depthwise, block.norm)
            tensors += [
                (prefix + "depthwise.weight", weight[:, 0, :]),
                (prefix + "depthwise.bias", bias),
                (prefix + "expand.weight", block.expand.weight[:, :, 0].numpy()),
                (prefix + "expand.bias", block.expand.bias.numpy()),
                (prefix + "response.gamma", block.response.gamma.flatten().numpy()),
                (prefix + "response.beta", block.response.beta.flatten().numpy()),
                (prefix + "project.weight", block.project.weight[:, :, 0].numpy()),
                (prefix + "project.bias", block.project.bias.numpy()),
                (prefix + "excite.reduce.weight", block.excite.reduce.weight.numpy()),
                (prefix + "excite.reduce.bias", block.excite.reduce.bias.numpy()),
                (prefix + "excite.expand.weight", block.excite.expand.weight.numpy()),
                (prefix + "excite.expand.bias", block.excite.expand.bias.numpy()),
            ]
        weight, bias = _fold(model.adapter, model.adapter_norm)
        tensors += [("adapter.weight", weight), ("adapter.bias", bias)]
        tensors += [
            ("coefficients.weight", model.coefficients.weight.numpy()),
            ("coefficients.bias", model.coefficients.bias.numpy()),
            ("gate.weight", model.gate.weight.numpy()),
            ("gate.bias", model.gate.bias.numpy()),
        ]
    return tensors


def write_weights(path: Path, model) -> None:
    config = model.config
    tensors = exported_tensors(model)
    header = MAGIC + struct.pack(
        "<9I", VERSION, POINTS, config.width, config.expansion, config.kernel, config.head_width,
        config.basis, len(config.dilations), len(tensors),
    )
    header += struct.pack(f"<{len(config.dilations)}I", *config.dilations)
    for name, array in tensors:
        encoded = name.encode("ascii")
        header += struct.pack("<H", len(encoded)) + encoded + struct.pack("<B", array.ndim)
        header += struct.pack(f"<{array.ndim}I", *array.shape)
    with open(path, "wb") as file:
        file.write(header)
        for _, array in tensors:
            file.write(np.ascontiguousarray(array, dtype="<f2").tobytes())


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("run")
    parser.add_argument("--checkpoint", default="best.pt")
    arguments = parser.parse_args()
    run_dir = arguments.data_dir / "models" / arguments.run
    output = run_dir / EXPORTED_FILE
    write_weights(output, load_encoder(run_dir / arguments.checkpoint, torch.device("cpu")))
    print(f"wrote {output} ({output.stat().st_size} bytes)")


if __name__ == "__main__":
    main()

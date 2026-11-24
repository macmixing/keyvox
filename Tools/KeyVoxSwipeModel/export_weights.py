"""Writes a trained encoder, and optionally a decoder, as flat fp16 tensor files for
on-device inference (`weights_format.py`; tensors and config values are listed in
README.md, "Exported weights").

Batch normalizations that follow a convolution are folded into it; the input
normalization, which comes before a zero-padded convolution, is written as a per-feature
scale and shift."""

import argparse
from pathlib import Path

import numpy as np
import torch

from emissions import load_encoder
from decoder_model import DecoderConfig, SwipeDecoder
from prepare_swipes import POINTS
from weights_format import DECODER_FILE, DECODER_MAGIC, ENCODER_FILE, ENCODER_MAGIC, write_tensor_file


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


def decoder_tensors(decoder: SwipeDecoder) -> list[tuple[str, np.ndarray]]:
    decoder = decoder.cpu().eval()
    tensors = [("project.weight", decoder.project.weight), ("project.bias", decoder.project.bias)]
    for number, block in enumerate(decoder.blocks):
        prefix = f"block{number}."
        tensors += [
            (prefix + "down.weight", block.down.weight),
            (prefix + "memory.weight", block.memory.weight[:, 0, :]),
            (prefix + "up.weight", block.up.weight),
            (prefix + "up.bias", block.up.bias),
        ]
    tensors += [("head.weight", decoder.head.weight), ("head.bias", decoder.head.bias)]
    return [(name, value.detach().numpy()) for name, value in tensors]


def write_encoder(path: Path, model) -> None:
    config = model.config
    values = [POINTS, config.width, config.expansion, config.kernel, config.head_width, config.basis,
              len(config.dilations), *config.dilations]
    write_tensor_file(path, ENCODER_MAGIC, values, exported_tensors(model))


def write_decoder(path: Path, decoder: SwipeDecoder) -> None:
    config = decoder.config
    values = [config.symbols, config.coefficients, config.width, config.bottleneck, config.blocks, config.memory]
    write_tensor_file(path, DECODER_MAGIC, values, decoder_tensors(decoder))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("run", help="an encoder run, or a decoder run (exports its encoder too)")
    parser.add_argument("--checkpoint", default="best.pt")
    arguments = parser.parse_args()
    models = arguments.data_dir / "models"
    run_dir = models / arguments.run
    outputs = []
    decoder_path = run_dir / "decoder.pt"
    if decoder_path.exists():
        state = torch.load(decoder_path, map_location="cpu")
        decoder = SwipeDecoder(DecoderConfig(**state["config"]))
        decoder.load_state_dict(state["model"])
        write_decoder(run_dir / DECODER_FILE, decoder)
        outputs.append(run_dir / DECODER_FILE)
        encoder_checkpoint = models / state["encoder_run"] / "best.pt"
    else:
        encoder_checkpoint = run_dir / arguments.checkpoint
    write_encoder(run_dir / ENCODER_FILE, load_encoder(encoder_checkpoint, torch.device("cpu")))
    outputs.append(run_dir / ENCODER_FILE)
    for output in outputs:
        print(f"wrote {output} ({output.stat().st_size} bytes)")


if __name__ == "__main__":
    main()

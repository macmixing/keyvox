"""Computes a run's final log-emissions for swipes: an encoder run's, or a decoder run's
(its encoder, then the decoder), from PyTorch checkpoints or from the exported fp16 files."""

from pathlib import Path

import numpy as np
import torch

from decoder_model import DecoderConfig, SwipeDecoder
from emissions import compute_frames, load_encoder
from exported_model import decode_frames, frames, read_decoder, read_encoder
from layouts import Layout
from weights_format import DECODER_FILE, ENCODER_FILE

DECODER_CHECKPOINT = "decoder.pt"
_BATCH = 1024


def is_decoder_run(run_dir: Path) -> bool:
    return (run_dir / DECODER_CHECKPOINT).exists()


def run_emissions(models: Path, run: str, xy: np.ndarray, layout: Layout, device: torch.device,
                  exported: bool, checkpoint: str = "best.pt") -> np.ndarray:
    run_dir = models / run
    symbols = len(layout.letters) + 1
    decoder_state = torch.load(run_dir / DECODER_CHECKPOINT, map_location=device) if is_decoder_run(run_dir) else None

    if exported:
        encoder = read_encoder(run_dir / ENCODER_FILE)
        decoder = read_decoder(run_dir / DECODER_FILE) if decoder_state else None
        outputs = []
        for start in range(0, len(xy), _BATCH):
            encoded = frames(encoder, xy[start:start + _BATCH], layout.centers)
            outputs.append(decode_frames(decoder, encoded) if decoder else encoded[..., :symbols])
        return np.concatenate(outputs)

    encoder_checkpoint = models / decoder_state["encoder_run"] / "best.pt" if decoder_state else run_dir / checkpoint
    encoded = compute_frames(load_encoder(encoder_checkpoint, device), xy, layout, device)
    if not decoder_state:
        return encoded[..., :symbols]
    decoder = SwipeDecoder(DecoderConfig(**decoder_state["config"])).to(device).eval()
    decoder.load_state_dict(decoder_state["model"])
    with torch.no_grad():
        return np.concatenate([
            decoder(torch.from_numpy(encoded[start:start + _BATCH]).to(device)).cpu().numpy()
            for start in range(0, len(encoded), _BATCH)
        ])

"""Loads a trained encoder checkpoint and computes per-frame key log-probabilities."""

from pathlib import Path

import numpy as np
import torch

from layouts import Layout
from model import EncoderConfig, SwipeEncoder, key_basis, log_emissions

_BATCH = 4096


def load_encoder(checkpoint: Path, device: torch.device) -> SwipeEncoder:
    state = torch.load(checkpoint, map_location=device)
    model = SwipeEncoder(EncoderConfig.from_dict(state["config"])).to(device)
    model.load_state_dict(state["model"])
    return model.eval()


def compute_frames(model: SwipeEncoder, xy: np.ndarray, layout: Layout, device: torch.device,
                   dtype=np.float32) -> np.ndarray:
    """[N, T, 2] swipes to [N, T / 2, K + 1 + basis^2 + 1]: log-probabilities (blank at index
    0), then the cosine coefficients, then the gate probability."""
    centers = torch.from_numpy(layout.centers).to(device)
    basis = key_basis(centers, model.config.basis)
    mask = torch.ones(1, len(layout.letters), dtype=torch.bool, device=device)
    outputs = []
    with torch.no_grad():
        for start in range(0, len(xy), _BATCH):
            batch = torch.from_numpy(xy[start:start + _BATCH]).to(device)
            coefficients, gate = model(batch)
            size = batch.shape[0]
            emissions = log_emissions(coefficients, gate, basis.expand(size, -1, -1), mask.expand(size, -1))
            frames = torch.cat([emissions, coefficients, torch.sigmoid(gate).unsqueeze(2)], dim=2)
            outputs.append(frames.cpu().numpy().astype(dtype))
    return np.concatenate(outputs)


def compute_emissions(model: SwipeEncoder, xy: np.ndarray, layout: Layout, device: torch.device) -> np.ndarray:
    """[N, T, 2] swipes to [N, T / 2, K + 1] log-probabilities, blank at index 0."""
    return compute_frames(model, xy, layout, device)[..., : len(layout.letters) + 1]

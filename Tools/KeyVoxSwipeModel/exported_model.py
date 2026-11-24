"""Reads an exported `.kvsw` file and runs the encoder in plain NumPy, operation by
operation, as on-device inference must: the reference an Accelerate port is checked
against."""

import struct
from dataclasses import dataclass
from pathlib import Path

import numpy as np

from model import (_FIRST_DERIVATIVE, _FIRST_DERIVATIVE_SCALE, _SECOND_DERIVATIVE, _SECOND_DERIVATIVE_SCALE,
                   _SMOOTHING_TAPS, _SPEED_FLOOR, _TURN_LIMIT)
from weights_format import MAGIC, VERSION


@dataclass(frozen=True)
class ExportedEncoder:
    points: int
    width: int
    expansion: int
    kernel: int
    head_width: int
    basis: int
    dilations: tuple[int, ...]
    tensors: dict[str, np.ndarray]  # float32 copies of the fp16 values


def read_weights(path: Path) -> ExportedEncoder:
    data = path.read_bytes()
    if data[:4] != MAGIC:
        raise ValueError("not a KeyVox swipe encoder file")
    version, points, width, expansion, kernel, head_width, basis, blocks, count = struct.unpack_from("<9I", data, 4)
    if version != VERSION:
        raise ValueError(f"unsupported version {version}")
    offset = 4 + 9 * 4
    dilations = struct.unpack_from(f"<{blocks}I", data, offset)
    offset += 4 * blocks
    table = []
    for _ in range(count):
        (length,) = struct.unpack_from("<H", data, offset)
        name = data[offset + 2:offset + 2 + length].decode("ascii")
        offset += 2 + length
        (rank,) = struct.unpack_from("<B", data, offset)
        shape = struct.unpack_from(f"<{rank}I", data, offset + 1)
        offset += 1 + 4 * rank
        table.append((name, shape))
    tensors = {}
    for name, shape in table:
        size = int(np.prod(shape))
        tensors[name] = np.frombuffer(data, dtype="<f2", count=size, offset=offset).astype(np.float32).reshape(shape)
        offset += 2 * size
    return ExportedEncoder(points, width, expansion, kernel, head_width, basis, tuple(dilations), tensors)


def _hardswish(x: np.ndarray) -> np.ndarray:
    return x * np.clip(x + 3, 0, 6) / 6


def _sigmoid(x: np.ndarray) -> np.ndarray:
    return 1 / (1 + np.exp(-x))


def _log_sigmoid(x: np.ndarray) -> np.ndarray:
    return -np.logaddexp(0, -x)


def _features(xy: np.ndarray) -> np.ndarray:
    """[B, T, 2] to [B, 8, T]; matches `model.swipe_features`."""
    half = _SMOOTHING_TAPS // 2
    positions = xy.transpose(0, 2, 1)
    padded = np.concatenate([np.repeat(positions[:, :, :1], half, 2), positions,
                             np.repeat(positions[:, :, -1:], half, 2)], axis=2)
    length = positions.shape[2]

    def filtered(taps, scale):
        return sum(tap / scale * padded[:, :, j:j + length] for j, tap in enumerate(taps))

    velocity = filtered(_FIRST_DERIVATIVE, _FIRST_DERIVATIVE_SCALE)
    acceleration = filtered(_SECOND_DERIVATIVE, _SECOND_DERIVATIVE_SCALE)
    speed_squared = (velocity ** 2).sum(axis=1, keepdims=True)
    cross = velocity[:, :1] * acceleration[:, 1:] - velocity[:, 1:] * acceleration[:, :1]
    turn = np.clip(cross / (speed_squared + _SPEED_FLOOR), -_TURN_LIMIT, _TURN_LIMIT)
    return np.concatenate([positions, velocity, acceleration, np.sqrt(speed_squared), turn], axis=1)


def _convolve(x: np.ndarray, weight: np.ndarray, bias: np.ndarray, dilation: int = 1) -> np.ndarray:
    """Zero-padded 'same' convolution: x [B, C, T], weight [O, C, k]."""
    kernel = weight.shape[2]
    pad = dilation * (kernel - 1) // 2
    padded = np.pad(x, ((0, 0), (0, 0), (pad, pad)))
    length = x.shape[2]
    out = sum(np.einsum("oc,bct->bot", weight[:, :, j], padded[:, :, j * dilation:j * dilation + length])
              for j in range(kernel))
    return out + bias[None, :, None]


def _depthwise(x: np.ndarray, weight: np.ndarray, bias: np.ndarray, dilation: int) -> np.ndarray:
    kernel = weight.shape[1]
    pad = dilation * (kernel - 1) // 2
    padded = np.pad(x, ((0, 0), (0, 0), (pad, pad)))
    length = x.shape[2]
    out = sum(weight[None, :, j:j + 1] * padded[:, :, j * dilation:j * dilation + length] for j in range(kernel))
    return out + bias[None, :, None]


def _pointwise(x: np.ndarray, weight: np.ndarray, bias: np.ndarray) -> np.ndarray:
    return np.einsum("oc,bct->bot", weight, x) + bias[None, :, None]


def encode(encoder: ExportedEncoder, xy: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """[B, T, 2] swipes to coefficients [B, T / 2, basis^2] and gate logits [B, T / 2]."""
    w = encoder.tensors
    x = _features(xy.astype(np.float32))
    x = x * w["input.scale"][None, :, None] + w["input.shift"][None, :, None]
    x = _hardswish(_convolve(x, w["stem.weight"], w["stem.bias"]))
    for number, dilation in enumerate(encoder.dilations):
        p = f"block{number}."
        y = _depthwise(x, w[p + "depthwise.weight"], w[p + "depthwise.bias"], dilation)
        y = _pointwise(y, w[p + "expand.weight"], w[p + "expand.bias"])
        half = y.shape[1] // 2
        y = y[:, :half] * _sigmoid(y[:, half:])
        energy = np.sqrt((y ** 2).sum(axis=2, keepdims=True))
        normalized = energy / (energy.mean(axis=1, keepdims=True) + 1e-6)
        y = w[p + "response.gamma"][None, :, None] * (y * normalized) + w[p + "response.beta"][None, :, None] + y
        y = _pointwise(y, w[p + "project.weight"], w[p + "project.bias"])
        squeezed = np.maximum(y.mean(axis=2) @ w[p + "excite.reduce.weight"].T + w[p + "excite.reduce.bias"], 0)
        y = y * _sigmoid(squeezed @ w[p + "excite.expand.weight"].T + w[p + "excite.expand.bias"])[:, :, None]
        x = x + y
    pairs = x.reshape(x.shape[0], x.shape[1], -1, 2)
    x = np.einsum("ock,bctk->bot", w["adapter.weight"], pairs) + w["adapter.bias"][None, :, None]
    x = _hardswish(x).transpose(0, 2, 1)
    coefficients = x @ w["coefficients.weight"].T + w["coefficients.bias"]
    gate = (x @ w["gate.weight"].T + w["gate.bias"])[:, :, 0]
    return coefficients, gate


def key_basis(centers: np.ndarray, basis: int) -> np.ndarray:
    """[K, 2] key centers to [K, basis^2]; matches `model.key_basis`."""
    frequencies = np.arange(basis, dtype=np.float32) * np.pi
    return (np.cos(centers[:, :1] * frequencies)[:, :, None] * np.cos(centers[:, 1:2] * frequencies)[:, None, :]).reshape(len(centers), -1)


def emissions(encoder: ExportedEncoder, xy: np.ndarray, centers: np.ndarray) -> np.ndarray:
    """[B, T, 2] swipes and [K, 2] key centers to [B, T / 2, K + 1] log-probabilities, blank first."""
    coefficients, gate = encode(encoder, xy)
    logits = coefficients @ key_basis(centers, encoder.basis).T
    logits = logits - logits.max(axis=2, keepdims=True)
    keys = logits - np.log(np.exp(logits).sum(axis=2, keepdims=True)) + _log_sigmoid(gate)[:, :, None]
    return np.concatenate([_log_sigmoid(-gate)[:, :, None], keys], axis=2).astype(np.float32)

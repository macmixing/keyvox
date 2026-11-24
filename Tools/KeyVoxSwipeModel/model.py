"""The swipe encoder: a dilated temporal convolution network that reads a resampled swipe
and, for every output frame, scores each key of whatever layout it is given.

The layout reaches the network only through its key centers. Each frame predicts a small
set of 2-D cosine coefficients; a key's score is that cosine surface evaluated at the key's
center. A gate per frame decides how likely the frame is to emit a key at all, which is
the CTC blank's complement:

    log p(key k at frame t) = log_softmax_k(c_t . basis(k)) + log sigmoid(g_t)
    log p(blank at frame t) = log sigmoid(-g_t)

Index 0 of the emissions is the blank and index k + 1 is the layout's key k."""

import math
from dataclasses import asdict, dataclass

import torch
from torch import nn
from torch.nn import functional as F


@dataclass(frozen=True)
class EncoderConfig:
    width: int = 128
    expansion: int = 4
    kernel: int = 7
    dilations: tuple[int, ...] = (1, 2, 3, 5, 8)
    head_width: int = 256
    basis: int = 8
    dropout: float = 0.1

    def to_dict(self) -> dict:
        return asdict(self)

    @staticmethod
    def from_dict(values: dict) -> "EncoderConfig":
        return EncoderConfig(**{**values, "dilations": tuple(values["dilations"])})


FEATURES = 8
_SMOOTHING_TAPS = 7
# Savitzky-Golay (window 7, quadratic) first and second derivative taps.
_FIRST_DERIVATIVE = (-3.0, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0)
_FIRST_DERIVATIVE_SCALE = 28.0
_SECOND_DERIVATIVE = (5.0, 0.0, -3.0, -4.0, -3.0, 0.0, 5.0)
_SECOND_DERIVATIVE_SCALE = 42.0
_TURN_LIMIT = 2.0
_SPEED_FLOOR = 1e-6


def swipe_features(xy: torch.Tensor) -> torch.Tensor:
    """[B, T, 2] positions to [B, 8, T]: x, y, velocity, acceleration, speed, turn rate.

    Derivatives are per resampled point."""
    positions = xy.transpose(1, 2)
    padded = F.pad(positions, (_SMOOTHING_TAPS // 2, _SMOOTHING_TAPS // 2), mode="replicate")
    taps = positions.new_tensor([
        [_FIRST_DERIVATIVE],
        [_SECOND_DERIVATIVE],
    ]) / positions.new_tensor([[[_FIRST_DERIVATIVE_SCALE]], [[_SECOND_DERIVATIVE_SCALE]]])
    batch, _, length = positions.shape
    filtered = F.conv1d(padded.reshape(batch * 2, 1, -1), taps).reshape(batch, 2, 2, length)
    velocity, acceleration = filtered[:, :, 0], filtered[:, :, 1]
    speed_squared = velocity.square().sum(dim=1, keepdim=True)
    speed = speed_squared.sqrt()
    cross = velocity[:, :1] * acceleration[:, 1:] - velocity[:, 1:] * acceleration[:, :1]
    turn = (cross / (speed_squared + _SPEED_FLOOR)).clamp(-_TURN_LIMIT, _TURN_LIMIT)
    return torch.cat([positions, velocity, acceleration, speed, turn], dim=1)


def pointwise(conv: nn.Conv1d, x: torch.Tensor) -> torch.Tensor:
    """A kernel-size-1 convolution as a matrix product, which runs faster on the GPU."""
    return torch.einsum("oc,bct->bot", conv.weight.squeeze(2), x) + conv.bias.unsqueeze(1)


class GlobalResponseNorm(nn.Module):
    def __init__(self, channels: int) -> None:
        super().__init__()
        self.gamma = nn.Parameter(torch.zeros(1, channels, 1))
        self.beta = nn.Parameter(torch.zeros(1, channels, 1))

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        energy = x.norm(p=2, dim=2, keepdim=True)
        normalized = energy / (energy.mean(dim=1, keepdim=True) + 1e-6)
        return self.gamma * (x * normalized) + self.beta + x


class SqueezeExcite(nn.Module):
    REDUCTION = 8

    def __init__(self, channels: int) -> None:
        super().__init__()
        self.reduce = nn.Linear(channels, channels // self.REDUCTION)
        self.expand = nn.Linear(channels // self.REDUCTION, channels)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        weights = torch.sigmoid(self.expand(F.relu(self.reduce(x.mean(dim=2)))))
        return x * weights.unsqueeze(2)


class TemporalBlock(nn.Module):
    def __init__(self, config: EncoderConfig, dilation: int) -> None:
        super().__init__()
        width = config.width
        hidden = config.expansion * width
        self.depthwise = nn.Conv1d(
            width, width, config.kernel, dilation=dilation,
            padding=dilation * (config.kernel - 1) // 2, groups=width,
        )
        self.norm = nn.BatchNorm1d(width)
        self.expand = nn.Conv1d(width, hidden, 1)
        self.response = GlobalResponseNorm(hidden // 2)
        self.project = nn.Conv1d(hidden // 2, width, 1)
        self.excite = SqueezeExcite(width)
        self.dropout = nn.Dropout(config.dropout)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        y = self.norm(self.depthwise(x))
        y = F.glu(pointwise(self.expand, y), dim=1)
        y = self.excite(pointwise(self.project, self.response(y)))
        return x + self.dropout(y)


class SwipeEncoder(nn.Module):
    def __init__(self, config: EncoderConfig) -> None:
        super().__init__()
        self.config = config
        self.input_norm = nn.BatchNorm1d(FEATURES)
        self.stem = nn.Conv1d(FEATURES, config.width, config.kernel, padding=config.kernel // 2)
        self.stem_norm = nn.BatchNorm1d(config.width)
        self.blocks = nn.ModuleList(TemporalBlock(config, dilation) for dilation in config.dilations)
        self.adapter = nn.Conv1d(config.width, config.head_width, 2, stride=2)
        self.adapter_norm = nn.BatchNorm1d(config.head_width)
        self.coefficients = nn.Linear(config.head_width, config.basis * config.basis)
        self.gate = nn.Linear(config.head_width, 1)
        for head in (self.coefficients, self.gate):
            nn.init.zeros_(head.weight)
            nn.init.zeros_(head.bias)

    def forward(self, xy: torch.Tensor) -> tuple[torch.Tensor, torch.Tensor]:
        """[B, T, 2] to coefficients [B, T / 2, basis^2] and gate logits [B, T / 2]."""
        x = F.hardswish(self.stem_norm(self.stem(self.input_norm(swipe_features(xy)))))
        for block in self.blocks:
            x = block(x)
        x = F.hardswish(self.adapter_norm(self.adapter(x))).transpose(1, 2)
        return self.coefficients(x), self.gate(x).squeeze(2)


def key_basis(centers: torch.Tensor, basis: int) -> torch.Tensor:
    """[..., K, 2] key centers to [..., K, basis^2] cosine values, u major then v."""
    frequencies = torch.arange(basis, device=centers.device, dtype=centers.dtype) * math.pi
    along_x = torch.cos(centers[..., 0:1] * frequencies)
    along_y = torch.cos(centers[..., 1:2] * frequencies)
    return (along_x.unsqueeze(-1) * along_y.unsqueeze(-2)).flatten(-2)


def log_emissions(
    coefficients: torch.Tensor, gate: torch.Tensor, basis: torch.Tensor, key_mask: torch.Tensor
) -> torch.Tensor:
    """Coefficients [B, T, M], gate [B, T], basis [B, K, M], mask [B, K] (True for real keys)
    to log-probabilities [B, T, K + 1] with the blank at index 0."""
    logits = torch.einsum("btm,bkm->btk", coefficients, basis)
    logits = logits.masked_fill(~key_mask.unsqueeze(1), float("-inf"))
    keys = F.log_softmax(logits, dim=2) + F.logsigmoid(gate).unsqueeze(2)
    blank = F.logsigmoid(-gate).unsqueeze(2)
    return torch.cat([blank, keys], dim=2)

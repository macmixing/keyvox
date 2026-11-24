"""The optional fixed-layout decoder: a small feedforward sequential memory network that
reads a frozen encoder's per-frame outputs and corrects its emissions.

Each frame's input is the encoder's log-emissions, its cosine coefficients, and its gate
probability. Every block projects to a narrow memory, mixes it with a symmetric window of
neighbouring frames, adds the previous block's memory, and projects back with a residual.
The head's output is added to the encoder's log-emissions and renormalized, and starts at
zero, so an untrained decoder reproduces the encoder exactly."""

from dataclasses import asdict, dataclass

import torch
from torch import nn
from torch.nn import functional as F


@dataclass(frozen=True)
class DecoderConfig:
    symbols: int = 27
    coefficients: int = 64
    width: int = 256
    bottleneck: int = 64
    blocks: int = 8
    memory: int = 7
    dropout: float = 0.05

    @property
    def inputs(self) -> int:
        return self.symbols + self.coefficients + 1

    def to_dict(self) -> dict:
        return asdict(self)


class MemoryBlock(nn.Module):
    def __init__(self, config: DecoderConfig) -> None:
        super().__init__()
        self.down = nn.Linear(config.width, config.bottleneck, bias=False)
        self.memory = nn.Conv1d(config.bottleneck, config.bottleneck, 2 * config.memory + 1,
                                padding=config.memory, groups=config.bottleneck, bias=False)
        self.up = nn.Linear(config.bottleneck, config.width)
        self.dropout = nn.Dropout(config.dropout)

    def forward(self, x: torch.Tensor, previous: torch.Tensor | None) -> tuple[torch.Tensor, torch.Tensor]:
        narrow = self.down(x)
        memory = narrow + self.memory(narrow.transpose(1, 2)).transpose(1, 2)
        if previous is not None:
            memory = memory + previous
        return x + self.dropout(F.relu(self.up(memory))), memory


class SwipeDecoder(nn.Module):
    def __init__(self, config: DecoderConfig) -> None:
        super().__init__()
        self.config = config
        self.project = nn.Linear(config.inputs, config.width)
        self.blocks = nn.ModuleList(MemoryBlock(config) for _ in range(config.blocks))
        self.head = nn.Linear(config.width, config.symbols)
        nn.init.zeros_(self.head.weight)
        nn.init.zeros_(self.head.bias)

    def forward(self, frames: torch.Tensor) -> torch.Tensor:
        """[B, T, inputs] encoder outputs (log-emissions first) to [B, T, symbols] log-probabilities."""
        x = F.relu(self.project(frames))
        memory = None
        for block in self.blocks:
            x, memory = block(x, memory)
        emissions = frames[..., : self.config.symbols]
        return F.log_softmax(emissions + self.head(x), dim=2)

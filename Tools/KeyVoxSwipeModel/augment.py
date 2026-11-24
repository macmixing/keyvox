"""Training augmentation that moves a swipe and its keyboard together, so the encoder
learns how a path relates to the keys it is given rather than one fixed keyboard.

Every geometric step is applied identically to the swipe [B, T, 2] and its key centers
[B, K, 2], in order: vertical squeeze, horizontal squeeze, shear, mirror flips, rotation
about the swipe's centroid (kept only when everything stays inside the unit square), and a
shift to a random spot where everything fits. A sample is geometrically augmented with
`probability`. Separately, a swipe is played backwards with `reverse_probability`, and its
target word must then be reversed too."""

import math
from dataclasses import dataclass

import torch


@dataclass(frozen=True)
class AugmentConfig:
    probability: float = 1.0
    y_scale: tuple[float, float] = (0.75, 1.0)
    x_scale: tuple[float, float] = (0.85, 1.0)
    shear: float = 0.05
    flip_probability: float = 0.5
    reverse_probability: float = 0.1


def _uniform(batch: int, low: float, high: float, like: torch.Tensor) -> torch.Tensor:
    return low + (high - low) * torch.rand(batch, 1, device=like.device, dtype=like.dtype)


def _inside(points: torch.Tensor, valid: torch.Tensor) -> torch.Tensor:
    within = ((points >= 0) & (points <= 1)).all(dim=2) | ~valid
    return within.all(dim=1)


def augment_geometry(
    xy: torch.Tensor, keys: torch.Tensor, key_mask: torch.Tensor, config: AugmentConfig
) -> tuple[torch.Tensor, torch.Tensor]:
    batch, length, _ = xy.shape
    points = torch.cat([xy, keys], dim=1)
    valid = torch.cat([torch.ones(batch, length, dtype=torch.bool, device=xy.device), key_mask], dim=1)
    chosen = torch.rand(batch, 1, device=xy.device) < config.probability
    identity = torch.ones(batch, 1, device=xy.device, dtype=xy.dtype)

    x, y = points[..., 0], points[..., 1]
    y = 0.5 + (y - 0.5) * torch.where(chosen, _uniform(batch, *config.y_scale, xy), identity)
    x = 0.5 + (x - 0.5) * torch.where(chosen, _uniform(batch, *config.x_scale, xy), identity)
    x = x + torch.where(chosen, _uniform(batch, -config.shear, config.shear, xy), 0 * identity) * (y - 0.5)
    y = y + torch.where(chosen, _uniform(batch, -config.shear, config.shear, xy), 0 * identity) * (x - 0.5)
    flip_x = chosen & (torch.rand(batch, 1, device=xy.device) < config.flip_probability)
    flip_y = chosen & (torch.rand(batch, 1, device=xy.device) < config.flip_probability)
    x = torch.where(flip_x, 1 - x, x)
    y = torch.where(flip_y, 1 - y, y)
    points = torch.stack([x, y], dim=2)

    angle = _uniform(batch, 0.0, 2 * math.pi, xy)
    cosine, sine = torch.cos(angle), torch.sin(angle)
    centroid = points[:, :length].mean(dim=1, keepdim=True)
    offset = points - centroid
    rotated = torch.stack(
        [cosine * offset[..., 0] - sine * offset[..., 1], sine * offset[..., 0] + cosine * offset[..., 1]],
        dim=2,
    ) + centroid
    keep_rotation = chosen.squeeze(1) & _inside(rotated, valid)
    points = torch.where(keep_rotation[:, None, None], rotated, points)

    infinity = torch.full_like(points, math.inf)
    low = torch.where(valid.unsqueeze(2), points, infinity).amin(dim=1)
    high = torch.where(valid.unsqueeze(2), points, -infinity).amax(dim=1)
    room_low, room_high = -low, 1 - high
    fraction = torch.rand(batch, 2, device=xy.device, dtype=xy.dtype)
    shift = torch.where(room_high >= room_low, room_low + fraction * (room_high - room_low), 0 * room_low)
    points = points + torch.where(chosen, shift, 0 * shift).unsqueeze(1)
    return points[:, :length], points[:, length:]


def reverse_choice(batch: int, config: AugmentConfig, device: torch.device) -> torch.Tensor:
    return torch.rand(batch, device=device) < config.reverse_probability


def reverse_swipes(
    xy: torch.Tensor, targets: torch.Tensor, lengths: torch.Tensor, chosen: torch.Tensor
) -> tuple[torch.Tensor, torch.Tensor]:
    """Plays chosen swipes backwards and reverses their padded targets within their length."""
    positions = torch.arange(targets.shape[1], device=targets.device).unsqueeze(0)
    mirrored = (lengths.unsqueeze(1) - 1 - positions).clamp(min=0)
    reversed_targets = torch.where(positions < lengths.unsqueeze(1), targets.gather(1, mirrored), targets)
    return (
        torch.where(chosen[:, None, None], xy.flip(1), xy),
        torch.where(chosen.unsqueeze(1), reversed_targets, targets),
    )

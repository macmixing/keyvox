"""The listwise ranking objective shared by decoder training and encoder fine-tuning:
rank a swipe's true word above the hard negatives the encoder confuses it with, each
scored exactly as at decode time (`scoring.py`)."""

import math

import numpy as np
import torch
from torch.nn import functional as F

from lexicon import Lexicon
from scoring import Scoring
from words import key_path

NEGATIVES = 16
CTC_WEIGHT = 0.3


def lexicon_paths(lexicon: Lexicon, key_index: dict[str, int], frames: int) -> tuple[np.ndarray, np.ndarray]:
    """Every form's key path as CTC labels (key + 1), zero padded, and its length (0 when
    the form cannot be decoded in `frames` frames)."""
    paths = np.zeros((len(lexicon.forms), frames), dtype=np.int64)
    lengths = np.zeros(len(lexicon.forms), dtype=np.int64)
    for number, form in enumerate(lexicon.forms):
        path = key_path(form, key_index)
        if path and len(path) <= frames:
            paths[number, : len(path)] = np.array(path) + 1
            lengths[number] = len(path)
    return paths, lengths


def hard_negatives(candidates, scores: np.ndarray, targets: np.ndarray, count: int) -> np.ndarray:
    """[N, count] the best-scoring candidate forms that are not the target, -1 padded."""
    swipes = len(candidates.start) - 1
    group = np.repeat(np.arange(swipes), np.diff(candidates.start))
    order = np.lexsort((-scores, group))
    group, forms = group[order], candidates.form[order]
    wrong = forms != targets[group]
    group, forms = group[wrong], forms[wrong]
    first = np.searchsorted(group, np.arange(swipes))
    position = np.arange(len(group)) - first[group]
    keep = position < count
    negatives = np.full((swipes, count), -1, dtype=np.int32)
    negatives[group[keep], position[keep]] = forms[keep]
    return negatives


def word_scores(emissions, forms, paths, lengths, frequency, scoring: Scoring):
    """Decode-time scores of `forms` [B, M] (-1 for none) under emissions [B, T, S]."""
    batch, options = forms.shape
    valid = forms >= 0
    safe = forms.clamp(min=0)
    on_cpu = safe.cpu()
    labels = paths[on_cpu].reshape(batch * options, -1)
    label_lengths = lengths[on_cpu].reshape(-1).clamp(min=1)
    repeated = emissions.unsqueeze(1).expand(-1, options, -1, -1).reshape(batch * options, *emissions.shape[1:])
    frame_count = torch.full((batch * options,), emissions.shape[1], dtype=torch.long)
    nll = F.ctc_loss(repeated.transpose(0, 1).cpu(), labels, frame_count, label_lengths,
                     blank=0, reduction="none").to(emissions.device).reshape(batch, options)
    length = label_lengths.reshape(batch, options).to(emissions.device).float()
    score = -nll / length.pow(scoring.gamma) + scoring.frequency_weight * frequency[safe] + scoring.length_bonus * length
    return score.masked_fill(~valid, -math.inf), nll, length


def ranking_loss(emissions, options, paths, lengths, frequency, scoring: Scoring) -> torch.Tensor:
    """Listwise cross-entropy putting `options[:, 0]` (the true word) first, plus the true
    word's CTC loss per key weighted by CTC_WEIGHT."""
    score, nll, length = word_scores(emissions, options, paths, lengths, frequency, scoring)
    rank = F.cross_entropy(score, torch.zeros(len(options), dtype=torch.long, device=emissions.device))
    return rank + CTC_WEIGHT * (nll[:, 0] / length[:, 0]).mean()


def ranking_options(candidates, scores: np.ndarray, targets: np.ndarray, path_lengths: np.ndarray
                    ) -> tuple[np.ndarray, np.ndarray]:
    """Per swipe, the true word then its hard negatives [N, 1 + NEGATIVES], and which swipes
    can be trained (true word in the lexicon with a decodable key path)."""
    negatives = hard_negatives(candidates, scores, targets, NEGATIVES)
    keep = (targets >= 0) & (path_lengths[np.maximum(targets, 0)] > 0)
    return np.concatenate([targets[:, None], negatives], axis=1).astype(np.int64), keep

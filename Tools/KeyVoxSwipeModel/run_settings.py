"""Reads a run's encoder settings: an encoder run's own, or a decoder run's encoder's."""

import json
from pathlib import Path

KEEP_DOUBLES = "keep_doubles"


def encoder_settings(models: Path, run: str) -> dict:
    settings = json.loads((models / run / "settings.json").read_text())
    if "encoder_run" in settings:
        return encoder_settings(models, settings["encoder_run"])
    return settings


def keeps_doubles(settings: dict) -> bool:
    """Whether the run's key paths keep repeated keys (runs from before the option collapse them)."""
    return bool(settings.get(KEEP_DOUBLES, False))

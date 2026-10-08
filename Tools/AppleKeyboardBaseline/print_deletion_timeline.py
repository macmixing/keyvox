"""Prints a deletion timeline the baseline host recorded while a keyboard's delete key was
held: each change's time since the first, the gap since the one before, and what it removed.

    python3 print_deletion_timeline.py --simulator <simulator-udid> [--save <timeline.json>]
    python3 print_deletion_timeline.py <timeline.json>
"""

import argparse
import json
import subprocess
from pathlib import Path

HOST_BUNDLE_ID = "org.keyvox.baseline.host"


def recorded_timeline(udid: str) -> list[dict]:
    container = subprocess.check_output(
        ["xcrun", "simctl", "get_app_container", udid, HOST_BUNDLE_ID, "data"], text=True
    ).strip()
    return json.loads((Path(container) / "Documents" / "deletion-timeline.json").read_text())


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("timeline", type=Path, nargs="?")
    parser.add_argument("--simulator", help="read the timeline from the host app on this simulator")
    parser.add_argument("--save", type=Path, help="also write the timeline to this file")
    arguments = parser.parse_args()
    if (arguments.timeline is None) == (arguments.simulator is None):
        parser.error("pass a timeline file or --simulator")

    entries = recorded_timeline(arguments.simulator) if arguments.simulator else json.loads(arguments.timeline.read_text())
    if arguments.save:
        arguments.save.write_text(json.dumps(entries))

    first = previous = None
    for before, after in zip(entries, entries[1:]):
        time = after["time"]
        first = time if first is None else first
        gap = "" if previous is None else f"{(time - previous) * 1000:.0f} ms"
        if after["text"] == before["text"][:len(after["text"])]:
            change = f"removed {before['text'][len(after['text']):]!r}"
        else:
            change = f"changed {before['text'][-20:]!r} to {after['text'][-20:]!r}"
        print(f"{time - first:7.3f} s {gap:>7}  {change}")
        previous = time
    removed = len(entries[0]["text"]) - len(entries[-1]["text"])
    print(f"{len(entries) - 1} changes, {removed} characters removed")


if __name__ == "__main__":
    main()

"""Types the words ITE typists copied with autocorrection off with the typo simulator, with another
seed than the calibration's, measures its mistakes the way `measure_ite_typing.py` measured
theirs, and prints and writes to `<data_dir>/work/simulation/comparison.json`, for ITE and the
simulator:
- each kind's share of a typo, events per mistyped word, against the typos typists left for the
  logged keyboards to autocorrect, and the share of mistyped words with a second mistake;
- the share of words of each length typed with a mistake, against the words typed with
  autocorrection off;
to show which mistakes the simulator makes too often or too rarely."""

import argparse
import json
from pathlib import Path

from calibrate_typo_simulator import mistyped_shares, shares
from ite_copied_typing import copied_sentences
from letter_layout import LetterLayout
from paths import DataPaths
from typo_kinds import TypoCounts
from typo_simulator import TypoSimulator

SEED = 20261124


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("data_dir", type=Path)
    data_dir = parser.parse_args().data_dir
    paths = DataPaths(data_dir)
    measurements = json.loads(paths.typing_measurements.read_text(encoding="utf-8"))
    calibration = json.loads(paths.typo_calibration.read_text(encoding="utf-8"))
    layout = LetterLayout.for_language(measurements["language"])
    simulator = TypoSimulator(layout, measurements, calibration, SEED)

    counts = TypoCounts()
    for _, intended, _ in copied_sentences(data_dir):
        for word in intended:
            counts.add(word, simulator.type_word(word), layout)
    simulated = counts.summary()
    autocorrected = measurements["autocorrected_typos"]
    ite_by_length, _ = mistyped_shares(measurements["typos"])
    simulated_by_length, simulated_second = mistyped_shares(simulated)
    _, autocorrected_second = mistyped_shares(autocorrected)
    ite_shares, simulated_shares = shares(autocorrected), shares(simulated)

    comparison = {
        "kind_shares": {kind: {"ite": ite_shares[kind], "simulated": simulated_shares[kind]}
                        for kind in ite_shares},
        "second_mistake_share": {"ite": autocorrected_second, "simulated": simulated_second},
        "mistyped_by_length": {str(length): {"ite": ite_by_length[length],
                                             "simulated": simulated_by_length[length]}
                               for length in ite_by_length},
    }
    (paths.simulation / "comparison.json").write_text(json.dumps(comparison, indent=2),
                                                     encoding="utf-8")
    print(f"{'events per typo':40} {'ITE':>9} {'simulated':>9} {'ratio':>6}")
    for kind, values in comparison["kind_shares"].items():
        ratio = values["simulated"] / values["ite"] if values["ite"] else float("nan")
        print(f"{kind:40} {values['ite']:9.5f} {values['simulated']:9.5f} {ratio:6.2f}")
    print(f"mistyped words with a second mistake: ITE {autocorrected_second:.4f}, "
          f"simulated {simulated_second:.4f}")
    for length, values in comparison["mistyped_by_length"].items():
        print(f"{length}{'+' if length == '12' else ''} letters mistyped: ITE "
              f"{values['ite']:.4f}, simulated {values['simulated']:.4f}")


if __name__ == "__main__":
    main()

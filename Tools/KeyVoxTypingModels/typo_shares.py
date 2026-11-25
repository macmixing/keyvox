"""The shares the typo simulator is calibrated to and compared on, from a `TypoCounts.summary()`:
how many words are mistyped, how many of those have a second mistake, and what a typo is made
of."""


def mistyped_shares(summary):
    """The share of words with a mistake by length, and the share of those with a second."""
    by_length = {}
    mistyped = second = 0
    for length, counts in summary["words_by_length"].items():
        total = sum(counts.values())
        by_length[int(length)] = (counts["1"] + counts["2"]) / total if total else 0.0
        mistyped += counts["1"] + counts["2"]
        second += counts["2"]
    return by_length, second / mistyped


def shares(summary):
    """Each kind's events per mistyped word."""
    mistyped = summary["words"]["mistyped"]
    return {kind: summary["events"].get(kind, 0) / mistyped for kind in summary["rates"]}

"""Writes the emoji data the KeyVox keyboards bundle: the emoji the system emoji keyboard shows,
in its categories and order, and the emoji its Frequently Used section starts with, both as
recorded by watching it (Tools/AppleKeyboardBaseline, EmojiOrderProbeTests and
EmojiKeyboardProbeTests); and each emoji's name and skin-tone variants from Unicode's
emoji-test.txt.

A skin-tone variant, one that carries an emoji modifier (U+1F3FB to U+1F3FF), belongs to the
emoji whose name is the variant's name without its skin tones, which the Component group names
("kiss: woman, man, light skin tone" varies "kiss: woman, man"), since two-tone variants do not
always follow the emoji they vary; otherwise to the last emoji before it, as for
"kiss: person, person, light skin tone, medium skin tone" right after the variants of "kiss".
Emoji are matched without variation selectors, which the system keyboard adds to some it shows.

Output, the catalog, one line each:
    @<category id>                    a category, such as @smileys-people
    <emoji>\t<name>\t<variants>       an emoji as the system keyboard types it, its Unicode name,
                                      and its skin-tone variants separated by spaces
and the starters, one emoji a line, in the order the section shows them.

Usage: python3 -I write_emoji_catalog.py <emoji-test.txt> <order.json> <layout.json> <catalog> <starters>
"""

import json
import re
import sys
from collections import Counter

LINE = re.compile(r"^(?P<points>[0-9A-F ]+?)\s*;\s*(?P<status>[\w-]+)\s*#\s*\S+\s+E\d+\.\d+\s+(?P<name>.+)$")
MODIFIERS = range(0x1F3FB, 0x1F3FF + 1)
COMPONENT_GROUP = "Component"
FREQUENTLY_USED = "FREQUENTLY USED"
# A section's title starts this far after its first column (EmojiKeyboardProbeTests).
TITLE_INSET = 2


def key(emoji):
    return emoji.replace("️", "")


def category_id(title):
    return re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")


def read_lines(path):
    """Every fully-qualified emoji and component as (group name, code points, name), in file
    order."""
    group = None
    for raw in open(path, encoding="utf-8"):
        line = raw.rstrip("\n")
        if line.startswith("# group: "):
            group = line[len("# group: "):]
            continue
        match = LINE.match(line)
        if match and match["status"] in ("fully-qualified", "component") and group is not None:
            yield group, [int(point, 16) for point in match["points"].split()], match["name"]


def without_skin_tones(name, tone_names):
    """The name a skin-tone variant's emoji has without skin tones."""
    base, separator, details = name.partition(": ")
    kept = [detail for detail in details.split(", ") if detail not in tone_names] if separator else []
    return f"{base}: {', '.join(kept)}" if kept else base


def read_unicode(path):
    """Each emoji without skin tones, by its key, with its name and skin-tone variants."""
    lines = list(read_lines(path))
    tone_names = {
        name for group, points, name in lines
        if group == COMPONENT_GROUP and len(points) == 1 and points[0] in MODIFIERS
    }
    if len(tone_names) != len(MODIFIERS):
        raise SystemExit(f"expected a name for each skin tone, found {sorted(tone_names)}")
    by_name = {}
    entries = {}
    last = None
    for group, points, name in lines:
        if group == COMPONENT_GROUP:
            continue
        emoji = "".join(map(chr, points))
        if any(point in MODIFIERS for point in points):
            base = by_name.get(without_skin_tones(name, tone_names)) or last
            if base is None:
                raise SystemExit(f"skin-tone variant without its emoji: {name}")
            base["variants"].append(emoji)
        else:
            last = {"name": name, "variants": []}
            by_name[name] = last
            entries[key(emoji)] = last
    return entries


def read_starters(layout_path):
    """The emoji the Frequently Used section showed on the untouched keyboard, column by column."""
    screens = {screen["name"]: screen["elements"] for screen in json.load(open(layout_path, encoding="utf-8"))}
    elements = screens["emoji"]
    titles = {element["label"]: element["frame"][0] for element in elements if element["label"].isupper()}
    following = min(x for title, x in titles.items() if title != FREQUENTLY_USED and x > titles[FREQUENTLY_USED]) - TITLE_INSET
    cells = {
        (element["frame"][0], element["frame"][1]): element["label"]
        for element in elements
        if element["type"] == "20" and element["identifier"] == element["label"] and element["frame"][2] < 40
        and element["frame"][0] < following
    }
    return [cells[position] for position in sorted(cells)]


def main():
    unicode_path, order_path, layout_path, catalog_path, starters_path = sys.argv[1:6]
    unicode = read_unicode(unicode_path)
    sections = [section for section in json.load(open(order_path, encoding="utf-8")) if section["title"] != FREQUENTLY_USED]
    unknown = [emoji for section in sections for emoji in section["emoji"] if key(emoji) not in unicode]
    if unknown:
        raise SystemExit(f"emoji the system keyboard shows that Unicode does not list: {''.join(unknown)}")
    with open(catalog_path, "w", encoding="utf-8") as file:
        for section in sections:
            file.write(f"@{category_id(section['title'])}\n")
            for emoji in section["emoji"]:
                entry = unicode[key(emoji)]
                file.write(f"{emoji}\t{entry['name']}\t{' '.join(entry['variants'])}\n")
    starters = read_starters(layout_path)
    with open(starters_path, "w", encoding="utf-8") as file:
        file.writelines(f"{emoji}\n" for emoji in starters)
    counts = Counter(len(unicode[key(emoji)]["variants"]) for section in sections for emoji in section["emoji"])
    total = sum(len(section["emoji"]) for section in sections)
    print(f"{total} emoji in {len(sections)} categories; skin-tone variants per emoji: {dict(sorted(counts.items()))}; {len(starters)} starters")


if __name__ == "__main__":
    main()

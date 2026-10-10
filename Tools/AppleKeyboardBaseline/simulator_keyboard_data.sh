#!/usr/bin/env bash
# Saves or restores what the system keyboard has learned on a simulator: the words it learned
# from typing, the corrections the user undid, and its typing statistics, all kept in the
# simulator's Library/Keyboard. Every replay teaches the keyboard the words it leaves in the
# text, so restoring a copy saved beforehand keeps one measurement from changing the next.
#
#   simulator_keyboard_data.sh save <simulator-udid> <folder>
#   simulator_keyboard_data.sh restore <simulator-udid> <folder>
#
# The keyboard keeps what it learns in memory and writes it out from time to time, so restoring
# stops its process (kbd) first, without letting it write, and again after the files are back,
# in case it restarted in between. The process starts again on its own when a keyboard is
# needed. Close the app being typed in before restoring.
set -euo pipefail

usage() {
  echo "usage: $0 save|restore <simulator-udid> <folder>" >&2
  exit 1
}

[[ $# -eq 3 ]] || usage
ACTION="$1"
SIMULATOR="$2"
FOLDER="$3"
KEYBOARD_DIR="$HOME/Library/Developer/CoreSimulator/Devices/$SIMULATOR/data/Library/Keyboard"
[[ -d "$KEYBOARD_DIR" ]] || { echo "no keyboard data for simulator $SIMULATOR" >&2; exit 1; }

stop_keyboard_process() {
  local pid
  pid="$(xcrun simctl spawn "$SIMULATOR" launchctl list | awk '$3 == "com.apple.TextInput.kbd" { print $1 }')"
  if [[ "$pid" =~ ^[0-9]+$ ]]; then
    kill -KILL "$pid"
  fi
}

case "$ACTION" in
  save)
    mkdir -p "$FOLDER"
    rsync -a --delete "$KEYBOARD_DIR/" "$FOLDER/"
    echo "saved $KEYBOARD_DIR to $FOLDER"
    ;;
  restore)
    [[ -d "$FOLDER" ]] || { echo "no saved keyboard data at $FOLDER" >&2; exit 1; }
    stop_keyboard_process
    rsync -a --delete "$FOLDER/" "$KEYBOARD_DIR/"
    stop_keyboard_process
    # A database's -shm file is an index rebuilt from its journal whenever the database opens,
    # so whatever opens it next may already have rewritten it.
    diff -rq --exclude='*-shm' "$FOLDER" "$KEYBOARD_DIR" >/dev/null \
      || { echo "restored files differ from $FOLDER" >&2; exit 1; }
    echo "restored $KEYBOARD_DIR from $FOLDER"
    ;;
  *)
    usage
    ;;
esac

#!/usr/bin/env bash
set -euo pipefail

# Research helper for paste-fallback signal discovery.
# Runs repeated trials, triggers paste (cmdv/menu), and captures AX metrics
# using Tools/ExploreAX.swift at configurable time offsets.

APP_NAME="Slack"
MODE="cmdv"            # cmdv | menu | none
TRIALS=3
ESCAPE_FIRST=1
MAX_DEPTH=20
MAX_NODES=45000
DELAYS=(0.02 0.05 0.10 0.20 0.40 0.80 1.20 2.00)
OUT_DIR="/tmp/paste-signal-probe"

usage() {
  cat <<'EOF'
Usage:
  Tools/ExplorePasteSignal.sh [options]

Options:
  --app <name>            App name to activate (default: Slack)
  --mode <cmdv|menu|none> Trigger mode per trial (default: cmdv)
  --trials <n>            Number of trials (default: 3)
  --delays "<list>"       Space-separated delay list in seconds
  --no-escape-first       Do not send ESC before trigger
  --max-depth <n>         ExploreAX max depth (default: 20)
  --max-nodes <n>         ExploreAX max nodes (default: 45000)
  --out-dir <path>        Output directory (default: /tmp/paste-signal-probe)
  --help                  Show this message

Output:
  Prints TSV rows and writes raw dumps + summary TSV under out-dir.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app) APP_NAME="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --trials) TRIALS="$2"; shift 2 ;;
    --delays)
      IFS=' ' read -r -a DELAYS <<< "$2"
      shift 2
      ;;
    --no-escape-first) ESCAPE_FIRST=0; shift ;;
    --max-depth) MAX_DEPTH="$2"; shift 2 ;;
    --max-nodes) MAX_NODES="$2"; shift 2 ;;
    --out-dir) OUT_DIR="$2"; shift 2 ;;
    --help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ "$MODE" != "cmdv" && "$MODE" != "menu" && "$MODE" != "none" ]]; then
  echo "Invalid --mode: $MODE" >&2
  exit 2
fi

mkdir -p "$OUT_DIR"
SUMMARY="$OUT_DIR/summary_$(date +%Y%m%d_%H%M%S).tsv"

print_header() {
  cat <<'EOF'
trial	mode	delay	token	focused_element	paste_menu_enabled	global_strict	global_loose	focused_machine_count	composer_count	undo_title	undo_enabled	paste_title	paste_enabled	token_visible_count	dump_path
EOF
}

extract_field() {
  local line="$1"
  local key="$2"
  awk -F'|' -v want="$key" '
    {
      for (i = 1; i <= NF; i++) {
        split($i, kv, "=")
        if (kv[1] == want) {
          print substr($i, length(want) + 2)
          exit
        }
      }
    }' <<< "$line"
}

trigger_mode() {
  local app="$1"
  local mode="$2"

  osascript -e "tell application \"$app\" to activate" -e "delay 0.25"
  if [[ "$ESCAPE_FIRST" -eq 1 ]]; then
    osascript -e 'tell application "System Events" to key code 53' -e 'delay 0.06'
  fi

  case "$mode" in
    cmdv)
      osascript -e 'tell application "System Events" to keystroke "v" using command down'
      ;;
    menu)
      osascript -e "tell application \"System Events\" to tell process \"$app\" to click menu item \"Paste\" of menu 1 of menu bar item \"Edit\" of menu bar 1"
      ;;
    none)
      ;;
  esac
}

print_header | tee "$SUMMARY" >/dev/null

for ((trial = 1; trial <= TRIALS; trial++)); do
  token="KVX_SIG_${MODE}_${trial}_$(date +%s)"
  printf '%s' "$token" | pbcopy

  trigger_mode "$APP_NAME" "$MODE"

  for delay in "${DELAYS[@]}"; do
    sleep "$delay"
    dump_path="$OUT_DIR/trial${trial}_${MODE}_${delay}.txt"
    swift Tools/ExploreAX.swift \
      --max-depth "$MAX_DEPTH" \
      --max-nodes "$MAX_NODES" \
      --all-candidates \
      --machine > "$dump_path"

    focused_element=$(rg -n '^Focused element:' "$dump_path" | head -n1 | sed 's/^[0-9]*://; s/^Focused element: //')
    paste_menu_enabled=$(rg -n '^Paste Menu Enabled:' "$dump_path" | head -n1 | sed 's/^[0-9]*://; s/^Paste Menu Enabled: //')
    global_strict=$(rg -n '^Global Strict Text Candidates:' "$dump_path" | awk -F': ' 'NR==1{print $2}')
    global_loose=$(rg -n '^Global Loose Writable Candidates:' "$dump_path" | awk -F': ' 'NR==1{print $2}')
    focused_machine_count=$(rg -c '^MACHINE\|.*focused=true' "$dump_path" || true)
    composer_count=$(rg -c 'desc=composer' "$dump_path" || true)
    token_visible_count=$(rg -c "$token" "$dump_path" || true)

    undo_line=$(rg '^MACHINE\|.*id=undo:' "$dump_path" | head -n1 || true)
    paste_line=$(rg '^MACHINE\|.*id=paste:' "$dump_path" | head -n1 || true)
    undo_title=$(extract_field "${undo_line:-}" "title")
    undo_enabled=$(extract_field "${undo_line:-}" "enabled")
    paste_title=$(extract_field "${paste_line:-}" "title")
    paste_enabled=$(extract_field "${paste_line:-}" "enabled")

    echo -e "${trial}\t${MODE}\t${delay}\t${token}\t${focused_element:-<none>}\t${paste_menu_enabled:-<nil>}\t${global_strict:-<nil>}\t${global_loose:-<nil>}\t${focused_machine_count:-0}\t${composer_count:-0}\t${undo_title:-<nil>}\t${undo_enabled:-<nil>}\t${paste_title:-<nil>}\t${paste_enabled:-<nil>}\t${token_visible_count:-0}\t${dump_path}" | tee -a "$SUMMARY" >/dev/null
  done
done

echo "Wrote summary: $SUMMARY"

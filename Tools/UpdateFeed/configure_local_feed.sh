#!/usr/bin/env bash
set -euo pipefail

OVERRIDE_DIR="$HOME/Library/Application Support/KeyVox"
OVERRIDE_FILE="$OVERRIDE_DIR/update-feed.override.json"

print_usage() {
  cat <<USAGE
Usage:
  configure_local_feed.sh set <owner> <repo>
  configure_local_feed.sh clear
  configure_local_feed.sh show

Examples:
  configure_local_feed.sh set macmixing keyvoxghost
  configure_local_feed.sh clear
  configure_local_feed.sh show
USAGE
}

validate_slug() {
  local value="$1"
  if [[ ! "$value" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "Invalid value: '$value'. Allowed: letters, numbers, dot, underscore, dash." >&2
    exit 1
  fi
}

cmd="${1:-}"

case "$cmd" in
  set)
    owner="${2:-}"
    repo="${3:-}"

    if [[ -z "$owner" || -z "$repo" ]]; then
      print_usage
      exit 1
    fi

    validate_slug "$owner"
    validate_slug "$repo"

    mkdir -p "$OVERRIDE_DIR"
    cat > "$OVERRIDE_FILE" <<JSON
{
  "owner": "$owner",
  "repo": "$repo"
}
JSON

    echo "Local update feed override written to: $OVERRIDE_FILE"
    ;;
  clear)
    rm -f "$OVERRIDE_FILE"
    echo "Local update feed override cleared."
    ;;
  show)
    if [[ -f "$OVERRIDE_FILE" ]]; then
      echo "Local update feed override file: $OVERRIDE_FILE"
      cat "$OVERRIDE_FILE"
    else
      echo "No local update feed override file found at: $OVERRIDE_FILE"
    fi
    ;;
  *)
    print_usage
    exit 1
    ;;
esac

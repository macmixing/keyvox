#!/bin/bash
set -euo pipefail

# KeyVox In-Place Auto-Updater
# Arguments:
# $1 = Target PID (The running KeyVox app to wait for)
# $2 = Zip Path (The downloaded update payload)
# $3 = Install Path (The current location of KeyVox.app to be replaced)

TARGET_PID="${1:-}"
ZIP_PATH="${2:-}"
INSTALL_PATH="${3:-}"
BACKUP_PATH=""
STAGING_DIR=""
UPDATE_COMPLETED=0

if [ -z "$TARGET_PID" ] || [ -z "$ZIP_PATH" ] || [ -z "$INSTALL_PATH" ]; then
    echo "Error: updater.sh requires target pid, zip path, and install path." >&2
    exit 1
fi

if ! [[ "$TARGET_PID" =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid target pid: $TARGET_PID" >&2
    exit 1
fi

if [ ! -r "$ZIP_PATH" ]; then
    echo "Error: Update zip is not readable: $ZIP_PATH" >&2
    exit 1
fi

INSTALL_PARENT="$(dirname "$INSTALL_PATH")"
if [ ! -d "$INSTALL_PARENT" ] || [ ! -w "$INSTALL_PARENT" ]; then
    echo "Error: Install directory is not writable: $INSTALL_PARENT" >&2
    exit 1
fi

cleanup() {
    if [ -n "$STAGING_DIR" ] && [ -d "$STAGING_DIR" ]; then
        rm -rf "$STAGING_DIR"
    fi
}

restore_backup() {
    if [ -n "$BACKUP_PATH" ] && [ -d "$BACKUP_PATH" ]; then
        if [ -e "$INSTALL_PATH" ]; then
            rm -rf "$INSTALL_PATH"
        fi
        mv "$BACKUP_PATH" "$INSTALL_PATH"
        open "$INSTALL_PATH"
    fi
}

on_exit() {
    if [ "$UPDATE_COMPLETED" -ne 1 ]; then
        restore_backup
    fi
    cleanup
}

trap on_exit EXIT INT TERM

# 1. Wait for KeyVox to exit completely
# kill -0 checks if the process is running without actually sending a kill signal
echo "Waiting for KeyVox (PID: $TARGET_PID) to terminate..."
WAIT_TICKS=0
MAX_WAIT_SECONDS=30
TICK_DURATION_SECONDS=0.2
MAX_WAIT_TICKS=150
while kill -0 "$TARGET_PID" 2>/dev/null; do
    if [ "$WAIT_TICKS" -ge "$MAX_WAIT_TICKS" ]; then
        # Fail closed instead of force-killing the app so the updater does not
        # discard unsaved state in the event the original process is hung.
        echo "Warning: Timed out waiting for PID $TARGET_PID after ${MAX_WAIT_SECONDS}s." >&2
        exit 1
    fi
    sleep "$TICK_DURATION_SECONDS"
    WAIT_TICKS=$((WAIT_TICKS + 1))
done

# 2. Create a temporary staging directory
STAGING_DIR=$(mktemp -d)

if [ ! -e "$INSTALL_PATH" ]; then
    echo "Error: Install path does not exist: $INSTALL_PATH" >&2
    exit 1
fi

# 3. Unzip the downloaded payload silently
echo "Unzipping update payload..."
/usr/bin/ditto -x -k "$ZIP_PATH" "$STAGING_DIR"

# Locate the newly extracted .app bundle
NEW_APP_PATH=$(find "$STAGING_DIR" -maxdepth 2 -name "*.app" | head -n 1)

if [ -z "$NEW_APP_PATH" ]; then
    echo "Error: No .app bundle found in the downloaded zip." >&2
    exit 1
fi

# 4. Swap the binaries
echo "Replacing old application bundle..."
BACKUP_PATH="${INSTALL_PATH}.backup.$(date +%s)"
mv "$INSTALL_PATH" "$BACKUP_PATH"

if ! mv "$NEW_APP_PATH" "$INSTALL_PATH"; then
    echo "Error: Failed to move new application bundle into place." >&2
    restore_backup
    exit 1
fi

# 5. Clean up the downloaded zip and staging folder
# Preserve BACKUP_PATH for the relaunched app to clean up after a successful
# launch so we still have a rollback target if relaunch fails unexpectedly.
rm -f "$ZIP_PATH"

# 6. Relaunch KeyVox
echo "Relaunching updated KeyVox..."
open "$INSTALL_PATH"
UPDATE_COMPLETED=1

exit 0

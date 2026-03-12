#!/bin/bash
set -euo pipefail

# KeyVox In-Place Auto-Updater
# Arguments:
# $1 = Target PID (The running KeyVox app to wait for)
# $2 = Zip Path (The downloaded update payload)
# $3 = Install Path (The current location of KeyVox.app to be replaced)

TARGET_PID=$1
ZIP_PATH=$2
INSTALL_PATH=$3
BACKUP_PATH=""
STAGING_DIR=""

cleanup() {
    if [ -n "$STAGING_DIR" ] && [ -d "$STAGING_DIR" ]; then
        rm -rf "$STAGING_DIR"
    fi
}

restore_backup() {
    if [ -n "$BACKUP_PATH" ] && [ -d "$BACKUP_PATH" ] && [ ! -e "$INSTALL_PATH" ]; then
        mv "$BACKUP_PATH" "$INSTALL_PATH"
        open "$INSTALL_PATH"
    fi
}

trap cleanup EXIT

# 1. Wait for KeyVox to exit completely
# kill -0 checks if the process is running without actually sending a kill signal
echo "Waiting for KeyVox (PID: $TARGET_PID) to terminate..."
while kill -0 "$TARGET_PID" 2>/dev/null; do
    sleep 0.2
done

# 2. Create a temporary staging directory
STAGING_DIR=$(mktemp -d)

if [ ! -e "$INSTALL_PATH" ]; then
    echo "Error: Install path does not exist: $INSTALL_PATH"
    exit 1
fi

# 3. Unzip the downloaded payload silently
echo "Unzipping update payload..."
/usr/bin/ditto -x -k "$ZIP_PATH" "$STAGING_DIR"

# Locate the newly extracted .app bundle
NEW_APP_PATH=$(find "$STAGING_DIR" -name "*.app" -maxdepth 2 | head -n 1)

if [ -z "$NEW_APP_PATH" ]; then
    echo "Error: No .app bundle found in the downloaded zip."
    exit 1
fi

# 4. Swap the binaries
echo "Replacing old application bundle..."
BACKUP_PATH="${INSTALL_PATH}.backup.$(date +%s)"
mv "$INSTALL_PATH" "$BACKUP_PATH"

if ! mv "$NEW_APP_PATH" "$INSTALL_PATH"; then
    echo "Error: Failed to move new application bundle into place."
    restore_backup
    exit 1
fi

# 5. Clean up the downloaded zip and staging folder
rm -rf "$BACKUP_PATH"
rm -f "$ZIP_PATH"

# 6. Relaunch KeyVox
echo "Relaunching updated KeyVox..."
open "$INSTALL_PATH"

exit 0

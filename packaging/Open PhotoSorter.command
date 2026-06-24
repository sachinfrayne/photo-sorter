#!/bin/bash
# Double-click to run PhotoSorter.
# First time after download: right-click this file → Open → click Open in the dialog.
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$DIR/PhotoSorter.app"

# Remove the browser quarantine flag so PhotoSorter can open normally.
xattr -dr com.apple.quarantine "$APP" "$0" 2>/dev/null || true

if [[ ! -d "$APP" ]]; then
  osascript -e 'display dialog "PhotoSorter.app was not found in this folder.\n\nKeep Open PhotoSorter.command and PhotoSorter.app together in the same folder." buttons {"OK"} default button 1 with icon caution with title "PhotoSorter"'
  exit 1
fi

open "$APP"

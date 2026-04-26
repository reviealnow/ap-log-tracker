#!/usr/bin/env bash
set -euo pipefail

SERIAL_DEVICE="${SERIAL_DEVICE:-${1:-/dev/ttyUSB0}}"
BAUD_RATE="${BAUD_RATE:-${2:-115200}}"
CAPTURE_PATH="${CAPTURE_PATH:-${3:-$HOME/minicom.cap}}"

if ! command -v minicom >/dev/null 2>&1; then
  echo "[ERROR] minicom is not installed. Install it with your OS package manager." >&2
  exit 1
fi

mkdir -p "$(dirname "$CAPTURE_PATH")"
echo "[pi] Starting minicom capture"
echo "[pi] Device: $SERIAL_DEVICE"
echo "[pi] Baud: $BAUD_RATE"
echo "[pi] Capture: $CAPTURE_PATH"
exec minicom -D "$SERIAL_DEVICE" -b "$BAUD_RATE" -C "$CAPTURE_PATH"

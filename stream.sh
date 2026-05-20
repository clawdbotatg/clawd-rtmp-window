#!/bin/bash
# stream.sh — capture a Chrome window region with ffmpeg + AVFoundation,
# encode with VideoToolbox (Apple hardware H.264), push to RTMP.
#
# Usage:
#   cp .env.example .env  &&  edit .env (set SLOP_STREAM_KEY)
#   ./stream.sh             # opens Chrome at SLOP_URL, starts streaming
#   ./stream.sh <url>       # override URL inline
#   Ctrl-C                  # stops the stream
#
# Notes:
#   - The Chrome window is positioned at (WINDOW_X, WINDOW_Y) on display
#     DISPLAY_INDEX and the capture region matches its size. Don't drag
#     or resize it while streaming — ffmpeg captures the fixed pixel rect.
#   - If SLOP_GOD_MODE_PASSWORD is set, it's appended to the URL.
#   - System-audio capture requires BlackHole; see install.sh.

set -euo pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load env
if [[ ! -f "$SELF_DIR/.env" ]]; then
  echo "error: $SELF_DIR/.env missing — copy .env.example and fill it in" >&2
  exit 1
fi
set -a; source "$SELF_DIR/.env"; set +a

# Required
: "${SLOP_STREAM_KEY:?SLOP_STREAM_KEY is required in .env}"
# Defaults
SLOP_URL="${1:-${SLOP_URL:-https://live.slop.computer/debug}}"
RTMP_SERVER="${RTMP_SERVER:-rtmp://media.slop.computer:1935}"
DISPLAY_INDEX="${DISPLAY_INDEX:-4}"
AUDIO_DEVICE="${AUDIO_DEVICE:-}"
WINDOW_X="${WINDOW_X:-0}"; WINDOW_Y="${WINDOW_Y:-0}"
WINDOW_W="${WINDOW_W:-1280}"; WINDOW_H="${WINDOW_H:-720}"
FPS="${FPS:-60}"
BITRATE="${BITRATE:-3400k}"

# Append god-mode if set
FINAL_URL="$SLOP_URL"
if [[ -n "${SLOP_GOD_MODE_PASSWORD:-}" ]]; then
  case "$SLOP_URL" in
    *\?*) FINAL_URL="${SLOP_URL}&godMode=${SLOP_GOD_MODE_PASSWORD}" ;;
    *)    FINAL_URL="${SLOP_URL}?godMode=${SLOP_GOD_MODE_PASSWORD}" ;;
  esac
fi

# Launch Chrome --app at the configured rect. -n = new instance even if
# Chrome is already running with this profile. --user-data-dir is local to
# this project so it doesn't disturb your personal Chrome.
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
PROFILE_DIR="$SELF_DIR/chrome-profile"
mkdir -p "$PROFILE_DIR"

echo "==> launching Chrome --app at (${WINDOW_X},${WINDOW_Y}) ${WINDOW_W}x${WINDOW_H}"
echo "    $FINAL_URL"
open -na "Google Chrome" --args \
  --app="$FINAL_URL" \
  --user-data-dir="$PROFILE_DIR" \
  --profile-directory=Default \
  --window-position="${WINDOW_X},${WINDOW_Y}" \
  --window-size="${WINDOW_W},${WINDOW_H}" \
  --no-first-run \
  --no-default-browser-check \
  --disable-notifications

# Give Chrome a moment to draw the window before we start capturing.
sleep 3

# ffmpeg input device string: "<video>:<audio>" (omit audio for video-only).
INPUT_SPEC="$DISPLAY_INDEX:"
if [[ -n "$AUDIO_DEVICE" ]]; then
  INPUT_SPEC="${DISPLAY_INDEX}:${AUDIO_DEVICE}"
fi

RTMP_URL="${RTMP_SERVER}/${SLOP_STREAM_KEY}"

echo "==> streaming → $RTMP_SERVER (key redacted)"
echo "==> press Ctrl-C to stop"
echo

# capture_cursor=0 hides the mouse pointer from the stream.
# Crop the captured display to the Chrome window rect, then encode w/
# VideoToolbox H.264 hardware encoder. yuv420p is the broadly compatible
# pixel format Flash Video / most players expect.
exec ffmpeg -hide_banner -loglevel warning -stats \
  -f avfoundation \
    -framerate "$FPS" \
    -capture_cursor 0 \
    -pixel_format uyvy422 \
    -i "$INPUT_SPEC" \
  -vf "crop=${WINDOW_W}:${WINDOW_H}:${WINDOW_X}:${WINDOW_Y},format=yuv420p" \
  -c:v h264_videotoolbox \
    -b:v "$BITRATE" \
    -maxrate "$BITRATE" \
    -bufsize "$BITRATE" \
    -g $((FPS * 2)) \
  ${AUDIO_DEVICE:+-c:a aac -b:a 160k -ar 48000} \
  -f flv \
  "$RTMP_URL"

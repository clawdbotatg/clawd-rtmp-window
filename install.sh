#!/bin/bash
# install.sh — install ffmpeg (required) + BlackHole audio loopback
# (optional, only needed for system-audio capture).
set -euo pipefail

if ! command -v brew >/dev/null; then
  echo "==> installing Homebrew ..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if ! command -v ffmpeg >/dev/null; then
  echo "==> installing ffmpeg ..."
  brew install ffmpeg
fi

# BlackHole is a virtual audio driver — pipes system audio into a device
# ffmpeg can read. Skip if you only want video.
if [[ "${SKIP_BLACKHOLE:-0}" != "1" ]]; then
  if ! system_profiler SPAudioDataType 2>/dev/null | grep -q "BlackHole"; then
    echo "==> installing BlackHole 2ch (system-audio loopback) ..."
    brew install blackhole-2ch
    echo
    echo "BlackHole is installed but needs a one-time macOS setup:"
    echo "  1. Open Audio MIDI Setup.app"
    echo "  2. Click + (bottom left) → 'Create Multi-Output Device'"
    echo "  3. Check both 'BlackHole 2ch' AND your usual output (e.g. MacBook Pro Speakers)"
    echo "  4. Right-click the new device → 'Use This Device for Sound Output'"
    echo "  5. Set AUDIO_DEVICE=\"BlackHole 2ch\" in .env"
    echo
    echo "Audio you hear normally now also flows into BlackHole, which ffmpeg captures."
  else
    echo "==> BlackHole already installed"
  fi
fi

echo
echo "done. next:"
echo "  cp .env.example .env  &&  edit .env (set SLOP_STREAM_KEY at minimum)"
echo "  ./list-devices.sh     (find your screen index + audio device name)"
echo "  ./stream.sh           (go live)"

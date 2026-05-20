#!/bin/bash
# Prints the AVFoundation capture devices ffmpeg sees. Find the index of
# the screen you want to capture from + the audio device name (if using
# BlackHole loopback).
exec ffmpeg -hide_banner -f avfoundation -list_devices true -i "" 2>&1 | sed -n '/AVFoundation .* devices:/,/AVFoundation audio devices:/p; /AVFoundation audio devices:/,/Input\|Error/p' | grep -E "\[[0-9]+\]" | sed 's/^\[AVFoundation indev[^]]*\] //'

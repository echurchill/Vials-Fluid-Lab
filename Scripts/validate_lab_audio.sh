#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
lab_output="${1:-build/audio-validation}"
mkdir -p "$lab_output"
xcrun swiftc -O -parse-as-library Vials/FluidLab/LabBoardFeedback.swift \
  Scripts/validate_lab_audio.swift -o "$lab_output/validate"
"$lab_output/validate" "$lab_output"

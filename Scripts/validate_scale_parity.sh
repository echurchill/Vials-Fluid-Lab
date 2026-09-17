#!/bin/bash
set -euo pipefail
lab_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lab_output="${1:-/tmp/vials-scale-parity}"
mkdir -p "$lab_output"
cd "$lab_root"
xcrun swiftc -O -parse-as-library Vials/FluidLab/LabGeometry.swift Vials/FluidLab/LabBoard.swift \
  Vials/FluidLab/LabBoardGeometry.swift Scripts/validate_scale_parity.swift -o "$lab_output/validate-scale-parity"
"$lab_output/validate-scale-parity"

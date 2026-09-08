#!/bin/bash
set -euo pipefail
lab_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lab_output="${1:-$(mktemp -d /tmp/vials-comparison.XXXXXX)}"
mkdir -p "$lab_output"
lab_output="$(cd "$lab_output" && pwd)"
cd "$lab_root"
xcodebuild -project 'Vials Fluid Lab.xcodeproj' -scheme 'Vials Fluid Lab' \
  -configuration Debug -destination 'generic/platform=macOS' \
  -derivedDataPath "$lab_output/DerivedData" CODE_SIGNING_ALLOWED=NO build \
  > "$lab_output/build.log" 2>&1 || { tail -n 60 "$lab_output/build.log"; exit 1; }
xcrun swiftc -O -parse-as-library Vials/FluidLab/LabGeometry.swift \
  Vials/FluidLab/LabRenderer.swift Vials/FluidLab/LabBoard.swift \
  Vials/FluidLab/LabBoardGeometry.swift Vials/FluidLab/LabBoardRenderer.swift \
  Vials/FluidLab/LabBoardPreferences.swift Vials/FluidLab/LabBoardSession.swift \
  Vials/FluidLab/LabPerformance.swift Vials/FluidLab/LabClassicBoardView.swift \
  Scripts/validate_comparison.swift -o "$lab_output/validate-comparison"
lab_library="$lab_output/DerivedData/Build/Products/Debug/VialsFluidLab.app/Contents/Resources/default.metallib"
"$lab_output/validate-comparison" --library "$lab_library" --output "$lab_output/shared-puzzles"
xcrun swiftc -O -parse-as-library Vials/FluidLab/LabGeometry.swift \
  Vials/FluidLab/LabRenderer.swift Vials/FluidLab/LabBoard.swift \
  Vials/FluidLab/LabBoardGeometry.swift Vials/FluidLab/LabBoardRenderer.swift \
  Scripts/validate_fluid_board.swift -o "$lab_output/validate-fluid-board"
for lab_fixture in level shortest three partial last pear; do
  "$lab_output/validate-fluid-board" --library "$lab_library" --speed 1.6 \
    --fixture "$lab_fixture" --output "$lab_output/quick-$lab_fixture"
done
"$lab_output/validate-fluid-board" --library "$lab_library" --speed 1.6 \
  --fps 30 --width 600 --height 760 --output "$lab_output/quick-portrait"
printf 'Comparison reports and captures: %s\n' "$lab_output"

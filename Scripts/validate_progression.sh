#!/bin/bash
set -euo pipefail
lab_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lab_output="${1:-$(mktemp -d /tmp/vials-progression.XXXXXX)}"
mkdir -p "$lab_output"
lab_output="$(cd "$lab_output" && pwd)"
cd "$lab_root"
xcodebuild -project 'Vials Fluid Lab.xcodeproj' -scheme 'Vials Fluid Lab' \
  -configuration Debug -destination 'generic/platform=macOS' \
  -derivedDataPath "$lab_output/DerivedData" CODE_SIGNING_ALLOWED=NO build \
  > "$lab_output/build.log" 2>&1 || { tail -n 60 "$lab_output/build.log"; exit 1; }
lab_sources=(Vials/FluidLab/LabGeometry.swift Vials/FluidLab/LabRenderer.swift
  Vials/FluidLab/LabBoard.swift Vials/FluidLab/LabBoardGeometry.swift
  Vials/FluidLab/LabBoardPreferences.swift Vials/FluidLab/LabSortingCourse.swift Vials/FluidLab/LabBoardRenderer.swift)
xcrun swiftc -O -parse-as-library "${lab_sources[@]}" Scripts/validate_fluid_board.swift -o "$lab_output/validate-board"
lab_library="$lab_output/DerivedData/Build/Products/Debug/VialsFluidLab.app/Contents/Resources/default.metallib"
for lab_fixture in greenArrival tidalPool glassGarden switchback estuary crossingPaths deepCurrent orchard confluence; do
  "$lab_output/validate-board" --library "$lab_library" --fixture "$lab_fixture" --speed 1.6 --output "$lab_output/$lab_fixture"
done
xcrun swiftc -O -parse-as-library "${lab_sources[@]}" Vials/FluidLab/LabBoardFeedback.swift \
  Vials/FluidLab/LabBoardSession.swift Vials/FluidLab/LabFluid2D.swift Vials/FluidLab/LabPerformance.swift \
  Vials/FluidLab/LabClassicBoardView.swift Scripts/validate_comparison.swift -o "$lab_output/validate-comparison"
"$lab_output/validate-comparison" --library "$lab_library" --output "$lab_output/comparison"
for lab_fixture in level last; do
  "$lab_output/validate-board" --library "$lab_library" --fixture "$lab_fixture" --output "$lab_output/relaxed-$lab_fixture"
done
"$lab_output/validate-board" --library "$lab_library" --fixture tidalPool --speed 1.6 \
  --fps 30 --width 600 --height 760 --output "$lab_output/portrait"
printf 'Progression reports and captures: %s\n' "$lab_output"

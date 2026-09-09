#!/bin/bash
set -euo pipefail
lab_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lab_output="${1:-$(mktemp -d /tmp/vials-planar.XXXXXX)}"
mkdir -p "$lab_output"
lab_output="$(cd "$lab_output" && pwd)"
cd "$lab_root"
xcodebuild -project 'Vials Fluid Lab.xcodeproj' -scheme 'Vials Fluid Lab' \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath "$lab_output/DerivedData" CODE_SIGNING_ALLOWED=NO build \
  > "$lab_output/build.log" 2>&1 || { tail -n 60 "$lab_output/build.log"; exit 1; }
lab_geometry=(Vials/FluidLab/LabGeometry.swift Vials/FluidLab/LabBoard.swift \
  Vials/FluidLab/LabBoardGeometry.swift Vials/FluidLab/LabBoardPreferences.swift Vials/FluidLab/LabFluid2D.swift)
xcrun swiftc -O -parse-as-library "${lab_geometry[@]}" Scripts/validate_fluid_2d.swift -o "$lab_output/validate-fluid-2d"
for lab_puzzle in firstSort crossCurrents lastDrops greenArrival tidalPool glassGarden switchback estuary crossingPaths deepCurrent orchard confluence; do
  "$lab_output/validate-fluid-2d" "$lab_puzzle" "$lab_output/$lab_puzzle.json" > "$lab_output/$lab_puzzle.log"
done
"$lab_output/validate-fluid-2d" greenArrival "$lab_output/relaxed.json" --relaxed > "$lab_output/relaxed.log"
"$lab_output/validate-fluid-2d" greenArrival "$lab_output/30fps.json" --30fps > "$lab_output/30fps.log"
xcrun swiftc -O -parse-as-library "${lab_geometry[@]}" \
  Vials/FluidLab/LabRenderer.swift Vials/FluidLab/LabBoardRenderer.swift \
  Vials/FluidLab/LabBoardFeedback.swift Vials/FluidLab/LabBoardSession.swift \
  Vials/FluidLab/LabPerformance.swift Vials/FluidLab/LabClassicBoardView.swift \
  Vials/FluidLab/LabFluid2DView.swift Scripts/validate_2d_session.swift -o "$lab_output/validate-2d-session"
"$lab_output/validate-2d-session" --output "$lab_output" \
  --library "$lab_output/DerivedData/Build/Products/Release/VialsFluidLab.app/Contents/Resources/default.metallib" \
  > "$lab_output/session.log" 2>&1
printf '2D Fluid reports and captures: %s\n' "$lab_output"

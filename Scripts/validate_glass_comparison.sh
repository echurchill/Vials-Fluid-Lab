#!/bin/bash
set -euo pipefail
lab_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lab_output="${1:-$(mktemp -d /tmp/vials-glass-check.XXXXXX)}"
mkdir -p "$lab_output"
lab_output="$(cd "$lab_output" && pwd)"
lab_build="${2:-$lab_output/DerivedData}"
cd "$lab_root"
xcodebuild -project 'Vials Fluid Lab.xcodeproj' -scheme 'Vials Fluid Lab' -configuration Release \
 -destination 'generic/platform=macOS' -derivedDataPath "$lab_build" CODE_SIGNING_ALLOWED=NO build \
 > "$lab_output/build.log" 2>&1 || { tail -60 "$lab_output/build.log"; exit 1; }
lab_sources=(Vials/FluidLab/LabGeometry.swift Vials/FluidLab/LabRenderer.swift Vials/FluidLab/LabBoard.swift \
 Vials/FluidLab/LabBoardGeometry.swift Vials/FluidLab/LabBoardRenderer.swift Vials/FluidLab/LabBoardPreferences.swift \
 Vials/FluidLab/LabBoardFeedback.swift Vials/FluidLab/LabBoardSession.swift Vials/FluidLab/LabFluid2D.swift \
 Vials/FluidLab/LabPerformance.swift Vials/FluidLab/LabClassicBoardView.swift Vials/FluidLab/LabFluid2DView.swift)
lab_library="$lab_build/Build/Products/Release/VialsFluidLab.app/Contents/Resources/default.metallib"
xcrun swiftc -O -parse-as-library "${lab_sources[@]}" Vials/FluidLab/LabPourComparison.swift Scripts/validate_pour_comparison.swift -o "$lab_output/validate-comparison"
"$lab_output/validate-comparison" --library "$lab_library" --output "$lab_output" > "$lab_output/comparison.log" 2>&1
xcrun swiftc -O -parse-as-library "${lab_sources[@]}" Scripts/validate_2d_session.swift -o "$lab_output/validate-session"
"$lab_output/validate-session" --library "$lab_library" --output "$lab_output" > "$lab_output/session.log" 2>&1
printf 'Glass and comparison checks: %s\n' "$lab_output"

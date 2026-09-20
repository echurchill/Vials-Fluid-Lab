#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
lab_library="${1:?Pass a built macOS Metal library}"
lab_output="${2:-build/density-change/validation}"
mkdir -p "$lab_output"
xcrun swiftc -O -parse-as-library Vials/FluidLab/LabGeometry.swift Vials/FluidLab/LabRenderer.swift \
 Vials/FluidLab/LabBoard.swift Vials/FluidLab/LabBoardGeometry.swift Vials/FluidLab/LabBoardRenderer.swift \
 Vials/FluidLab/LabBoardPreferences.swift Vials/FluidLab/LabBoardFeedback.swift Vials/FluidLab/LabBoardSession.swift \
 Vials/FluidLab/LabFluid2D.swift Vials/FluidLab/LabPerformance.swift Vials/FluidLab/LabClassicBoardView.swift \
 Vials/FluidLab/LabFluid2DView.swift Vials/FluidLab/LabPlanarSurface.swift Scripts/validate_density_change.swift -o "$lab_output/validate"
cp "$lab_library" "$lab_output/default.metallib"
"$lab_output/validate" "$lab_library" "$lab_output" "${@:3}"

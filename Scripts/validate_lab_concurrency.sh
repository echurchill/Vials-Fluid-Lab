#!/bin/bash
set -euo pipefail
lab_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lab_library="${1:?Pass a built macOS default.metallib}"
lab_output="${2:-$lab_root/build/lab-concurrency}"
mkdir -p "$lab_output"
lab_output="$(cd "$lab_output" && pwd)"
cd "$lab_root"
xcrun swiftc -module-cache-path "$lab_output/ModuleCache" -O -parse-as-library Vials/FluidLab/LabGeometry.swift Vials/FluidLab/LabRenderer.swift \
 Vials/FluidLab/LabBoard.swift Vials/FluidLab/LabBoardGeometry.swift Vials/FluidLab/LabBoardRenderer.swift \
 Vials/FluidLab/LabBoardPreferences.swift Vials/FluidLab/LabSortingCourse.swift Vials/FluidLab/LabBoardFeedback.swift Vials/FluidLab/LabBoardSession.swift \
 Vials/FluidLab/LabFluid2D.swift Vials/FluidLab/LabPerformance.swift Vials/FluidLab/LabClassicBoardView.swift \
 Vials/FluidLab/LabFluid2DView.swift Vials/FluidLab/LabPlanarSurface.swift Scripts/validate_lab_concurrency.swift -o "$lab_output/validate"
cp "$lab_library" "$lab_output/default.metallib"
"$lab_output/validate" "$lab_library" "$lab_output"

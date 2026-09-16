#!/bin/bash
set -euo pipefail
lab_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lab_library="${1:?Pass a built macOS Metal library}"
lab_output="${2:-$lab_root/build/reset-progress}"
mkdir -p "$lab_output"
cd "$lab_root"
xcrun swiftc -O -parse-as-library Vials/FluidLab/LabGeometry.swift Vials/FluidLab/LabRenderer.swift \
 Vials/FluidLab/LabBoard.swift Vials/FluidLab/LabBoardGeometry.swift Vials/FluidLab/LabBoardRenderer.swift \
 Vials/FluidLab/LabBoardPreferences.swift Vials/FluidLab/LabBoardFeedback.swift Vials/FluidLab/LabBoardSession.swift \
 Vials/FluidLab/LabFluid2D.swift Vials/FluidLab/LabPerformance.swift Vials/FluidLab/LabClassicBoardView.swift \
 Vials/FluidLab/LabFluid2DView.swift Vials/FluidLab/LabPlanarSurface.swift \
 Vials/Game/LevelMode.swift Vials/Game/Mastery.swift Vials/Support/GameProgressStore.swift \
 Vials/Support/PlayerResultStore.swift Vials/Support/LevelVariantStore.swift Vials/Support/LevelFeedbackStore.swift \
 Scripts/validate_reset_progress.swift -o "$lab_output/validate-reset"
"$lab_output/validate-reset" "$lab_library"

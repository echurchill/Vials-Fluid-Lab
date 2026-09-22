#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
output="${TMPDIR:-/tmp}/vials-journey"
mkdir -p "$output/module-cache"
xcrun swiftc -O -module-cache-path "$output/module-cache" -parse-as-library \
  Vials/FluidLab/LabGeometry.swift Vials/FluidLab/LabRenderer.swift \
  Vials/FluidLab/LabBoard.swift Vials/FluidLab/LabBoardGeometry.swift \
  Vials/FluidLab/LabBoardPreferences.swift Vials/FluidLab/LabBoardRenderer.swift \
  Vials/FluidLab/LabBoardFeedback.swift Vials/FluidLab/LabBoardSession.swift \
  Vials/FluidLab/LabFluid2D.swift Vials/FluidLab/LabPerformance.swift \
  Vials/FluidLab/LabClassicBoardView.swift Scripts/validate_journey.swift \
  -o "$output/validate-journey"
"$output/validate-journey"

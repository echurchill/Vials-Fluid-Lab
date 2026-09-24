#!/bin/bash
set -euo pipefail
lab_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lab_output="${1:-$(mktemp -d /tmp/vials-render-cost.XXXXXX)}"
mkdir -p "$lab_output"
lab_output="$(cd "$lab_output" && pwd)"
cd "$lab_root"
# Compare the prior visual renderer against the current one on identical snapshots.
git show "${2:-1f515c2}":Vials/FluidLab/LabFluid2DView.swift | sed 's/struct LabFluid2DView:View/struct LabFluid2DBaselineView:View/' > "$lab_output/BaselineView.swift"
xcrun swiftc -O -parse-as-library Vials/FluidLab/LabGeometry.swift Vials/FluidLab/LabRenderer.swift \
 Vials/FluidLab/LabBoard.swift Vials/FluidLab/LabBoardGeometry.swift Vials/FluidLab/LabBoardRenderer.swift \
 Vials/FluidLab/LabBoardPreferences.swift Vials/FluidLab/LabSortingCourse.swift Vials/FluidLab/LabBoardFeedback.swift Vials/FluidLab/LabBoardSession.swift \
 Vials/FluidLab/LabPerformance.swift Vials/FluidLab/LabClassicBoardView.swift Vials/FluidLab/LabFluid2D.swift \
 Vials/FluidLab/LabFluid2DView.swift "$lab_output/BaselineView.swift" Scripts/benchmark_2d_rendering.swift \
 -o "$lab_output/benchmark"
"$lab_output/benchmark" "$lab_output/render-cost.json"

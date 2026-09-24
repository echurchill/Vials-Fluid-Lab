#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
output="${TMPDIR:-/tmp}/vials-sorting-course"
mkdir -p "$output/module-cache"
xcrun swiftc -O -module-cache-path "$output/module-cache" -parse-as-library \
  Vials/Game/ContainerRule.swift Vials/Game/FluidMaterial.swift Vials/Game/Fluid.swift \
  Vials/Game/GameSnapshot.swift Vials/Game/HelperCup.swift Vials/Game/LevelCurriculum.swift \
  Vials/Game/LevelMode.swift Vials/Game/SeededRandomNumberGenerator.swift Vials/Game/Vial.swift \
  Vials/Game/VialAnchorCatalog.swift Vials/Game/VialLevel.swift Vials/Game/VialLevelGenerator.swift \
  Vials/FluidLab/LabGeometry.swift Vials/FluidLab/LabRenderer.swift \
  Vials/FluidLab/LabBoard.swift Vials/FluidLab/LabBoardGeometry.swift \
  Vials/FluidLab/LabBoardPreferences.swift Vials/FluidLab/LabSortingCourse.swift \
  Vials/FluidLab/LabBoardRenderer.swift Vials/FluidLab/LabBoardFeedback.swift \
  Vials/FluidLab/LabBoardSession.swift Vials/FluidLab/LabEndlessSorting.swift \
  Vials/FluidLab/LabFluid2D.swift Vials/FluidLab/LabPerformance.swift \
  Vials/FluidLab/LabClassicBoardView.swift Scripts/validate_sorting_course.swift \
  -o "$output/validate-sorting-course"
"$output/validate-sorting-course"

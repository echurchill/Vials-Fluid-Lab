#!/bin/bash
set -euo pipefail
lab_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lab_output="${1:-$(mktemp -d /tmp/vials-complexity.XXXXXX)}"
mkdir -p "$lab_output"
lab_output="$(cd "$lab_output" && pwd)"
cd "$lab_root"

xcodebuild -project 'Vials Fluid Lab.xcodeproj' -scheme 'Vials Fluid Lab' \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath "$lab_output/DerivedData" CODE_SIGNING_ALLOWED=NO build \
  > "$lab_output/build.log" 2>&1 || { tail -n 80 "$lab_output/build.log"; exit 1; }

xcrun swiftc -module-cache-path "$lab_output/ModuleCache" -O -parse-as-library \
  Vials/FluidLab/LabGeometry.swift Vials/FluidLab/LabBoard.swift \
  Vials/FluidLab/LabBoardGeometry.swift Vials/FluidLab/LabBoardPreferences.swift Vials/FluidLab/LabSortingCourse.swift \
  Scripts/validate_complexity.swift -o "$lab_output/validate-complexity"
"$lab_output/validate-complexity" | tee "$lab_output/model.log"

lab_sources=(Vials/FluidLab/LabGeometry.swift Vials/FluidLab/LabRenderer.swift
  Vials/FluidLab/LabBoard.swift Vials/FluidLab/LabBoardGeometry.swift
  Vials/FluidLab/LabBoardPreferences.swift Vials/FluidLab/LabSortingCourse.swift Vials/FluidLab/LabFluid2D.swift Vials/FluidLab/LabBoardRenderer.swift)
xcrun swiftc -module-cache-path "$lab_output/ModuleCache" -O -parse-as-library \
  "${lab_sources[@]}" Scripts/validate_fluid_board.swift -o "$lab_output/validate-board"
lab_library="$lab_output/DerivedData/Build/Products/Release/VialsFluidLab.app/Contents/Resources/default.metallib"
for lab_fixture in fiveStreams tallOrder sixfold valveCircuit; do
  "$lab_output/validate-board" --library "$lab_library" --fixture "$lab_fixture" \
    --speed 1.6 --fps 30 --width 700 --height 455 --pacing-budget 14 \
    --output "$lab_output/3d-$lab_fixture" | tee "$lab_output/3d-$lab_fixture.log"
done

lab_planar=(Vials/FluidLab/LabGeometry.swift Vials/FluidLab/LabBoard.swift
  Vials/FluidLab/LabBoardGeometry.swift Vials/FluidLab/LabBoardPreferences.swift Vials/FluidLab/LabSortingCourse.swift Vials/FluidLab/LabFluid2D.swift)
xcrun swiftc -module-cache-path "$lab_output/ModuleCache" -O -parse-as-library \
  "${lab_planar[@]}" Scripts/validate_fluid_2d.swift -o "$lab_output/validate-2d"
for lab_fixture in fiveStreams tallOrder sixfold valveCircuit; do
  "$lab_output/validate-2d" "$lab_fixture" "$lab_output/2d-$lab_fixture.json" \
    > "$lab_output/2d-$lab_fixture.log"
done

printf 'Complexity validation reports and captures: %s\n' "$lab_output"

#!/bin/bash
set -euo pipefail
lab_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lab_output="${1:-$(mktemp -d /tmp/vials-fluid-validation.XXXXXX)}"
mkdir -p "$lab_output"
lab_output="$(cd "$lab_output" && pwd)"
cd "$lab_root"
xcodebuild -project 'Vials Fluid Lab.xcodeproj' -scheme 'Vials Fluid Lab' \
  -configuration Debug -destination 'generic/platform=macOS' \
  -derivedDataPath "$lab_output/DerivedData" CODE_SIGNING_ALLOWED=NO build \
  > "$lab_output/build.log" 2>&1 || { tail -n 60 "$lab_output/build.log"; exit 1; }
xcrun swiftc -O -parse-as-library Vials/FluidLab/LabGeometry.swift \
  Vials/FluidLab/LabRenderer.swift Scripts/validate_fluid_lab.swift \
  -o "$lab_output/validate-fluid-lab"
lab_library="$lab_output/DerivedData/Build/Products/Debug/VialsFluidLab.app/Contents/Resources/default.metallib"
for lab_run in 1 2 3; do
  for lab_material in water thick dyes; do
    "$lab_output/validate-fluid-lab" --library "$lab_library" \
      --material "$lab_material" --output "$lab_output/$lab_run-$lab_material" \
      --frames 1080 --capture 119,539,959 --skip-reset-fixture
  done
done
"$lab_output/validate-fluid-lab" --library "$lab_library" \
  --output "$lab_output/portrait-30fps" --fps 30 --frames 570 --pour-frame 0 \
  --width 430 --height 520 --capture 59,239,269,539
"$lab_output/validate-fluid-lab" --library "$lab_library" \
  --output "$lab_output/slow-motion" --speed 0.35 --frames 2880 --pour-frame 0 \
  --capture 359,1379,2099,2819 --skip-reset-fixture
"$lab_output/validate-fluid-lab" --library "$lab_library" \
  --output "$lab_output/rejected-aim" --aim 0.9 --frames 1080 \
  --capture 539,1019 --expect-rejection --skip-reset-fixture
"$lab_output/validate-fluid-lab" --library "$lab_library" \
  --output "$lab_output/larger-correction" --lookahead 0.28 --frames 1080 \
  --capture 899,959 --skip-reset-fixture
"$lab_output/validate-fluid-lab" --library "$lab_library" \
  --output "$lab_output/rejected-volume" --lookahead 0.18 --frames 1080 \
  --capture 959 --expect-rejection --skip-reset-fixture
printf 'Validation reports and captures: %s\n' "$lab_output"

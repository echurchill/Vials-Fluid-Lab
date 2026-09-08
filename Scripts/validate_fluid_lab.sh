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
for lab_material in water thick dyes; do
  "$lab_output/validate-fluid-lab" --library "$lab_library" \
    --material "$lab_material" --output "$lab_output/$lab_material" --frames 1260
done
"$lab_output/validate-fluid-lab" --library "$lab_library" \
  --output "$lab_output/portrait-30fps" --fps 30 --frames 660 --pour-frame 0 \
  --width 430 --height 520 --capture 59,239,269,329,599
printf 'Validation reports and captures: %s\n' "$lab_output"

#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
output="${TMPDIR:-/tmp}/vials-keystone-validation"
mkdir -p "$output/module-cache"
xcrun swiftc -O -module-cache-path "$output/module-cache" -parse-as-library \
  Vials/FluidLab/LabBoard.swift \
  Vials/FluidLab/LabBoardPreferences.swift \
  Scripts/validate_keystone_labs.swift \
  -o "$output/validate-keystone-labs"
"$output/validate-keystone-labs"

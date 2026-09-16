#!/bin/bash
set -euo pipefail
lab_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lab_library="${1:?Pass a built macOS default.metallib}"
lab_output="${2:-$lab_root/build/seed-setup}"
mkdir -p "$lab_output"
lab_output="$(cd "$lab_output" && pwd)"
cd "$lab_root"
# Keep this comparison tied to the shipped Prototype18 implementation.
python3 - "$lab_output/BaselineBoardRenderer.swift" <<'PY'
import pathlib,subprocess,sys
source=subprocess.check_output(['git','show','710c272:Vials/FluidLab/LabBoardRenderer.swift'],text=True)
source='import Foundation\nimport MetalKit\nimport simd\n\n'+source[source.index('private struct LabMetalTransfer'):]
source=source.replace('LabMetalTransfer','BaselineMetalTransfer').replace('LabBoardRenderer','BaselineBoardRenderer')
pathlib.Path(sys.argv[1]).write_text(source)
PY
xcrun swiftc -O -parse-as-library Vials/FluidLab/LabGeometry.swift Vials/FluidLab/LabRenderer.swift \
 Vials/FluidLab/LabBoard.swift Vials/FluidLab/LabBoardGeometry.swift Vials/FluidLab/LabBoardRenderer.swift \
 Vials/FluidLab/LabBoardPreferences.swift Vials/FluidLab/LabFluid2D.swift \
 "$lab_output/BaselineBoardRenderer.swift" Scripts/benchmark_seed_setup.swift -o "$lab_output/benchmark-seed"
"$lab_output/benchmark-seed" "$lab_library" "$lab_output/seed-setup.json"

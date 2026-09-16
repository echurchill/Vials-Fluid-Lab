#!/bin/bash
set -euo pipefail
lab_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lab_library="${1:?Pass a built macOS Metal library}"
lab_output="${2:-$lab_root/build/antialiasing/paired}"
mkdir -p "$lab_output"
lab_output="$(cd "$lab_output" && pwd)"
cd "$lab_root"
python3 - "$lab_output/BaselineBoardRenderer.swift" <<'PY'
import pathlib,subprocess,sys
source=subprocess.check_output(['git','show','bbe76cc:Vials/FluidLab/LabBoardRenderer.swift'],text=True)
source='import Foundation\nimport MetalKit\nimport simd\n\n'+source[source.index('private struct LabMetalTransfer'):]
source=source.replace('LabMetalTransfer','BaselineMetalTransfer').replace('LabBoardRenderer','BaselineBoardRenderer')
pathlib.Path(sys.argv[1]).write_text(source)
PY
xcrun swiftc -O -parse-as-library Vials/FluidLab/LabGeometry.swift Vials/FluidLab/LabRenderer.swift \
 Vials/FluidLab/LabBoard.swift Vials/FluidLab/LabBoardGeometry.swift Vials/FluidLab/LabBoardRenderer.swift \
 Vials/FluidLab/LabBoardPreferences.swift Vials/FluidLab/LabFluid2D.swift \
 "$lab_output/BaselineBoardRenderer.swift" Scripts/validate_glass_antialiasing.swift -o "$lab_output/validate"
"$lab_output/validate" "$lab_library" "$lab_output"

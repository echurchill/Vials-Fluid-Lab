#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
journey_output="${1:-build/journey/presentation}"
mkdir -p "$journey_output"
xcrun swiftc -O -parse-as-library Vials/FluidLab/LabBoard.swift Vials/FluidLab/LabBoardPreferences.swift Vials/FluidLab/LabJourneyMapView.swift Vials/FluidLab/LabLearningGuideView.swift Scripts/preview_journey.swift -o "$journey_output/preview"
"$journey_output/preview" "$journey_output"

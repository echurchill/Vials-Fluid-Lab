import SwiftUI

struct LiquidLayerStack: View {
    let fluids: [Fluid]
    let bands: [LiquidBand]
    let visibleUnitCount: Int
    let showsTopSurface: Bool

    var body: some View {
        GeometryReader { proxy in
            let runs = liquidRuns(
                from: fluids,
                bands: bands,
                visibleUnitCount: visibleUnitCount,
                showsTopSurface: showsTopSurface
            )

            ZStack {
                ForEach(runs) { run in
                    FluidSegment(
                        fluid: run.fluid,
                        seed: run.startIndex,
                        unitCount: run.unitCount,
                        showsSurface: run.showsSurface,
                        showsBottomDepth: run.showsBottomDepth
                    )
                        .frame(width: proxy.size.width, height: max(run.band.height, 1) + 1)
                        .position(x: proxy.size.width / 2, y: run.band.midY)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func liquidRuns(
        from fluids: [Fluid],
        bands: [LiquidBand],
        visibleUnitCount: Int,
        showsTopSurface: Bool
    ) -> [LiquidRun] {
        guard !fluids.isEmpty, !bands.isEmpty else { return [] }

        var runs: [LiquidRun] = []
        var start = 0
        var current = fluids[0]

        for index in 1..<fluids.count {
            if fluids[index] != current {
                runs.append(run(
                    fluid: current,
                    start: start,
                    end: index - 1,
                    bands: bands,
                    visibleUnitCount: visibleUnitCount,
                    showsTopSurface: showsTopSurface
                ))
                start = index
                current = fluids[index]
            }
        }

        runs.append(run(
            fluid: current,
            start: start,
            end: fluids.count - 1,
            bands: bands,
            visibleUnitCount: visibleUnitCount,
            showsTopSurface: showsTopSurface
        ))
        return runs
    }

    private func run(
        fluid: Fluid,
        start: Int,
        end: Int,
        bands: [LiquidBand],
        visibleUnitCount: Int,
        showsTopSurface: Bool
    ) -> LiquidRun {
        let safeStart = min(start, bands.count - 1)
        let safeEnd = min(end, bands.count - 1)
        let visibleTopIndex = max(0, min(visibleUnitCount, bands.count) - 1)
        let bottomBand = bands[safeStart]
        let topBand = bands[safeEnd]

        return LiquidRun(
            fluid: fluid,
            startIndex: start,
            endIndex: end,
            unitCount: max(1, end - start + 1),
            showsSurface: showsTopSurface && visibleUnitCount > 0 && start <= visibleTopIndex && end >= visibleTopIndex,
            showsBottomDepth: start == 0,
            band: LiquidBand(top: topBand.top, bottom: bottomBand.bottom)
        )
    }
}

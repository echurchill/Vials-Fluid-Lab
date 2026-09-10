import SwiftUI
import MetalKit
import Combine

/// Runs a captured transfer in disposable sessions; it never owns gameplay defaults.
@MainActor final class LabPourComparison:ObservableObject {
    let example:LabPourExample
    @Published private(set) var session:FluidBoardSession
    @Published private(set) var preparing=true
    @Published private(set) var status="Preparing the same pour for each view…"
    @Published private(set) var durations:[LabBoardPresentation:Float]=[.classic:LabClassicPour.duration]
    @Published var matchDuration=true
    let targetSeconds:Float=5
    private let device:MTLDevice?
    private let library:MTLLibrary?
    private var prepared=false
    init(example:LabPourExample,device:MTLDevice?=MTLCreateSystemDefaultDevice(),library:MTLLibrary?=nil) {
        self.example=example;self.device=device;self.library=library
        session=Self.makeSession(example:example,mode:.fluid2D,device:device,library:library)
    }
    private static func makeSession(example:LabPourExample,mode:LabBoardPresentation,device:MTLDevice?,library:MTLLibrary?)->FluidBoardSession {
        FluidBoardSession(defaults:nil,device:device,library:library,restoredSave:LabComparisonSave(presentation:mode,pace:.quick,puzzle:example.puzzle,games:[example.puzzle.rawValue:LabBoardGame(state:example.state)]))
    }
    func prepare() async {
        guard !prepared else { return };prepared=true
        defer { preparing=false }
        let state=example.state,move=example.move
        let duration=await Task.detached(priority:.userInitiated) {
            var engine=LabFluid2D(game:LabBoardGame(state:state));engine.quickMotion=true
            guard engine.begin(move) else { return Float(0) }
            for _ in 0..<2400 where engine.busy { engine.advance(deltaTime:1/60) }
            return engine.game.state==state.applying(move) ? engine.time:0
        }.value
        guard !Task.isCancelled else { return }
        if duration>0 { durations[.fluid2D]=duration }
        status="Preparing 3D Fluid…"
        do {
            guard let device else { throw LabError.message("3D is unavailable on this device.") }
            let renderer=try LabBoardRenderer(device:device,library:library)
            renderer.install(game:LabBoardGame(state:state),samples:nil)
            let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm_srgb,width:32,height:32,mipmapped:false)
            descriptor.usage=[.renderTarget,.shaderRead];descriptor.storageMode = .shared
            guard let target=device.makeTexture(descriptor:descriptor),renderer.begin(from:move.source,to:move.destination) else { throw LabError.message("This pour could not be prepared in 3D.") }
            let start=renderer.simulationTime
            for _ in 0..<1800 where renderer.game.pending != nil {
                try Task.checkCancellation()
                await renderer.encodeFrame(target:target,deltaTime:1/60).completed()
            }
            guard renderer.game.state==state.applying(move) else { throw LabError.message("3D could not complete this pour. Classic and 2D are still available.") }
            durations[.fluid]=renderer.simulationTime-start
            status="Same starting liquid and transfer. Your game is unchanged."
        } catch is CancellationError { return }
        catch { status=error.localizedDescription }
    }
    func choose(_ mode:LabBoardPresentation) {
        guard !preparing,!session.busy,durations[mode] != nil else { return }
        session.discardPreview()
        session=Self.makeSession(example:example,mode:mode,device:device,library:library)
    }
    @discardableResult func play(automaticClock:Bool=true)->Bool {
        guard !preparing,!session.busy,let duration=durations[session.presentation] else { return false }
        let mode=session.presentation
        choose(mode)
        session.comparisonSpeed=matchDuration ? duration/targetSeconds:nil
        return session.begin(example.move,automaticClock:automaticClock)
    }
    func stop() {
        let mode=session.presentation
        session.discardPreview()
        session=Self.makeSession(example:example,mode:mode,device:device,library:library)
    }
}

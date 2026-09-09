import SwiftUI
import MetalKit
import Combine

/// The puzzle and its undo history belong to this controller, not to a view.
/// Fluid rendering has a transactional copy while a pour is in flight.
@MainActor final class FluidBoardSession:ObservableObject {
    @Published private(set) var game:LabBoardGame
    @Published private(set) var presentation:LabBoardPresentation
    @Published private(set) var pace:LabBoardPace
    @Published private(set) var puzzle:LabBoardPuzzle
    @Published private(set) var renderer:LabBoardRenderer?
    @Published private(set) var classicPour:LabClassicPour?
    lazy var fluid2D=LabFluid2D(game:LabBoardGame(state:LabBoardState(layers:[])))
    @Published private(set) var planarFrame=0
    @Published var selected:Int?
    @Published var hintTarget:Int?
    @Published var phase="Choose a vial"
    @Published var notice="Tap a filled vial, then a matching color or an empty vial."
    @Published var paused=false
    @Published var slow=false { didSet { updateSpeed() } }
    @Published var points=false { didSet { renderer?.pointMode=points } }
    @Published var diagnostics=false
    @Published var orbit:Double=0.12 { didSet { renderer?.orbit=Float(orbit) } }
    @Published var metrics=LabBoardMetrics()
    @Published var correction=0
    @Published var captured:Float=0
    @Published var error:String?
    @Published private(set) var measurementActive=false
    @Published private(set) var reportURL:URL?
    @Published var soundEnabled=false { didSet { feedback.soundEnabled=soundEnabled;defaults?.set(soundEnabled,forKey:"lab.sound");updateFeedback() } }
    @Published var hapticsEnabled=true { didSet { feedback.hapticsEnabled=hapticsEnabled;defaults?.set(hapticsEnabled,forKey:"lab.haptics") } }
    @Published var quality:LabRenderQuality = .automatic { didSet { renderer?.quality=quality;defaults?.set(quality.rawValue,forKey:"lab.quality");finishMeasurement(reason:"quality changed") } }
    private let feedback=LabBoardFeedback()
    var completedPuzzleCount:Int { saved.games.values.filter { $0.state.solved }.count }
    func hasCompleted(_ puzzle:LabBoardPuzzle) -> Bool { puzzle == self.puzzle ? state.solved:(saved.games[puzzle.rawValue]?.state.solved ?? false) }
    func nextPuzzle() { if !busy,let next=puzzle.next { changePuzzle(next) } }
    let performance=LabPerformanceRecorder()
    private var trialStarted=false
    private var suspended=false
    private let defaults:UserDefaults?
    private let device:MTLDevice?
    private let library:MTLLibrary?
    private var saved:LabComparisonSave
    private var undoParticles:[[LabParticle]?]=[]
    private var settledParticles:[LabParticle]?
    private var beforeParticles:[LabParticle]?
    private var classicTask:Task<Void,Never>?
    var state:LabBoardState { game.state }
    var moveCount:Int { game.moveCount }
    var busy:Bool { game.pending != nil }
    var effectiveSpeed:Float { pace.speed*(slow ? 0.35:1) }

    init(defaults:UserDefaults? = .standard,device:MTLDevice? = MTLCreateSystemDefaultDevice(),library:MTLLibrary? = nil,restoredSave:LabComparisonSave? = nil) {
        let trial=LabTrialConfiguration.current
        self.defaults=trial == nil ? defaults:nil;self.device=device;self.library=library
        var save=self.defaults?.data(forKey:"lab.comparison.v1").flatMap { try? JSONDecoder().decode(LabComparisonSave.self,from:$0) } ?? LabComparisonSave()
        if let restoredSave { save=restoredSave }
        if let trial { save=LabComparisonSave(presentation:trial.presentation,pace:trial.pace,puzzle:trial.puzzle,games:[:]) }
        soundEnabled=self.defaults?.bool(forKey:"lab.sound") ?? false
        hapticsEnabled=self.defaults?.object(forKey:"lab.haptics") as? Bool ?? (self.defaults != nil)
        quality=trial?.quality ?? LabRenderQuality(rawValue:self.defaults?.string(forKey:"lab.quality") ?? "automatic") ?? .automatic
        saved=save;presentation=save.presentation;pace=save.pace;puzzle=save.puzzle
        var restored=save.games[save.puzzle.rawValue] ?? LabBoardGame(state:save.puzzle.initial)
        restored.cancel() // A launch restores the last committed move.
        game=restored;undoParticles=Array(repeating:nil,count:restored.moveCount)
        feedback.soundEnabled=soundEnabled;feedback.hapticsEnabled=hapticsEnabled
        if presentation == .fluid { prepareFluid() }
        if presentation == .fluid2D { fluid2D.quickMotion=pace == .quick;fluid2D.install(game);planarFrame+=1 }
        refresh()
    }
    deinit { classicTask?.cancel() }
    private func prepareFluid() {
        guard !busy else { return }
        do {
            if renderer == nil {
                guard let device else { throw LabError.message("Fluid rendering is unavailable. Classic remains playable.") }
                let engine=try LabBoardRenderer(device:device,library:library)
                engine.onFrame={ [weak self] interval,cpu,gpu in self?.performance.recordFrame(interval:interval,cpuMS:cpu,gpuMS:gpu) }
                engine.onError={ [weak self] in self?.error=$0 }
                engine.onUpdate={ [weak self] _,_,_ in self?.fluidUpdate() }
                renderer=engine
            }
            renderer?.install(game:game,samples:settledParticles)
            renderer?.quality=quality;renderer?.pointMode=points;renderer?.orbit=Float(orbit);updateSpeed();updatePause()
        } catch { self.error=error.localizedDescription;presentation = .classic }
    }
    private func checkpoint() {
        var stable=game;stable.cancel()
        saved.games[puzzle.rawValue]=stable;saved.presentation=presentation;saved.pace=pace;saved.puzzle=puzzle
        if let data=try? JSONEncoder().encode(saved) { defaults?.set(data,forKey:"lab.comparison.v1") }
    }
    func checkpointData() throws -> Data { checkpoint();return try JSONEncoder().encode(saved) }
    func changePresentation(_ value:LabBoardPresentation) {
        guard !busy,presentation != value else { return }
        finishMeasurement(reason:"presentation changed")
        if presentation == .fluid { settledParticles=renderer?.particleSamples() }
        presentation=value;error=nil
        if value == .fluid { prepareFluid() }
        else { renderer?.paused=true }
        if value == .fluid2D { fluid2D.quickMotion=pace == .quick;fluid2D.install(game);planarFrame+=1 }
        checkpoint();refresh()
    }
    func changePace(_ value:LabBoardPace) {
        guard !busy,pace != value else { return };finishMeasurement(reason:"pace changed");pace=value;updateSpeed();checkpoint()
    }
    func changePuzzle(_ value:LabBoardPuzzle) {
        guard !busy,value != puzzle else { return }
        finishMeasurement(reason:"puzzle changed");checkpoint();puzzle=value;game=saved.games[value.rawValue] ?? LabBoardGame(state:value.initial);game.cancel()
        undoParticles=Array(repeating:nil,count:game.moveCount);settledParticles=nil
        selected=nil;hintTarget=nil;paused=false;metrics=LabBoardMetrics();correction=0;captured=0
        if presentation == .fluid { prepareFluid() }
        if presentation == .fluid2D { fluid2D.quickMotion=pace == .quick;fluid2D.install(game);planarFrame+=1 }
        notice="Same puzzle and rules in all three views.";checkpoint();refresh()
    }
    func refresh() {
        updateFeedback()
        if state.solved { phase="Sorted beautifully";notice="Every color has a home. Undo to explore, or play again." }
        else if let pour=classicPour {
            phase=pour.time<0.95 ? "Moving into position":(pour.returning ? "Returning the vial":"Pouring \(pour.move.amount) \(pour.move.amount == 1 ? "unit":"units")")
        } else if busy { phase=presentation == .fluid2D ? fluid2D.phase:(renderer?.phase ?? "Pouring") }
        else { phase=moveCount>0 ? "Move complete":"Choose a vial" }
    }
    private func fluidUpdate() {
        guard presentation == .fluid,let renderer else { return }
        metrics=renderer.lastMetrics;correction=renderer.correctionCount;captured=renderer.arrivalBeforeCorrection
        if busy,renderer.game.pending == nil {
            let amount=game.pending?.amount ?? 1
            let committed=renderer.game.moveCount == game.moveCount+1
            if committed { undoParticles.append(beforeParticles);game=renderer.game;settledParticles=renderer.particleSamples() }
            else { game.cancel();notice=renderer.lastOutcome }
            performance.endMove(committed:committed,correctionPercent:Double(correction)/Double(amount*640)*100)
            if committed { feedback.completed(solved:state.solved) } else { feedback.stop() }
            beforeParticles=nil;checkpoint()
        }
        refresh()
    }
    func select(_ index:Int) {
        guard state.stacks.indices.contains(index),!busy,!state.solved else { return }
        if let source=selected {
            if source == index { selected=nil;hintTarget=nil;notice="Choose another vial.";return }
            guard let move=state.move(from:source,to:index) else {
                notice=state.stacks[index].count == state.capacity ? "That vial is full.":"Choose the same top color or an empty vial.";return
            }
            if begin(move) {
                selected=nil;hintTarget=nil
                notice="\(move.amount) \(move.amount == 1 ? "unit":"units") of \(Self.name(move.color)) · \(Self.letter(source)) → \(Self.letter(index))"
            }
        } else {
            guard !state.stacks[index].isEmpty else { notice="Choose a vial that contains liquid first.";return }
            feedback.selection();selected=index;hintTarget=nil;notice="Now choose a matching color or an empty vial."
        }
    }
    @discardableResult func begin(_ move:LabBoardMove,automaticClock:Bool = true) -> Bool {
        guard !busy,!state.solved,game.state.move(from:move.source,to:move.destination)==move else { return false }
        beforeParticles=settledParticles
        if presentation == .fluid {
            guard let renderer else { return false }
            beforeParticles=renderer.particleSamples()
            guard renderer.begin(from:move.source,to:move.destination) else { return false }
        }
        if presentation == .fluid2D { guard fluid2D.begin(move) else { return false } }
        guard game.begin(from:move.source,to:move.destination) != nil else { return false }
        paused=false;metrics=LabBoardMetrics();correction=0;captured=0;updatePause()
        performance.beginMove(presentation:presentation,pace:pace)
        if presentation == .classic { classicPour=LabClassicPour(move:move) }
        if presentation != .fluid,automaticClock { startClassicClock() }
        refresh();return true
    }
    private func startClassicClock() {
        classicTask?.cancel()
        classicTask=Task { @MainActor [weak self] in
            var last=ProcessInfo.processInfo.systemUptime
            while !Task.isCancelled {
                try? await Task.sleep(for:.milliseconds(16))
                guard !Task.isCancelled,let self,self.busy,self.presentation != .fluid else { return }
                let now=ProcessInfo.processInfo.systemUptime
                if self.presentation == .fluid2D { self.advance2D(deltaTime:Float(now-last)) }
                else { self.advanceClassic(deltaTime:Float(now-last)) };last=now
            }
        }
    }
    func advance2D(deltaTime:Float) {
        guard presentation == .fluid2D,busy,!paused,!suspended else { return }
        fluid2D.advance(deltaTime:deltaTime,speed:effectiveSpeed);planarFrame+=1
        if !fluid2D.busy {
            let committed=fluid2D.game.moveCount==game.moveCount+1
            if committed {
                game=fluid2D.game;undoParticles.append(beforeParticles);settledParticles=nil
                feedback.completed(solved:state.solved)
            } else { game.cancel();notice=fluid2D.lastOutcome;feedback.stop() }
            performance.endMove(committed:committed,correctionPercent:Double(fluid2D.cleanupPercent))
            beforeParticles=nil;classicTask?.cancel();classicTask=nil;checkpoint()
        }
        performance.recordFrame(interval:Double(deltaTime),cpuMS:fluid2D.cpuMilliseconds,gpuMS:nil)
        refresh()
    }
    func advanceClassic(deltaTime:Float) {
        guard !paused,!suspended,var pour=classicPour else { return }
        let updateStart=ProcessInfo.processInfo.systemUptime
        pour.time+=min(max(deltaTime,0),0.05)*effectiveSpeed
        if pour.finished {
            guard game.commit(pour.move) else { return }
            performance.endMove(committed:true,correctionPercent:0)
            feedback.completed(solved:state.solved)
            undoParticles.append(beforeParticles);beforeParticles=nil;settledParticles=nil
            classicPour=nil;classicTask?.cancel();classicTask=nil;checkpoint()
        } else { classicPour=pour }
        refresh()
        performance.recordFrame(interval:Double(deltaTime),cpuMS:(ProcessInfo.processInfo.systemUptime-updateStart)*1000,gpuMS:nil)
    }
    func reset() {
        feedback.stop()
        classicTask?.cancel();classicTask=nil;classicPour=nil
        game=LabBoardGame(state:puzzle.initial);undoParticles=[];settledParticles=nil;beforeParticles=nil
        renderer?.reset(state:puzzle.initial)
        if presentation == .fluid2D { fluid2D.quickMotion=pace == .quick;fluid2D.install(game);planarFrame+=1 }
        selected=nil;hintTarget=nil;paused=false;metrics=LabBoardMetrics();correction=0;captured=0
        notice="Tap a filled vial, then a matching color or an empty vial.";updatePause();checkpoint();refresh()
    }
    func undo() {
        guard !busy,game.undo() else { return }
        settledParticles=undoParticles.isEmpty ? nil:undoParticles.removeLast()
        if presentation == .fluid { prepareFluid() }
        if presentation == .fluid2D { fluid2D.quickMotion=pace == .quick;fluid2D.install(game);planarFrame+=1 }
        selected=nil;hintTarget=nil;paused=false;metrics=LabBoardMetrics();correction=0;captured=0
        notice="Move undone. Try a different route.";updatePause();checkpoint();refresh()
    }
    func hint() {
        guard !busy,!state.solved else { return }
        if let move=state.solution()?.first {
            selected=move.source;hintTarget=move.destination
            notice="Try \(Self.letter(move.source)) → \(Self.letter(move.destination)) · \(move.amount) \(Self.name(move.color)) \(move.amount == 1 ? "unit":"units")"
        } else { notice="No solution from here. Undo a move to try another route." }
    }
    func setSuspended(_ value:Bool) { suspended=value;updatePause() }
    func togglePause() { paused.toggle();updatePause() }
    private func updatePause() { renderer?.paused=paused || suspended || presentation != .fluid;updateFeedback() }
    private func updateFeedback() {
        let visibleStream:Bool
        if let pour=classicPour { visibleStream=pour.progress>0 && pour.progress<1 }
        else if presentation == .fluid2D { visibleStream=busy && fluid2D.departed>0 && fluid2D.cutoff==nil }
        else { visibleStream=busy && (renderer?.lastMetrics.departed ?? 0)>20 && renderer?.cutoffTime == nil }
        feedback.setPouring(visibleStream && !paused && !suspended)
    }
    private func beginMeasurement() {
        performance.context=["puzzle":puzzle.rawValue,"vialCount":state.stacks.count,"colorCount":Set(state.colors).count,"quality":quality.rawValue,"maximumRenderDimension":quality.maximumDimension,"particleCount":presentation == .fluid ? (renderer?.particleCount ?? 0):(presentation == .fluid2D ? fluid2D.particles.count:0)]
        if presentation == .fluid2D {
            performance.context["quality"]="canvas-native"
            performance.context.removeValue(forKey:"maximumRenderDimension")
            performance.context["frameCounter"]="controller updates, not compositor presents"
            performance.context["cpuCounter"]="2D solver only; excludes Canvas drawing"
        }
        performance.begin(presentation:presentation,pace:pace);measurementActive=true;reportURL=nil
    }
    private func updateSpeed() { renderer?.playbackSpeed=effectiveSpeed;if presentation == .fluid2D { fluid2D.quickMotion=pace == .quick } }
    func toggleMeasurement() {
        if measurementActive { finishMeasurement() }
        else { beginMeasurement() }
    }
    private func finishMeasurement(filename:String? = nil,reason:String="completed") {
        guard measurementActive else { return }
        do { reportURL=try performance.finish(filename:filename,reason:reason) }
        catch { self.error=error.localizedDescription }
        measurementActive=false
    }
    func runTrialIfRequested() async {
        guard !trialStarted,let trial=LabTrialConfiguration.current else { return }
        trialStarted=true
        #if os(iOS)
        let previousIdleTimer=UIApplication.shared.isIdleTimerDisabled
        if ProcessInfo.processInfo.arguments.contains("--keep-awake") { UIApplication.shared.isIdleTimerDisabled=true }
        defer { UIApplication.shared.isIdleTimerDisabled=previousIdleTimer }
        #endif
        try? await Task.sleep(for:.seconds(2))
        beginMeasurement()
        let start=ProcessInfo.processInfo.systemUptime
        var reason="completed"
        while !Task.isCancelled && ProcessInfo.processInfo.systemUptime-start<trial.seconds {
            if suspended { reason="application suspended";break }
            if !busy {
                if state.solved { reset() }
                guard let move=state.solution()?.first,begin(move) else { reason="no legal continuation";break }
            }
            try? await Task.sleep(for:.milliseconds(100))
        }
        if Task.isCancelled { reason="cancelled" }
        // Do not count an unfinished move as a successful transfer.
        paused=true;updatePause()
        finishMeasurement(filename:"trial-\(trial.puzzle.rawValue)-\(trial.presentation.rawValue)-\(trial.pace.rawValue)-\(trial.quality.rawValue)",reason:reason)
        notice="Measurement saved. Reset to play again."
        #if os(macOS)
        if ProcessInfo.processInfo.arguments.contains("--exit-after-trial") { NSApplication.shared.terminate(nil) }
        #endif
    }

    static func letter(_ index:Int) -> String { String(UnicodeScalar(65+index)!) }
    static func name(_ color:Int) -> String { color == 0 ? "Tide":(color == 1 ? "Ember":"Leaf") }
    static func color(_ value:Int) -> Color { value == 0 ? Color(red:0.05,green:0.58,blue:0.86):(value == 1 ? Color(red:0.96,green:0.34,blue:0.07):Color(red:0.20,green:0.76,blue:0.36)) }
    func accessibility(_ index:Int) -> String {
        let layers=state.stacks[index].reversed().map { Self.name(state.colors[$0]) }.joined(separator:", ")
        return "Vial \(Self.letter(index)), \(state.stacks[index].count) of 4 units. \(layers.isEmpty ? "Empty":"Top to bottom: "+layers)."
    }
}

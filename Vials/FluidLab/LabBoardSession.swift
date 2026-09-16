import SwiftUI
import MetalKit
import Combine

/// Only liquid drawing and its optional diagnostics observe these snapshots.
/// Keeping this publisher separate prevents particle frames from rebuilding controls.
@MainActor final class LabPlanarDisplay:ObservableObject {
    @Published private(set) var snapshot=LabFluid2D(game:LabBoardGame(state:LabBoardState(layers:[])))
    private(set) var frame=0
    fileprivate func publish(_ value:LabFluid2D) { frame+=1;snapshot=value }
}

/// The puzzle and its undo history belong to this controller, not to a view.
/// Fluid rendering has a transactional copy while a pour is in flight.
@MainActor final class FluidBoardSession:ObservableObject {
    @Published private(set) var game:LabBoardGame
    @Published private(set) var presentation:LabBoardPresentation
    @Published private(set) var pace:LabBoardPace
    @Published private(set) var puzzle:LabBoardPuzzle
    @Published private(set) var renderer:LabBoardRenderer?
    @Published private(set) var classicPour:LabClassicPour?
    let allowsConcurrentPours:Bool
    @Published private(set) var pourQueue=LabPourQueue()
    @Published private(set) var concurrentClassicPours:[LabClassicPour]=[]
    private var concurrentExamples:[Int:LabPourExample]=[:]
    private var classicLanes:[Int:LabClassicPour]=[:]
    private var metalGroups:[Int:LabBoardRenderer]=[:]
    private var metalPool:[LabBoardRenderer]=[]
    private var compositeSamples:[LabParticle]=[]
    private var concurrentFrame=0
    private var concurrentWorker:LabConcurrent2DWorker?
    var activeMoves:[LabBoardMove] { allowsConcurrentPours ? pourQueue.items.map(\.move):[game.pending].compactMap { $0 } }
    var solved:Bool { state.solved && !busy }
    func canTap(_ index:Int)->Bool {
        guard !solved else { return false }
        if !allowsConcurrentPours { return !busy }
        return selected == nil ? !pourQueue.lockedSources.contains(index):!pourQueue.movingSources.contains(index)
    }
    func availableMove(from:Int,to:Int)->LabBoardMove? {
        allowsConcurrentPours ? pourQueue.move(from:from,to:to,state:state):state.move(from:from,to:to)
    }
    lazy var fluid2D=LabFluid2D(game:LabBoardGame(state:LabBoardState(layers:[])))
    let planarDisplay=LabPlanarDisplay()
    @Published private(set) var rejectedVial:Int?
    @Published private(set) var lastPour:LabPourExample?
    private var pendingExample:LabPourExample?
    private var rejectionTask:Task<Void,Never>?
    // Used only by the disposable comparison session to align playback duration.
    var comparisonSpeed:Float? { didSet { updateSpeed() } }
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
    private var clockRevision=0
    var state:LabBoardState { game.state }
    var moveCount:Int { game.moveCount }
    var busy:Bool { game.pending != nil || pourQueue.busy }
    var effectiveSpeed:Float { (comparisonSpeed ?? pace.speed)*(slow ? 0.35:1) }
    var validDestinations:Set<Int> {
        guard let selected,allowsConcurrentPours || !busy else { return [] }
        return Set(state.stacks.indices.filter { availableMove(from:selected,to:$0) != nil })
    }
    func vialComplete(_ index:Int)->Bool {
        state.isComplete(index)
    }
    // Menu availability must not run a puzzle search on every board redraw.
    var canComparePour:Bool {
        guard !busy else { return false }
        if lastPour != nil { return true }
        guard !state.solved else { return false }
        let sources=selected.map { [$0] } ?? Array(state.stacks.indices)
        return sources.contains { source in state.stacks.indices.contains { state.move(from:source,to:$0) != nil } }
    }
    var comparisonExample:LabPourExample? {
        guard !busy else { return nil }
        if let lastPour { return lastPour }
        let move:LabBoardMove?
        if let selected {
            move=state.stacks.indices.compactMap { state.move(from:selected,to:$0) }.first
        } else {
            move=state.solution()?.first ?? state.stacks.indices.compactMap { source in
                state.stacks.indices.compactMap { state.move(from:source,to:$0) }.first
            }.first
        }
        return move.map { LabPourExample(puzzle:puzzle,state:state,move:$0) }
    }
    private func reject(_ index:Int) {
        rejectionTask?.cancel();rejectedVial=index
        rejectionTask=Task { @MainActor [weak self] in
            try? await Task.sleep(for:.milliseconds(850))
            guard !Task.isCancelled else { return };self?.rejectedVial=nil
        }
    }
    private func clearSelectionFeedback() { rejectionTask?.cancel();rejectedVial=nil }
    private func rememberPour(_ committed:Bool) {
        if committed { lastPour=pendingExample };pendingExample=nil
    }

    init(defaults:UserDefaults? = .standard,device:MTLDevice? = MTLCreateSystemDefaultDevice(),library:MTLLibrary? = nil,restoredSave:LabComparisonSave? = nil,allowsConcurrentPours:Bool=false) {
        self.allowsConcurrentPours=allowsConcurrentPours
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
        if presentation == .fluid2D { fluid2D.quickMotion=pace == .quick;fluid2D.install(game);planarDisplay.publish(fluid2D) }
        refresh()
    }
    deinit { classicTask?.cancel();rejectionTask?.cancel() }
    private func prepareFluid() {
        guard !busy else { return }
        do {
            if renderer == nil {
                guard let device else { throw LabError.message("Fluid rendering is unavailable. Classic remains playable.") }
                let engine=try LabBoardRenderer(device:device,library:library)
                engine.onFrame={ [weak self] interval,cpu,gpu in
                    guard let self,!self.allowsConcurrentPours else { return }
                    self.performance.recordFrame(interval:interval,cpuMS:cpu,gpuMS:gpu)
                }
                engine.onError={ [weak self] in self?.error=$0 }
                engine.onUpdate={ [weak self] _,_,_ in self?.fluidUpdate() }
                renderer=engine
            }
            renderer?.install(game:game,samples:settledParticles)
            if allowsConcurrentPours,let renderer {
                compositeSamples=renderer.particleSamples()
                if metalPool.isEmpty { metalPool=try (0..<2).map { _ in try LabBoardRenderer(simulationCopyOf:renderer) } }
            }
            renderer?.quality=quality;renderer?.pointMode=points;renderer?.orbit=Float(orbit);updateSpeed();updatePause()
        } catch { self.error=error.localizedDescription;presentation = .classic }
    }
    private func checkpoint() {
        performance.traceBegin("Checkpoint");defer { performance.traceEnd("Checkpoint") }
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
        if value == .fluid2D { fluid2D.quickMotion=pace == .quick;fluid2D.install(game);planarDisplay.publish(fluid2D) }
        checkpoint();refresh()
    }
    func changePace(_ value:LabBoardPace) {
        guard !busy,pace != value else { return };finishMeasurement(reason:"pace changed");pace=value;updateSpeed();checkpoint()
    }
    func changePuzzle(_ value:LabBoardPuzzle) {
        guard !busy,value != puzzle else { return }
        lastPour=nil;pendingExample=nil;clearSelectionFeedback()
        finishMeasurement(reason:"puzzle changed");checkpoint();puzzle=value;game=saved.games[value.rawValue] ?? LabBoardGame(state:value.initial);game.cancel()
        undoParticles=Array(repeating:nil,count:game.moveCount);settledParticles=nil
        selected=nil;hintTarget=nil;paused=false;metrics=LabBoardMetrics();correction=0;captured=0
        if presentation == .fluid { prepareFluid() }
        if presentation == .fluid2D { fluid2D.quickMotion=pace == .quick;fluid2D.install(game);planarDisplay.publish(fluid2D) }
        notice="Same puzzle and rules in all three views.";checkpoint();refresh()
    }
    func refresh() {
        updateFeedback()
        let nextPhase:String
        if solved {
            nextPhase="Sorted beautifully"
            let solvedNotice="Every color has a home. Undo to explore, or play again."
            if notice != solvedNotice { notice=solvedNotice }
        } else if allowsConcurrentPours,busy {
            let active=pourQueue.active.count,waiting=pourQueue.items.count-active
            nextPhase="\(active) \(active == 1 ? "pour":"pours")"+(waiting>0 ? " · \(waiting) queued":"")
        } else if let pour=classicPour {
            nextPhase=pour.time<0.95 ? "Moving into position":(pour.returning ? "Returning the vial":"Pouring \(pour.move.amount) \(pour.move.amount == 1 ? "unit":"units")")
        } else if busy { nextPhase=presentation == .fluid2D ? fluid2D.phase:(renderer?.phase ?? "Pouring") }
        else { nextPhase=moveCount>0 ? "Move complete":"Choose a vial" }
        if phase != nextPhase { phase=nextPhase;performance.tracePhase(nextPhase) }
    }
    private func fluidUpdate() {
        guard !allowsConcurrentPours,presentation == .fluid,let renderer else { return }
        metrics=renderer.lastMetrics;correction=renderer.correctionCount;captured=renderer.arrivalBeforeCorrection
        if busy,renderer.game.pending == nil {
            let amount=game.pending?.amount ?? 1
            let committed=renderer.game.moveCount == game.moveCount+1
            if committed { undoParticles.append(beforeParticles);game=renderer.game;settledParticles=renderer.particleSamples() }
            else { game.cancel();notice=renderer.lastOutcome }
            rememberPour(committed)
            performance.endMove(committed:committed,correctionPercent:Double(correction)/Double(amount*640)*100)
            if committed { feedback.completed(solved:state.solved) } else { feedback.stop() }
            beforeParticles=nil;checkpoint()
        }
        refresh()
    }
    func select(_ index:Int) {
        guard state.stacks.indices.contains(index),allowsConcurrentPours || !busy,!solved else { return }
        if let source=selected {
            if source == index { clearSelectionFeedback();selected=nil;hintTarget=nil;notice="Choose another vial.";return }
            guard let move=availableMove(from:source,to:index) else {
                reject(index)
                if allowsConcurrentPours,pourQueue.movingSources.contains(index) { notice="That vial is already pouring or queued." }
                else if pourQueue.projected(state).stacks[index].count == state.capacity { notice="That vial is full or its remaining space is reserved." }
                else { notice="Choose the same top color or an empty vial." }
                return
            }
            if begin(move) {
                selected=nil;hintTarget=nil
                notice="\(move.amount) \(move.amount == 1 ? "unit":"units") of \(Self.name(move.color)) · \(Self.letter(source)) → \(Self.letter(index))"
            }
        } else {
            guard !allowsConcurrentPours || !pourQueue.lockedSources.contains(index) else { reject(index);notice="That vial is already in use.";return }
            guard !state.stacks[index].isEmpty else { reject(index);notice="Choose a vial that contains liquid first.";return }
            clearSelectionFeedback();feedback.selection();selected=index;hintTarget=nil;notice="Now choose a matching color or an empty vial."
        }
    }
    @discardableResult func begin(_ move:LabBoardMove,automaticClock:Bool = true) -> Bool {
        if allowsConcurrentPours { return beginConcurrent(move,automaticClock:automaticClock) }
        guard !busy,!state.solved,game.state.move(from:move.source,to:move.destination)==move else { return false }
        performance.traceBegin("Begin pour");defer { performance.traceEnd("Begin pour") }
        beforeParticles=settledParticles
        if presentation == .fluid {
            guard let renderer else { return false }
            beforeParticles=renderer.particleSamples()
            guard renderer.begin(from:move.source,to:move.destination) else { return false }
        }
        if presentation == .fluid2D { guard fluid2D.begin(move) else { return false } }
        guard game.begin(from:move.source,to:move.destination) != nil else { return false }
        clearSelectionFeedback();pendingExample=LabPourExample(puzzle:puzzle,state:state,move:move)
        paused=false;metrics=LabBoardMetrics();correction=0;captured=0;updatePause()
        performance.beginMove(presentation:presentation,pace:pace)
        if presentation == .classic { classicPour=LabClassicPour(move:move) }
        if automaticClock {
            if presentation == .fluid2D { startPlanarClock() }
            else if presentation == .classic { startClassicClock() }
        }
        refresh();return true
    }
    private func startPlanarClock() {
        classicTask?.cancel()
        let worker=Lab2DWorker(fluid2D)
        classicTask=Task { @MainActor [weak self] in
            var last=ProcessInfo.processInfo.systemUptime
            while !Task.isCancelled {
                guard let self,self.busy,self.presentation == .fluid2D else { return }
                if self.paused || self.suspended {
                    try? await Task.sleep(for:.milliseconds(16))
                    last=ProcessInfo.processInfo.systemUptime
                    continue
                }
                let started=ProcessInfo.processInfo.systemUptime
                let delta=Float(started-last),revision=self.clockRevision
                last=started
                let frame=await worker.advance(deltaTime:delta,speed:self.effectiveSpeed)
                guard !Task.isCancelled else { return } // Reset invalidates an in-flight result.
                if revision != self.clockRevision {
                    // Pause/suspension may arrive while physics runs. Keep the
                    // displayed state and restart the clock upon resuming.
                    await worker.replace(self.fluid2D)
                    last=ProcessInfo.processInfo.systemUptime
                    continue
                }
                self.fluid2D=frame
                self.finishPlanarFrame(deltaTime:delta)
                let remaining=1.0/60-(ProcessInfo.processInfo.systemUptime-started)
                if remaining>0 { try? await Task.sleep(for:.seconds(remaining)) }
                else { await Task.yield() }
            }
        }
    }
    private func startClassicClock() {
        classicTask?.cancel()
        classicTask=Task { @MainActor [weak self] in
            var last=ProcessInfo.processInfo.systemUptime
            while !Task.isCancelled {
                try? await Task.sleep(for:.milliseconds(16))
                guard !Task.isCancelled,let self,self.busy,self.presentation == .classic else { return }
                let now=ProcessInfo.processInfo.systemUptime
                self.advanceClassic(deltaTime:Float(now-last));last=now
            }
        }
    }
    func advance2D(deltaTime:Float) {
        guard presentation == .fluid2D,busy,!paused,!suspended else { return }
        fluid2D.advance(deltaTime:deltaTime,speed:effectiveSpeed)
        finishPlanarFrame(deltaTime:deltaTime)
    }
    private func finishPlanarFrame(deltaTime:Float) {
        if measurementActive {
            let previous=performance.context["maximumSimulationBacklogSeconds"] as? Float ?? 0
            performance.context["maximumSimulationBacklogSeconds"]=max(previous,fluid2D.pendingSimulationSeconds)
        }
        planarDisplay.publish(fluid2D)
        if !fluid2D.busy {
            let committed=fluid2D.game.moveCount==game.moveCount+1
            if committed {
                game=fluid2D.game;undoParticles.append(beforeParticles);settledParticles=nil
                feedback.completed(solved:state.solved)
            } else { game.cancel();notice=fluid2D.lastOutcome;feedback.stop() }
            rememberPour(committed)
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
            rememberPour(true)
            performance.endMove(committed:true,correctionPercent:0)
            feedback.completed(solved:state.solved)
            undoParticles.append(beforeParticles);beforeParticles=nil;settledParticles=nil
            classicPour=nil;classicTask?.cancel();classicTask=nil;checkpoint()
        } else { classicPour=pour }
        refresh()
        performance.recordFrame(interval:Double(deltaTime),cpuMS:(ProcessInfo.processInfo.systemUptime-updateStart)*1000,gpuMS:nil)
    }
    func reset() {
        cancelConcurrent()
        lastPour=nil;pendingExample=nil;clearSelectionFeedback()
        feedback.stop()
        classicTask?.cancel();classicTask=nil;classicPour=nil
        game=LabBoardGame(state:puzzle.initial);undoParticles=[];settledParticles=nil;beforeParticles=nil
        renderer?.reset(state:puzzle.initial)
        if presentation == .fluid2D { fluid2D.quickMotion=pace == .quick;fluid2D.install(game);planarDisplay.publish(fluid2D) }
        selected=nil;hintTarget=nil;paused=false;metrics=LabBoardMetrics();correction=0;captured=0
        notice="Tap a filled vial, then a matching color or an empty vial.";updatePause();checkpoint();refresh()
    }
    /// Clears every saved board, not just the currently selected puzzle.
    /// reset() invalidates in-flight worker results before the fresh checkpoint.
    func resetAllProgress() {
        finishMeasurement(reason:"all progress reset")
        saved=LabComparisonSave()
        puzzle=saved.puzzle;presentation=saved.presentation;pace=saved.pace
        comparisonSpeed=nil;slow=false;points=false;diagnostics=false;orbit=0.12
        error=nil;reportURL=nil
        reset()
        fluid2D.quickMotion=false;fluid2D.install(game);planarDisplay.publish(fluid2D)
        prepareFluid()
        checkpoint()
        notice="All progress reset. Tap a filled vial to begin."
    }
    func undo() {
        guard !busy,game.undo() else { return }
        lastPour=nil;pendingExample=nil;clearSelectionFeedback()
        settledParticles=undoParticles.isEmpty ? nil:undoParticles.removeLast()
        if presentation == .fluid { prepareFluid() }
        if presentation == .fluid2D { fluid2D.quickMotion=pace == .quick;fluid2D.install(game);planarDisplay.publish(fluid2D) }
        selected=nil;hintTarget=nil;paused=false;metrics=LabBoardMetrics();correction=0;captured=0
        notice="Move undone. Try a different route.";updatePause();checkpoint();refresh()
    }
    func hint() {
        guard !busy,!state.solved else { return }
        clearSelectionFeedback()
        if let move=state.solution()?.first {
            selected=move.source;hintTarget=move.destination
            notice="Try \(Self.letter(move.source)) → \(Self.letter(move.destination)) · \(move.amount) \(Self.name(move.color)) \(move.amount == 1 ? "unit":"units")"
        } else { notice="No solution from here. Undo a move to try another route." }
    }
    // A dismissed preview must release its clock even when it closes mid-pour.
    func discardPreview() {
        guard defaults == nil else { return }
        cancelConcurrent()
        classicTask?.cancel();classicTask=nil;clockRevision+=1
        game.cancel();classicPour=nil;renderer?.paused=true;suspended=true;feedback.stop()
    }
    func setSuspended(_ value:Bool) { suspended=value;updatePause() }
    func togglePause() { paused.toggle();updatePause() }
    private func updatePause() { clockRevision+=1;renderer?.paused=paused || suspended || presentation != .fluid;updateFeedback() }
    private func updateFeedback() {
        let visibleStream:Bool
        if allowsConcurrentPours {
            switch presentation {
            case .classic: visibleStream=concurrentClassicPours.contains { $0.progress>0 && $0.progress<1 }
            case .fluid2D: visibleStream=fluid2D.streamActive
            case .fluid: visibleStream=metalGroups.values.contains { $0.groupStreamActive }
            }
        } else if let pour=classicPour { visibleStream=pour.progress>0 && pour.progress<1 }
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
            performance.context["cpuCounter"]="2D worker solver only; excludes Canvas drawing"
            performance.context["physicsExecution"]="isolated actor, immutable value snapshots"
        }
        if allowsConcurrentPours {
            performance.context["concurrentPourLimit"]=2
            performance.context["frameCounter"]="concurrent controller updates, not compositor presents"
            if presentation == .fluid { performance.context["cpuCounter"]="simulation scheduling and GPU waits; excludes surface rendering" }
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
    // Explicit diagnostic flag: exercise the same actions as the board controls
    // on the device, outside the timed/battery sample and without saved progress.
    private func checkTrialControls() async -> [String:Bool] {
        if allowsConcurrentPours { return await checkConcurrentControls() }
        guard presentation == .fluid2D,let move=state.solution()?.first else { return [:] }
        let initial=state
        guard begin(move) else { return ["begin":false] }
        try? await Task.sleep(for:.milliseconds(200))
        togglePause();let frozen=fluid2D
        try? await Task.sleep(for:.milliseconds(200))
        let pauseOK=fluid2D.time==frozen.time && fluid2D.particles==frozen.particles && fluid2D.surfaces==frozen.surfaces && fluid2D.splashes==frozen.splashes
        togglePause();setSuspended(true);let suspendedTime=fluid2D.time
        try? await Task.sleep(for:.milliseconds(200))
        let suspendOK=fluid2D.time==suspendedTime
        setSuspended(false)
        try? await Task.sleep(for:.milliseconds(150))
        let resumeOK=fluid2D.time>suspendedTime
        reset()
        try? await Task.sleep(for:.milliseconds(100))
        let resetOK=state==initial && !busy && fluid2D.time==0
        let began=begin(move)
        for _ in 0..<600 where busy && !Task.isCancelled { try? await Task.sleep(for:.milliseconds(16)) }
        let commitOK=began && state==initial.applying(move) && !busy
        undo();let undoOK=state==initial && !busy
        let reloaded=(try? checkpointData()).flatMap { try? JSONDecoder().decode(LabComparisonSave.self,from:$0) }
        let saveOK=reloaded?.games[puzzle.rawValue]?.state==initial
        reset()
        return ["pause":pauseOK,"suspension":suspendOK,"resume":resumeOK,"reset":resetOK,"commit":commitOK,"undo":undoOK,"saveReload":saveOK]
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
        let checks=ProcessInfo.processInfo.arguments.contains("--check-controls") ? await checkTrialControls():[:]
        beginMeasurement()
        if !checks.isEmpty { performance.context["deviceControlChecks"]=checks }
        let start=ProcessInfo.processInfo.systemUptime
        var reason="completed"
        while !Task.isCancelled && ProcessInfo.processInfo.systemUptime-start<trial.seconds {
            if suspended { reason="application suspended";break }
            if allowsConcurrentPours,ProcessInfo.processInfo.arguments.contains("--concurrent-pours") {
                if solved { reset() }
                if pourQueue.items.count<2 {
                    let projected=pourQueue.projected(state)
                    let options=state.stacks.indices.flatMap { a in state.stacks.indices.compactMap { b in availableMove(from:a,to:b) } }.sorted { a,b in
                        let receivers=Set(pourQueue.active.map {$0.move.destination})
                        return receivers.contains(a.destination) && !receivers.contains(b.destination)
                    }
                    if let next=options.first(where:{ move in
                        !(projected.stacks[move.destination].isEmpty && Set(projected.stacks[move.source].map { projected.colors[$0] }).count==1) && projected.applying(move)?.solution() != nil
                    }) { _=begin(next) }
                }
            } else if !busy {
                if state.solved { reset() }
                guard let move=state.solution()?.first,begin(move) else { reason="no legal continuation";break }
            }
            try? await Task.sleep(for:.milliseconds(100))
        }
        if Task.isCancelled { reason="cancelled" }
        // Stop accepting work, then let the final visible pours return home.
        // If the app was suspended, retain the measured interval and restore its
        // committed board instead of leaving the diagnostic app frozen mid-pour.
        if reason=="completed" {
            performance.context["requestedDurationSeconds"]=trial.seconds
            let drainStart=ProcessInfo.processInfo.systemUptime
            while busy && !suspended && !Task.isCancelled && ProcessInfo.processInfo.systemUptime-drainStart<20 {
                try? await Task.sleep(for:.milliseconds(50))
            }
            performance.context["drainSeconds"]=ProcessInfo.processInfo.systemUptime-drainStart
        }
        paused=true;updatePause()
        finishMeasurement(filename:"trial-\(trial.puzzle.rawValue)-\(trial.presentation.rawValue)-\(trial.pace.rawValue)-\(trial.quality.rawValue)",reason:reason)
        if busy {
            cancelConcurrent();game.cancel();classicPour=nil
            if presentation == .fluid2D {fluid2D.install(game);planarDisplay.publish(fluid2D)}
            if presentation == .fluid {renderer?.install(game:game);renderer?.paused=true}
        }
        refresh()
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

extension FluidBoardSession {
    @discardableResult private func beginConcurrent(_ move:LabBoardMove,automaticClock:Bool)->Bool {
        guard !solved else { return false }
        let wasBusy=busy,example=LabPourExample(puzzle:puzzle,state:pourQueue.projected(state),move:move)
        guard pourQueue.reserve(move,state:state),let item=pourQueue.items.last else { return false }
        concurrentExamples[item.id]=example;clearSelectionFeedback()
        if !wasBusy {
            paused=false;updatePause()
            if presentation == .fluid2D { concurrentWorker=LabConcurrent2DWorker(fluid2D) }
            if presentation == .fluid { compositeSamples=renderer?.particleSamples() ?? [] }
            if automaticClock { startConcurrentClock() }
        }
        refresh();return true
    }
    private func startConcurrentClock() {
        classicTask?.cancel()
        let initialRevision=clockRevision
        classicTask=Task { @MainActor [weak self] in
            var last=ProcessInfo.processInfo.systemUptime,revision=initialRevision
            while !Task.isCancelled {
                guard let self,self.busy else { return }
                let now=ProcessInfo.processInfo.systemUptime
                // Background suspension can stop the task itself. Never turn that
                // wall-clock gap into simulation debt on the first resumed tick.
                let delta=revision==self.clockRevision ? Float(now-last):0
                last=now;revision=self.clockRevision
                if !self.paused && !self.suspended { await self.advanceConcurrent(deltaTime:delta) }
                let remaining=1.0/60-(ProcessInfo.processInfo.systemUptime-now)
                if remaining>0 { try? await Task.sleep(for:.seconds(remaining)) } else { await Task.yield() }
            }
        }
    }
    /// Shared by the live clock and deterministic multi-pour regression checks.
    func advanceConcurrent(deltaTime:Float) async {
        guard allowsConcurrentPours,busy,!paused,!suspended else { return }
        var queue=pourQueue
        let starts=queue.startReady()
        if !starts.isEmpty { pourQueue=queue }
        let revision=clockRevision
        let updateStart=ProcessInfo.processInfo.systemUptime
        for item in starts { performance.beginConcurrentMove(id:item.id,presentation:presentation,pace:pace) }
        if presentation == .fluid2D {
            guard let worker=concurrentWorker else { return }
            let frame=await worker.advance(game:game,starts:starts,deltaTime:deltaTime,speed:effectiveSpeed)
            guard !Task.isCancelled else { return }
            if revision != clockRevision {
                await worker.rollbackLastAdvance()
                pourQueue.unstart(Set(starts.map(\.id)))
                return
            }
            fluid2D=frame.display
            for result in frame.finished { finishConcurrent(result) }
            fluid2D.setDisplayGame(game);planarDisplay.publish(fluid2D)
            performance.recordFrame(interval:Double(deltaTime),cpuMS:fluid2D.cpuMilliseconds,gpuMS:nil)
        } else if presentation == .classic {
            for item in starts {
                guard state.applyingReserved(item.move) != nil else {
                    finishConcurrent(LabLaneResult(id:item.id,committed:false,cleanup:0));continue
                }
                classicLanes[item.id]=LabClassicPour(move:item.move,approach:item.approach)
            }
            var finished:[Int]=[]
            for id in classicLanes.keys.sorted() {
                classicLanes[id]!.time+=min(max(deltaTime,0),0.05)*effectiveSpeed
                if classicLanes[id]!.finished { finished.append(id) }
            }
            for id in finished { classicLanes[id]=nil;finishConcurrent(LabLaneResult(id:id,committed:true,cleanup:0)) }
            concurrentClassicPours=classicLanes.keys.sorted().compactMap { classicLanes[$0] }
            performance.recordFrame(interval:Double(deltaTime),cpuMS:(ProcessInfo.processInfo.systemUptime-updateStart)*1000,gpuMS:nil)
        } else if let renderer {
            for item in starts where metalGroups[item.move.destination]==nil {
                guard let engine=metalPool.popLast() else { finishConcurrent(LabLaneResult(id:item.id,committed:false,cleanup:0));continue }
                engine.installSimulation(game:game,samples:compositeSamples,vessels:item.vessels)
                metalGroups[item.move.destination]=engine
            }
            var vessels=LabBoardLayout.vessels(profiles:renderer.profiles,move:nil,time:0,tilt:0,cutoffTilt:nil,cutoffElapsed:0,returnElapsed:nil)
            var aggregate=LabBoardMetrics();aggregate.gpuMilliseconds=renderer.lastGPUWorkMilliseconds
            var completed:[LabLaneResult]=[],empty:[Int]=[]
            for receiver in metalGroups.keys.sorted() {
                let engine=metalGroups[receiver]!
                engine.playbackSpeed=effectiveSpeed
                engine.advanceGroup(game:game,starts:starts.filter {$0.move.destination==receiver},samples:compositeSamples,deltaTime:deltaTime)
                let samples=engine.particleSamples(),ids=engine.groupOwnedParcels
                aggregate.gpuMilliseconds+=engine.lastGPUWorkMilliseconds
                aggregate.arrived+=engine.lastMetrics.arrived;aggregate.departed+=engine.lastMetrics.departed;aggregate.guided+=engine.lastMetrics.guided
                aggregate.outside+=engine.lastMetrics.outside;aggregate.wrongParcel+=engine.lastMetrics.wrongParcel;aggregate.nonFinite+=engine.lastMetrics.nonFinite
                compositeSamples.removeAll {ids.contains(Int($0.visual.y))};compositeSamples+=samples.filter {ids.contains(Int($0.visual.y))}
                for owner in Set(engine.groupMoves.flatMap {[$0.source,$0.destination]}+engine.groupResults.flatMap(\.vessels)) {vessels[owner]=engine.currentVessels[owner]}
                completed+=engine.groupResults
                if engine.groupMoves.isEmpty {empty.append(receiver)}
            }
            for result in completed { finishConcurrent(result) }
            for receiver in empty {if let engine=metalGroups.removeValue(forKey:receiver) {metalPool.append(engine)}}
            concurrentFrame+=1
            if concurrentFrame%15==0 || !busy { metrics=aggregate }
            renderer.displayComposite(game:game,samples:compositeSamples,vessels:vessels)
            if !busy { settledParticles=compositeSamples }
            performance.recordFrame(interval:Double(deltaTime),cpuMS:(ProcessInfo.processInfo.systemUptime-updateStart)*1000,gpuMS:aggregate.gpuMilliseconds)
        }
        if measurementActive {
            performance.context["maximumConcurrentPours"]=max(performance.context["maximumConcurrentPours"] as? Int ?? 0,pourQueue.active.count)
            let shared=Dictionary(grouping:pourQueue.active,by:{$0.move.destination}).values.map(\.count).max() ?? 0
            performance.context["maximumSharedReceiverPours"]=max(performance.context["maximumSharedReceiverPours"] as? Int ?? 0,shared)
        }
        refresh()
    }
    private func finishConcurrent(_ result:LabLaneResult) {
        guard let item=pourQueue.items.first(where:{$0.id==result.id}) else { return }
        let committed=result.committed && game.commitReserved(item.move)
        pourQueue.finish(result.id)
        if committed {
            undoParticles.append(nil);lastPour=concurrentExamples[result.id]
            if presentation != .fluid { settledParticles=nil }
            feedback.completed(solved:solved)
        } else {
            notice="A pour could not finish. Its source has been restored.";feedback.stop()
            performance.context["lastRejectedPour"]="\(presentation.rawValue) \(item.move.source)→\(item.move.destination) units=\(item.move.amount) approach=\(item.approach) \(result.diagnostic)"
        }
        concurrentExamples[result.id]=nil
        performance.endConcurrentMove(id:result.id,committed:committed,correctionPercent:Double(result.cleanup))
        checkpoint()
    }
    private func cancelConcurrent() {
        classicTask?.cancel();classicTask=nil;clockRevision+=1
        for engine in metalGroups.values { engine.paused=true;metalPool.append(engine) }
        metalGroups=[:];classicLanes=[:];concurrentClassicPours=[];concurrentWorker=nil
        pourQueue.cancelAll();concurrentExamples=[:];compositeSamples=[]
    }
}

extension FluidBoardSession {
    private func checkConcurrentControls() async->[String:Bool] {
        guard let move=state.solution()?.first else { return [:] }
        let initial=state
        func signature()->[Float] {
            switch presentation {
            case .classic: return concurrentClassicPours.map(\.time)
            case .fluid2D: return fluid2D.particles.flatMap { [$0.position.x,$0.position.y] }
            case .fluid: return renderer?.currentVessels.flatMap { [$0.world.columns.3.x,$0.world.columns.3.y,$0.world.columns.3.z] } ?? []
            }
        }
        guard begin(move) else { return ["begin":false] }
        try? await Task.sleep(for:.milliseconds(200));togglePause();let frozen=signature()
        try? await Task.sleep(for:.milliseconds(200));let pauseOK=signature()==frozen
        togglePause();setSuspended(true);let background=signature()
        try? await Task.sleep(for:.milliseconds(200));let suspendOK=signature()==background
        setSuspended(false);try? await Task.sleep(for:.milliseconds(150));let resumeOK=signature() != background
        reset();try? await Task.sleep(for:.milliseconds(100));let resetOK = !busy && state==puzzle.initial
        // The diagnostic trial starts from the puzzle's actual saved fixture.
        guard state==initial,begin(move) else { return ["pause":pauseOK,"suspension":suspendOK,"resume":resumeOK,"reset":resetOK,"restart":false] }
        for _ in 0..<1000 where busy { try? await Task.sleep(for:.milliseconds(16)) }
        let commitOK=state==initial.applying(move) && !busy
        undo();let undoOK=state==initial && !busy
        let save=(try? checkpointData()).flatMap { try? JSONDecoder().decode(LabComparisonSave.self,from:$0) }
        let reloadOK=save?.games[puzzle.rawValue]?.state==initial
        reset()
        return ["pause":pauseOK,"suspension":suspendOK,"resume":resumeOK,"reset":resetOK,"commit":commitOK,"undo":undoOK,"saveReload":reloadOK]
    }
}

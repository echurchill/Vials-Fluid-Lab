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
    @Published private(set) var sortingCourseBoard:LabSortingCourseBoard?
    @Published private(set) var endlessBoard:LabEndlessBoard?
    @Published private(set) var valveBoard:LabValveBoard?
    @Published private(set) var journeyMode:Bool
    @Published private(set) var twoRowLayout=false
    private var requestedTwoRowLayout=false
    var isSortingCourse:Bool {sortingCourseBoard != nil}
    var isEndlessSorting:Bool {endlessBoard != nil}
    var isValveCourse:Bool {valveBoard != nil}
    private var isSortingSubcourse:Bool {isSortingCourse || isEndlessSorting || isValveCourse}
    var discipline:LabDiscipline {isSortingSubcourse ? .sorting:puzzle.discipline}
    var boardID:String {valveBoard?.saveKey ?? sortingCourseBoard?.saveKey ?? endlessBoard?.saveKey ?? puzzle.rawValue}
    var boardTitle:String {valveBoard?.title ?? sortingCourseBoard?.title ?? endlessBoard?.title ?? puzzle.title}
    var boardDetail:String {valveBoard?.detail ?? sortingCourseBoard?.detail ?? endlessBoard?.detail ?? puzzle.detail}
    var boardHeader:String {
        if isValveCourse {return "VALVE LAB"}
        if let sortingCourseBoard {return sortingCourseBoard.isDiscoveryLevel ? "SORTING DISCOVERY":"SORTING COURSE"}
        if let endlessBoard {return endlessBoard.isDiscoveryLevel ? "ENDLESS DISCOVERY":"ENDLESS SORTING"}
        return journeyMode ? "JOURNEY · \(discipline.title.uppercased())":discipline.header
    }
    var boardProgressSummary:String {
        if isValveCourse {return "\(completedValveLevelCount) / \(LabValveBoard.levelCount) complete"}
        if isSortingCourse {return "\(completedSortingCourseLevelCount) / \(LabSortingCourseBoard.levelCount) complete"}
        return isEndlessSorting ? "Generated curriculum":"\(completedPuzzleCount) complete"
    }
    private var initialState:LabBoardState {valveBoard?.initial ?? sortingCourseBoard?.initial ?? endlessBoard?.initial ?? puzzle.initial}
    private var gameKey:String {valveBoard?.saveKey ?? sortingCourseBoard?.saveKey ?? endlessBoard?.saveKey ?? puzzle.rawValue}
    private var boardInstruction:String {
        if let valveBoard {return valveBoard.instruction}
        if sortingCourseBoard?.isDiscoveryLevel == true || endlessBoard?.isDiscoveryLevel == true {return "Pour known colors to reveal what is below. Discoveries stay known."}
        return isSortingSubcourse ? "Tap a filled vial, then a matching color or an empty vial.":puzzle.instruction
    }
    @Published private(set) var renderer:LabBoardRenderer?
    @Published private(set) var classicPour:LabClassicPour?
    @Published private(set) var transformation:LabApparatusTransition?
    var reduceTransformationMotion=false
    let allowsConcurrentPours:Bool
    /// Ordinary pours overlap in every lab; apparatus transitions remain exclusive.
    var concurrentPoursEnabled:Bool {allowsConcurrentPours}
    @Published private(set) var concurrentReveals:[Int:Float]=[:]
    private var revealingSources:Set<Int> {
        Set(state.stacks.indices.filter { owner in state.stacks[owner].contains {concurrentReveals[$0] != nil} })
    }
    @Published private(set) var pourQueue=LabPourQueue()
    @Published private(set) var concurrentClassicPours:[LabClassicPour]=[]
    private var concurrentExamples:[Int:LabPourExample]=[:]
    private var classicLanes:[Int:LabClassicPour]=[:]
    private var metalGroups:[Int:LabBoardRenderer]=[:]
    private var metalPool:[LabBoardRenderer]=[]
    private var compositeSamples:[LabParticle]=[]
    private var concurrentFrame=0
    private var concurrentWorker:LabConcurrent2DWorker?
    var activeMoves:[LabBoardMove] { concurrentPoursEnabled ? pourQueue.items.map(\.move):[game.pending].compactMap { $0 } }
    var fluidFinalSettling:Bool { metalGroups.values.contains(where:\.groupFinalSettling) }
    var solved:Bool { state.solved && !busy }
    func canTap(_ index:Int)->Bool {
        guard !solved,transformation == nil,!revealingSources.contains(index) else { return false }
        if !concurrentPoursEnabled { return !busy && (selected != nil || state.canPourOut(index) || target(index) != nil) }
        return selected == nil ? (state.canPourOut(index) || target(index) != nil) && !pourQueue.lockedSources.contains(index):!pourQueue.movingSources.contains(index)
    }
    func availableMove(from:Int,to:Int)->LabBoardMove? {
        guard transformation == nil,!revealingSources.contains(from),!revealingSources.contains(to) else {return nil}
        return concurrentPoursEnabled ? pourQueue.move(from:from,to:to,state:state):state.move(from:from,to:to)
    }
    lazy var fluid2D=LabFluid2D(game:LabBoardGame(state:LabBoardState(layers:[])))
    let planarDisplay=LabPlanarDisplay()
    @Published private(set) var rejectedVial:Int?
    @Published private(set) var lastPour:LabPourExample?
    private var pendingExample:LabPourExample?
    private var pendingReveal:Set<Int>=[]
    private var rejectionTask:Task<Void,Never>?
    private var hintTask:Task<Void,Never>?
    private var hintRevision=0
    private var hintPlan:[LabBoardOperation]=[]
    @Published private(set) var findingHint=false
    @Published private(set) var hintUndoOffer=false
    // Used only by the disposable comparison session to align playback duration.
    var comparisonSpeed:Float? { didSet { updateSpeed() } }
    @Published var selected:Int?
    @Published var hintTarget:Int?
    @Published var hintApparatusID:Int?
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
    var completedPuzzleCount:Int { discipline.levels.filter(hasCompleted).count }
    var completedSortingCourseLevelCount:Int {(1...LabSortingCourseBoard.levelCount).filter(hasCompletedSortingCourseLevel).count}
    var completedValveLevelCount:Int {(1...LabValveBoard.levelCount).filter(hasCompletedValveLevel).count}
    func hasCompletedSortingCourseLevel(_ number:Int)->Bool {hasCompleted(key:"sortingCourse.\(number)")}
    func sortingCourseCompletion(_ number:Int)->LabCompletionRecord? {saved.completions["sortingCourse.\(number)"]}
    func hasCompletedValveLevel(_ number:Int)->Bool {hasCompleted(key:"valves.\(number)")}
    func hasCompleted(_ puzzle:LabBoardPuzzle) -> Bool {
        (!isSortingSubcourse && puzzle == self.puzzle && state.solved) || hasCompleted(key:puzzle.rawValue)
    }
    private func hasCompleted(key:String)->Bool {saved.completions[key] != nil || (saved.games[key]?.state.solved ?? false)}
    var completionAssistanceSummary:String? {
        guard solved,let record=saved.completions[gameKey] else {return nil}
        switch (record.lastUsedHint,record.lastUsedHelper) {
        case (false,false):return "Completed without hints or helpers."
        case (true,false):return "Completed with a hint."
        case (false,true):return "Completed with a helper."
        case (true,true):return "Completed with a hint and a helper."
        }
    }
    var learningTopics:[LabLearningTopic] {
        if isValveCourse {return [.valves]}
        if sortingCourseBoard?.isDiscoveryLevel == true || endlessBoard?.isDiscoveryLevel == true {return [.discovery]}
        return isSortingSubcourse ? []:LabLearningTopic.topics(for:puzzle)
    }
    var unseenLearningTopics:[LabLearningTopic] {learningTopics.filter {!saved.seenLearningTopics.contains($0.rawValue)}}
    func markLearningTopicSeen(_ topic:LabLearningTopic) {
        guard learningTopics.contains(topic),saved.seenLearningTopics.insert(topic.rawValue).inserted else {return}
        checkpoint()
    }
    var journeyNext:[LabBoardPuzzle] {isSortingSubcourse ? []:(LabJourney.stop(puzzle)?.next ?? [])}
    var nextSuggestedPuzzle:LabBoardPuzzle? {isSortingSubcourse ? nil:(journeyMode ? (journeyNext.count==1 ? journeyNext[0]:nil):puzzle.next)}
    func nextPuzzle() {
        guard !busy,let next=nextSuggestedPuzzle else {return}
        changePuzzle(next,inJourney:journeyMode)
    }
    func startJourney(at stop:LabBoardPuzzle) {
        guard LabJourney.stop(stop) != nil else {return}
        changePuzzle(stop,inJourney:true)
    }
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
    var canUndo:Bool {game.canUndo}
    var supportsHelpers:Bool {discipline == .sorting && !isValveCourse}
    var canAddHelper:Bool {supportsHelpers && !busy && !solved && state.canAddHelper}
    func canUpgradeHelper(_ index:Int)->Bool {supportsHelpers && !busy && !solved && state.canUpgradeHelper(index)}
    var busy:Bool { transformation != nil || game.pending != nil || pourQueue.busy || !concurrentReveals.isEmpty }
    var active3DSimulationParticleCount:Int {metalGroups.values.reduce(0) {$0+$1.particleCount}}
    /// Endless has a shorter play cadence than the instructional labs, while
    /// keeping the same simulation, choreography and completion rules.
    private var boardPlaybackSpeed:Float {
        (isEndlessSorting || isSortingCourse) && pace == .quick ? 2.4:pace.speed
    }
    var effectiveSpeed:Float { (comparisonSpeed ?? boardPlaybackSpeed)*(slow ? 0.35:1) }
    var validDestinations:Set<Int> {
        guard let selected,concurrentPoursEnabled || !busy else { return [] }
        return Set(state.stacks.indices.filter { availableMove(from:selected,to:$0) != nil })
    }
    var activatableApparatus:[LabApparatus] {state.apparatus.filter {state.canActivate(.init(apparatusID:$0.id))}}
    func target(_ index:Int)->LabVialTarget? {state.target(index)}
    func targetExplanation(_ index:Int)->String? {
        state.targetAssessment(index).map {"Target \(Self.letter(index)): \($0.explanation)"}
    }
    func apparatus(forVial index:Int)->[LabApparatus] {state.apparatus.filter {$0.inputs.contains(index) || $0.outputs.contains(index)}}
    func vialComplete(_ index:Int)->Bool {
        state.isComplete(index)
    }
    // Menu availability must not run a puzzle search on every board redraw.
    var canComparePour:Bool {
        guard !busy,state.knownParcels == nil else { return false }
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
            move=state.stacks.indices.compactMap { source in
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
    private func cancelHint(clearPlan:Bool = true) {
        hintRevision &+= 1;hintTask?.cancel();hintTask=nil;findingHint=false
        hintUndoOffer=false
        hintApparatusID=nil
        if clearPlan { hintPlan=[] }
    }
    private func rememberPour(_ committed:Bool) {
        if committed {
            lastPour=pendingExample
            if let before=pendingExample?.state.knownParcels,let after=state.knownParcels {pendingReveal=after.subtracting(before)}
            if let destination=pendingExample?.move.destination,let message=targetExplanation(destination) {notice=message}
        }
        pendingExample=nil
    }

    init(defaults:UserDefaults? = .standard,device:MTLDevice? = MTLCreateSystemDefaultDevice(),library:MTLLibrary? = nil,restoredSave:LabComparisonSave? = nil,allowsConcurrentPours:Bool=false) {
        self.allowsConcurrentPours=allowsConcurrentPours
        let trial=LabTrialConfiguration.current
        self.defaults=trial == nil ? defaults:nil;self.device=device;self.library=library
        var save=self.defaults?.data(forKey:"lab.comparison.v1").flatMap { try? JSONDecoder().decode(LabComparisonSave.self,from:$0) } ?? LabComparisonSave(journeyMode:true)
        if let restoredSave { save=restoredSave }
        if let trial { save=LabComparisonSave(presentation:trial.presentation,pace:trial.pace,puzzle:trial.puzzle,games:[:]) }
        if restoredSave == nil,trial == nil,save.sortingCourseBoard == nil,save.endlessBoard == nil,save.valveBoard == nil,save.puzzle.discipline == .discovery {
            let remembered=save.lastPuzzles[LabDiscipline.sorting.rawValue].flatMap(LabBoardPuzzle.init(rawValue:))
            if let remembered,remembered.discipline == .sorting {save.puzzle=remembered}
            else {save.puzzle = .firstSort}
            save.journeyMode=false
        }
        if save.densitySetupVersion<1 {
            for level in LabDiscipline.density.levels {save.games.removeValue(forKey:level.rawValue)}
            save.densitySetupVersion=1
        }
        soundEnabled=self.defaults?.bool(forKey:"lab.sound") ?? false
        hapticsEnabled=self.defaults?.object(forKey:"lab.haptics") as? Bool ?? (self.defaults != nil)
        quality=trial?.quality ?? LabRenderQuality(rawValue:self.defaults?.string(forKey:"lab.quality") ?? "automatic") ?? .automatic
        saved=save;presentation=save.presentation;pace=save.pace;puzzle=save.puzzle
        valveBoard=save.valveBoard
        sortingCourseBoard=save.valveBoard == nil ? save.sortingCourseBoard:nil
        endlessBoard=save.valveBoard == nil && save.sortingCourseBoard == nil ? save.endlessBoard:nil
        journeyMode=save.sortingCourseBoard == nil && save.endlessBoard == nil && save.valveBoard == nil && save.journeyMode && LabJourney.stop(save.puzzle) != nil
        let restoredKey=save.valveBoard?.saveKey ?? save.sortingCourseBoard?.saveKey ?? save.endlessBoard?.saveKey ?? save.puzzle.rawValue
        let restoredInitial=save.valveBoard?.initial ?? save.sortingCourseBoard?.initial ?? save.endlessBoard?.initial ?? save.puzzle.initial
        var restored=save.games[restoredKey] ?? LabBoardGame(state:restoredInitial)
        restored.cancel() // A launch restores the last committed move.
        game=restored;undoParticles=Array(repeating:nil,count:restored.actionCount)
        if restored.state.hasHelpers {saved.attempts[restoredKey,default:LabAssistanceUsage()].usedHelper=true}
        feedback.soundEnabled=soundEnabled;feedback.hapticsEnabled=hapticsEnabled
        notice=boardInstruction
        if presentation == .fluid { prepareFluid() }
        if presentation == .fluid2D { fluid2D.quickMotion=pace == .quick;fluid2D.install(game);planarDisplay.publish(fluid2D) }
        refresh()
    }
    deinit { classicTask?.cancel();rejectionTask?.cancel() }
    func updateAdaptiveLayout(portrait:Bool) {
        requestedTwoRowLayout=LabBoardLayout.usesTwoRows(portrait:portrait,count:state.stacks.count)
        applyRequestedLayoutIfPossible()
    }
    private func applyRequestedLayoutIfPossible() {
        guard !busy,requestedTwoRowLayout != twoRowLayout else {return}
        let metalSamples=renderer?.reflowedParticleSamples(for:game.state,twoRows:requestedTwoRowLayout)
        twoRowLayout=requestedTwoRowLayout
        fluid2D.setTwoRowLayout(twoRowLayout)
        if presentation == .fluid2D {
            fluid2D.quickMotion=pace == .quick;fluid2D.install(game);planarDisplay.publish(fluid2D)
        }
        renderer?.twoRowLayout=twoRowLayout
        for engine in metalPool {engine.twoRowLayout=twoRowLayout}
        if renderer != nil {settledParticles=metalSamples}
        if presentation == .fluid,let renderer {
            renderer.install(game:game,samples:metalSamples);compositeSamples=renderer.particleSamples()
        }
    }
    private func prepareFluid() {
        guard !busy else { return }
        do {
            if renderer == nil {
                guard let device else { throw LabError.message("Fluid rendering is unavailable. Classic remains playable.") }
                let engine=try LabBoardRenderer(device:device,library:library)
                engine.onFrame={ [weak self] interval,cpu,gpu in
                    guard let self,!self.concurrentPoursEnabled else { return }
                    self.performance.recordFrame(interval:interval,cpuMS:cpu,gpuMS:gpu)
                }
                engine.onError={ [weak self] in self?.error=$0 }
                engine.onUpdate={ [weak self] _,_,_ in self?.fluidUpdate() }
                renderer=engine
            }
            renderer?.twoRowLayout=twoRowLayout
            renderer?.install(game:game,samples:settledParticles)
            if concurrentPoursEnabled,let renderer {
                compositeSamples=renderer.particleSamples()
                // One simulation group per independent receiver. Dependency
                // rules, rather than a two-pour ceiling, now determine how
                // many transfers may overlap on larger boards.
                let required=max(2,game.state.stacks.count/2)
                while metalPool.count+metalGroups.count<required {
                    metalPool.append(try LabBoardRenderer(simulationCopyOf:renderer))
                }
            }
            renderer?.quality=quality;renderer?.pointMode=points;renderer?.orbit=Float(orbit);updateSpeed();updatePause()
        } catch { self.error=error.localizedDescription;presentation = .classic }
    }
    private func checkpoint() {
        performance.traceBegin("Checkpoint");defer { performance.traceEnd("Checkpoint") }
        if state.hasHelpers {saved.attempts[gameKey,default:LabAssistanceUsage()].usedHelper=true}
        var stable=game;stable.cancel()
        saved.games[gameKey]=stable;saved.presentation=presentation;saved.pace=pace;saved.puzzle=puzzle;saved.sortingCourseBoard=sortingCourseBoard;saved.endlessBoard=endlessBoard;saved.valveBoard=valveBoard
        if !isSortingSubcourse {saved.lastPuzzles[puzzle.discipline.rawValue]=puzzle.rawValue}
        saved.journeyMode=journeyMode
        if let data=try? JSONEncoder().encode(saved) { defaults?.set(data,forKey:"lab.comparison.v1") }
    }
    private func markAssistance(hint:Bool=false,helper:Bool=false) {
        var usage=saved.attempts[gameKey] ?? LabAssistanceUsage()
        usage.usedHint = usage.usedHint || hint
        usage.usedHelper = usage.usedHelper || helper
        saved.attempts[gameKey]=usage
    }
    private func recordCompletionIfNeeded() {
        guard solved,!busy else {return}
        var usage=saved.attempts[gameKey] ?? LabAssistanceUsage()
        guard !usage.completionRecorded else {return}
        var record=saved.completions[gameKey] ?? LabCompletionRecord()
        record.record(moveCount:moveCount,usage:usage)
        usage.completionRecorded=true
        saved.attempts[gameKey]=usage;saved.completions[gameKey]=record
        checkpoint()
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
    func changeDiscipline(_ value:LabDiscipline) {
        guard !busy,value != discipline || journeyMode || isSortingSubcourse else {return}
        let remembered=saved.lastPuzzles[value.rawValue].flatMap(LabBoardPuzzle.init(rawValue:))
        changePuzzle(remembered?.discipline==value ? remembered!:value.levels[0])
    }
    func changePuzzle(_ value:LabBoardPuzzle,inJourney:Bool=false) {
        guard !busy else {return}
        let enteringJourney=inJourney && LabJourney.stop(value) != nil
        guard value != puzzle || isSortingSubcourse || journeyMode != enteringJourney else {checkpoint();return}
        cancelHint()
        lastPour=nil;pendingExample=nil;clearSelectionFeedback()
        finishMeasurement(reason:"puzzle changed");checkpoint();sortingCourseBoard=nil;endlessBoard=nil;valveBoard=nil;journeyMode=enteringJourney
        puzzle=value;game=saved.games[value.rawValue] ?? LabBoardGame(state:value.initial);game.cancel()
        undoParticles=Array(repeating:nil,count:game.actionCount);settledParticles=nil
        selected=nil;hintTarget=nil;hintApparatusID=nil;paused=false;metrics=LabBoardMetrics();correction=0;captured=0
        if presentation == .fluid { prepareFluid() }
        if presentation == .fluid2D { fluid2D.quickMotion=pace == .quick;fluid2D.install(game);planarDisplay.publish(fluid2D) }
        notice=value.instruction;checkpoint();refresh()
    }
    func changeSortingCourseBoard(_ value:LabSortingCourseBoard) {
        guard !busy else {return}
        if sortingCourseBoard?.saveKey == value.saveKey {checkpoint();return}
        cancelHint();lastPour=nil;pendingExample=nil;clearSelectionFeedback()
        finishMeasurement(reason:"sorting course level changed");checkpoint()
        sortingCourseBoard=value;endlessBoard=nil;valveBoard=nil;journeyMode=false
        game=saved.games[value.saveKey] ?? LabBoardGame(state:value.initial);game.cancel()
        undoParticles=Array(repeating:nil,count:game.actionCount);settledParticles=nil
        selected=nil;hintTarget=nil;hintApparatusID=nil;paused=false;metrics=LabBoardMetrics();correction=0;captured=0
        if presentation == .fluid {prepareFluid()}
        if presentation == .fluid2D {fluid2D.quickMotion=pace == .quick;fluid2D.install(game);planarDisplay.publish(fluid2D)}
        notice=boardInstruction;checkpoint();refresh()
    }
    func changeEndlessBoard(_ value:LabEndlessBoard) {
        guard !busy else {return}
        if endlessBoard?.saveKey == value.saveKey {checkpoint();return}
        cancelHint();lastPour=nil;pendingExample=nil;clearSelectionFeedback()
        finishMeasurement(reason:"endless level changed");checkpoint()
        endlessBoard=value;sortingCourseBoard=nil;valveBoard=nil;journeyMode=false
        game=saved.games[value.saveKey] ?? LabBoardGame(state:value.initial);game.cancel()
        undoParticles=Array(repeating:nil,count:game.actionCount);settledParticles=nil
        selected=nil;hintTarget=nil;hintApparatusID=nil;paused=false;metrics=LabBoardMetrics();correction=0;captured=0
        if presentation == .fluid {prepareFluid()}
        if presentation == .fluid2D {fluid2D.quickMotion=pace == .quick;fluid2D.install(game);planarDisplay.publish(fluid2D)}
        notice=boardInstruction;checkpoint();refresh()
    }
    func changeValveBoard(_ value:LabValveBoard) {
        guard !busy else {return}
        if valveBoard?.saveKey == value.saveKey {checkpoint();return}
        cancelHint();lastPour=nil;pendingExample=nil;clearSelectionFeedback()
        finishMeasurement(reason:"valve course level changed");checkpoint()
        valveBoard=value;sortingCourseBoard=nil;endlessBoard=nil;journeyMode=false
        game=saved.games[value.saveKey] ?? LabBoardGame(state:value.initial);game.cancel()
        undoParticles=Array(repeating:nil,count:game.actionCount);settledParticles=nil
        selected=nil;hintTarget=nil;hintApparatusID=nil;paused=false;metrics=LabBoardMetrics();correction=0;captured=0
        if presentation == .fluid {prepareFluid()}
        if presentation == .fluid2D {fluid2D.quickMotion=pace == .quick;fluid2D.install(game);planarDisplay.publish(fluid2D)}
        notice=boardInstruction;checkpoint();refresh()
    }
    func refresh() {
        applyRequestedLayoutIfPossible()
        if !busy,!pendingReveal.isEmpty {
            let ids=pendingReveal;pendingReveal=[]
            var before=state;before.knownParcels?.subtract(ids)
            let owners=state.stacks.indices.filter { !Set(state.stacks[$0]).isDisjoint(with:ids) }
            let tool=LabApparatus(id:-1,kind:.densityModifier,inputs:owners,output:nil,direction:nil)
            let transition=LabApparatusTransition(before:before,after:state,apparatus:tool,reduceMotion:reduceTransformationMotion,revealedParcels:ids)
            transformation=transition
            if presentation == .fluid {renderer?.beginTransformation(transition);renderer?.showTransformation(transition)}
            if presentation == .fluid2D {fluid2D.beginTransformation(transition);fluid2D.showTransformation(transition);planarDisplay.publish(fluid2D)}
            notice="New color discovered. It stays known through Undo and Reset."
            startTransformationClock()
        }
        updateFeedback()
        recordCompletionIfNeeded()
        let nextPhase:String
        if solved {
            nextPhase=state.targets.isEmpty ? "Sorted beautifully":"Targets complete"
            let solvedNotice=state.targets.isEmpty ? "Every color has a home. Undo to explore, or play again.":"Every requested material is in place. Undo to explore, or play again."
            if notice != solvedNotice { notice=solvedNotice }
        } else if state.helpersPreventCompletion {
            nextPhase="Empty the helpers"
            if notice != "Helper cups must be empty to finish." {notice="Helper cups must be empty to finish."}
        } else if let transformation { nextPhase=transformation.status
        } else if concurrentPoursEnabled,busy {
            let active=pourQueue.active.count,waiting=pourQueue.items.count-active
            nextPhase=active==0 && waiting==0 ? "Discovering a color":"\(active) \(active == 1 ? "pour":"pours")"+(waiting>0 ? " · \(waiting) queued":"")
        } else if let pour=classicPour {
            nextPhase=pour.time<0.95 ? "Moving into position":(pour.returning ? "Returning the vial":"Pouring \(pour.move.amount) \(pour.move.amount == 1 ? "unit":"units")")
        } else if busy { nextPhase=presentation == .fluid2D ? fluid2D.phase:(renderer?.phase ?? "Pouring") }
        else { nextPhase=moveCount>0 ? "Move complete":"Choose a vial" }
        if phase != nextPhase { phase=nextPhase;performance.tracePhase(nextPhase) }
    }
    private func fluidUpdate() {
        guard transformation == nil,!concurrentPoursEnabled,presentation == .fluid,let renderer else { return }
        metrics=renderer.lastMetrics;correction=renderer.correctionCount;captured=renderer.arrivalBeforeCorrection
        if busy,renderer.game.pending == nil {
            let amount=game.pending?.amount ?? 1
            let committed=renderer.game.moveCount == game.moveCount+1
            if committed { undoParticles.append(beforeParticles);game=renderer.game;settledParticles=renderer.particleSamples() }
            else { game.cancel();hintPlan=[];notice=renderer.lastOutcome }
            rememberPour(committed)
            performance.endMove(committed:committed,correctionPercent:Double(correction)/Double(amount*640)*100)
            if committed { feedback.completed(solved:state.solved) } else { feedback.stop() }
            beforeParticles=nil;checkpoint()
        }
        refresh()
    }
    func select(_ index:Int) {
        guard state.stacks.indices.contains(index),transformation == nil,!revealingSources.contains(index),concurrentPoursEnabled || !busy,!solved else { return }
        if let source=selected {
            if source == index { clearSelectionFeedback();selected=nil;hintTarget=nil;hintApparatusID=nil;notice="Choose another vial.";return }
            guard let move=availableMove(from:source,to:index) else {
                reject(index)
                let projected=pourQueue.projected(state)
                if concurrentPoursEnabled,pourQueue.movingSources.contains(index) { notice="That vial is already pouring or queued." }
                else if projected.stacks[index].count == state.capacity(index) { notice="That vial is full or its remaining space is reserved." }
                else if let key=projected.valvePigment(index),let parcel=projected.stacks[source].last,projected.colors[parcel] != key {
                    notice="That lid opens only for \(Self.name(key))."
                }
                else { notice=state.behavior.unrestrictedDestinations ? "That destination cannot receive this batch.":"Choose the same top material, an apparatus input, or an empty vial." }
                return
            }
            if begin(move) {
                selected=nil;hintTarget=nil;hintApparatusID=nil
                notice="\(move.amount) \(move.amount == 1 ? "unit":"units") of \(Self.name(move.color)) · \(Self.letter(source)) → \(Self.letter(index))"
            }
        } else {
            guard !concurrentPoursEnabled || !pourQueue.lockedSources.contains(index) else { reject(index);notice="That vial is already in use.";return }
            guard state.canPourOut(index) else { reject(index);notice=targetExplanation(index) ?? "That keyed valve cannot pour out. Choose an ordinary vial first.";return }
            guard !state.stacks[index].isEmpty else { reject(index);notice=targetExplanation(index) ?? "Choose a vial that contains liquid first.";return }
            clearSelectionFeedback();feedback.selection();selected=index;hintTarget=nil;hintApparatusID=nil
            notice=targetExplanation(index) ?? (state.behavior.unrestrictedDestinations ? "Now choose any non-full destination.":"Now choose a matching material, apparatus input, or empty vial.")
        }
    }
    @discardableResult func begin(_ move:LabBoardMove,automaticClock:Bool = true) -> Bool {
        // A followed hint advances the route that was already solved. Any
        // different move invalidates it, so the next hint plans afresh.
        // The live board permits concurrent pours, but a hint followed while
        // the queue is idle is still a sequential step along the retained
        // route. A second overlapping reservation invalidates that route.
        let followsHintPlan = hintPlan.first == .pour(move) && (!concurrentPoursEnabled || !busy)
        cancelHint(clearPlan:!followsHintPlan)
        if concurrentPoursEnabled {
            let began=beginConcurrent(move,automaticClock:automaticClock)
            if began,followsHintPlan { hintPlan.removeFirst() }
            if !began { hintPlan=[] }
            return began
        }
        guard !busy,!state.solved,game.state.move(from:move.source,to:move.destination)==move else {
            hintPlan=[];return false
        }
        performance.traceBegin("Begin pour");defer { performance.traceEnd("Begin pour") }
        beforeParticles=settledParticles
        if presentation == .fluid {
            guard let renderer else { hintPlan=[];return false }
            beforeParticles=renderer.particleSamples()
            guard renderer.begin(from:move.source,to:move.destination) else { hintPlan=[];return false }
        }
        if presentation == .fluid2D { guard fluid2D.begin(move) else { hintPlan=[];return false } }
        guard game.begin(from:move.source,to:move.destination) != nil else { hintPlan=[];return false }
        if followsHintPlan { hintPlan.removeFirst() }
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
        if transformation != nil {advanceTransformation(deltaTime:deltaTime);return}
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
            } else { game.cancel();hintPlan=[];notice=fluid2D.lastOutcome;feedback.stop() }
            rememberPour(committed)
            performance.endMove(committed:committed,correctionPercent:Double(fluid2D.cleanupPercent))
            beforeParticles=nil;classicTask?.cancel();classicTask=nil;checkpoint()
        }
        performance.recordFrame(interval:Double(deltaTime),cpuMS:fluid2D.cpuMilliseconds,gpuMS:nil)
        refresh()
    }
    func advanceClassic(deltaTime:Float) {
        if transformation != nil {advanceTransformation(deltaTime:deltaTime);return}
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
    func reset(keepingDiscoveries:Bool=true) {
        let initial=keepingDiscoveries ? initialState.retainingDiscoveries(from:state):initialState
        cancelHint()
        cancelConcurrent()
        transformation=nil;pendingReveal=[]
        lastPour=nil;pendingExample=nil;clearSelectionFeedback()
        feedback.stop()
        classicTask?.cancel();classicTask=nil;classicPour=nil
        game=LabBoardGame(state:initial);undoParticles=[];settledParticles=nil;beforeParticles=nil
        saved.attempts[gameKey]=LabAssistanceUsage()
        renderer?.reset(state:initial)
        if presentation == .fluid2D { fluid2D.quickMotion=pace == .quick;fluid2D.install(game);planarDisplay.publish(fluid2D) }
        selected=nil;hintTarget=nil;hintApparatusID=nil;paused=false;metrics=LabBoardMetrics();correction=0;captured=0
        notice=boardInstruction;updatePause();checkpoint();refresh()
    }
    /// Clears every saved board, not just the currently selected puzzle.
    /// reset() invalidates in-flight worker results before the fresh checkpoint.
    func resetAllProgress() {
        finishMeasurement(reason:"all progress reset")
        saved=LabComparisonSave(journeyMode:true);journeyMode=true
        puzzle=saved.puzzle;sortingCourseBoard=nil;endlessBoard=nil;valveBoard=nil;presentation=saved.presentation;pace=saved.pace
        comparisonSpeed=nil;slow=false;points=false;diagnostics=false;orbit=0.12
        error=nil;reportURL=nil
        reset(keepingDiscoveries:false)
        fluid2D.quickMotion=false;fluid2D.install(game);planarDisplay.publish(fluid2D)
        prepareFluid()
        checkpoint()
        notice="All progress reset. Tap a filled vial to begin."
    }
    func undo() {
        guard !busy,game.undo() else { return }
        cancelHint()
        lastPour=nil;pendingExample=nil;clearSelectionFeedback()
        settledParticles=undoParticles.isEmpty ? nil:undoParticles.removeLast()
        if presentation == .fluid { prepareFluid() }
        if presentation == .fluid2D { fluid2D.quickMotion=pace == .quick;fluid2D.install(game);planarDisplay.publish(fluid2D) }
        selected=nil;hintTarget=nil;hintApparatusID=nil;paused=false;metrics=LabBoardMetrics();correction=0;captured=0
        notice="Last action undone. Try a different route.";updatePause();checkpoint();refresh()
    }
    func addHelper() {
        guard canAddHelper else {return}
        cancelHint();lastPour=nil;pendingExample=nil;clearSelectionFeedback()
        let particles=presentation == .fluid ? renderer?.particleSamples():settledParticles
        guard game.addHelper() else {return}
        markAssistance(helper:true)
        // An empty helper changes only the vessel homes. Preserve local liquid
        // placement while translating it into the new topology; Undo retains
        // the exact old world-space sample.
        undoParticles.append(particles)
        settledParticles=renderer?.reflowedParticleSamples(particles,for:game.state)
        selected=nil;hintTarget=nil;hintApparatusID=nil
        if presentation == .fluid {prepareFluid()}
        if presentation == .fluid2D {
            fluid2D.quickMotion=pace == .quick
            if !fluid2D.installAddingEmptyHelper(game) {fluid2D.install(game)}
            planarDisplay.publish(fluid2D)
        }
        notice="Tea cup added. It must be empty to finish the level."
        checkpoint();refresh()
    }
    func upgradeHelper(_ index:Int) {
        guard canUpgradeHelper(index) else {return}
        cancelHint();lastPour=nil;pendingExample=nil;clearSelectionFeedback()
        let particles=presentation == .fluid ? renderer?.particleSamples():settledParticles
        let wasEmpty=state.stacks[index].isEmpty
        guard game.upgradeHelper(index) else {return}
        // Capacity changes replace the helper profile. Preserve the old sample
        // for Undo. An empty helper can reuse every existing liquid sample;
        // a filled helper still rebuilds liquid inside the new physical volume.
        undoParticles.append(particles)
        settledParticles=wasEmpty ? renderer?.reflowedParticleSamples(particles,for:game.state):nil
        selected=nil;hintTarget=nil;hintApparatusID=nil
        if presentation == .fluid {prepareFluid()}
        if presentation == .fluid2D {
            fluid2D.quickMotion=pace == .quick
            if !wasEmpty || !fluid2D.installUpgradingEmptyHelper(index,to:game) {fluid2D.install(game)}
            planarDisplay.publish(fluid2D)
        }
        notice="Helper upgraded to \(state.helperName(index) ?? "the next size"). It still must be empty to finish."
        checkpoint();refresh()
    }
    func hint() {
        guard !busy,!state.solved,!findingHint else { return }
        clearSelectionFeedback()
        if state.hasUnknown {
            cancelHint()
            if let move=state.discoveryHint() {
                showHint(.pour(move));notice="Try \(Self.letter(move.source)) → \(Self.letter(move.destination)). Use the known color to make room or uncover a layer."
            } else {offerHintUndo(message:"No visible move is available.")}
            return
        }
        if let operation=hintPlan.first,state.applying(operation) != nil {
            showHint(operation);return
        }
        hintPlan=[];let snapshot=state
        hintRevision &+= 1;let revision=hintRevision
        findingHint=true;notice="Finding a route through this larger board…";let puzzle=self.puzzle,isAuthored = !isSortingSubcourse
        hintTask=Task { @MainActor [weak self] in
            let route=await Task.detached(priority:.userInitiated) {
                Self.hintRoute(for:snapshot,puzzle:puzzle,isAuthored:isAuthored)
            }.value
            guard let self,self.hintRevision==revision else {return}
            self.findingHint=false;self.hintTask=nil
            guard !Task.isCancelled,!self.busy,self.state==snapshot else {return}
            if let route,let operation=route.first {
                self.hintPlan=route
                self.showHint(operation)
            } else {self.offerHintUndo(message:"No solution is available from here.")}
        }
    }
    nonisolated private static func hintRoute(for snapshot:LabBoardState,puzzle:LabBoardPuzzle,isAuthored:Bool)->[LabBoardOperation]? {
        if snapshot.behavior == .sorting || snapshot.behavior == .discovery {
            return snapshot.solution().map {$0.map(LabBoardOperation.pour)}
        }
        if isAuthored,snapshot==puzzle.initial,let authored=puzzle.authoredRoute(from:snapshot) {return authored}
        return snapshot.operationSolution()
    }
    private func offerHintUndo(message:String) {
        hintPlan=[];selected=nil;hintTarget=nil;hintApparatusID=nil
        hintUndoOffer=canUndo
        notice=message+(hintUndoOffer ? " Undo until a hint becomes available?":" There are no earlier moves to undo.")
    }
    func dismissHintUndoOffer() {hintUndoOffer=false}
    func undoUntilHintAvailable() {
        guard !busy,!state.solved,!findingHint,canUndo else {hintUndoOffer=false;return}
        hintUndoOffer=false;cancelHint()
        let snapshot=game,puzzle=self.puzzle,isAuthored = !isSortingSubcourse
        let revision=hintRevision
        findingHint=true;notice="Finding the nearest earlier position with a hint…"
        hintTask=Task { @MainActor [weak self] in
            let recovery=await Task.detached(priority:.userInitiated) { () -> (Int,[LabBoardOperation])? in
                var candidate=snapshot,undoCount=0
                while candidate.undo() {
                    undoCount+=1
                    let route:[LabBoardOperation]?
                    if candidate.state.hasUnknown {
                        route=candidate.state.discoveryHint().map {[.pour($0)]}
                    } else {
                        route=Self.hintRoute(for:candidate.state,puzzle:puzzle,isAuthored:isAuthored)
                    }
                    if let route,!route.isEmpty {return (undoCount,route)}
                }
                return nil
            }.value
            guard let self,self.hintRevision==revision else {return}
            self.findingHint=false;self.hintTask=nil
            guard !Task.isCancelled,!self.busy,self.game==snapshot else {return}
            guard let recovery else {
                self.notice="No hint is available, even at the beginning of this level."
                return
            }
            var restoredParticles:[LabParticle]?
            for _ in 0..<recovery.0 {
                guard self.game.undo() else {return}
                restoredParticles=self.undoParticles.isEmpty ? nil:self.undoParticles.removeLast()
            }
            self.lastPour=nil;self.pendingExample=nil;self.clearSelectionFeedback()
            self.settledParticles=restoredParticles
            self.selected=nil;self.hintTarget=nil;self.hintApparatusID=nil;self.paused=false
            self.metrics=LabBoardMetrics();self.correction=0;self.captured=0
            if self.presentation == .fluid {self.prepareFluid()}
            if self.presentation == .fluid2D {
                self.fluid2D.quickMotion=self.pace == .quick;self.fluid2D.install(self.game);self.planarDisplay.publish(self.fluid2D)
            }
            self.hintPlan=recovery.1;self.checkpoint();self.refresh()
            self.showHint(recovery.1[0])
        }
    }
    private func showHint(_ operation:LabBoardOperation) {
        markAssistance(hint:true);checkpoint()
        switch operation {
        case .pour(let move):
            hintApparatusID=nil;selected=move.source;hintTarget=move.destination
            notice="Try \(Self.letter(move.source)) → \(Self.letter(move.destination)) · \(move.amount) \(Self.name(move.color)) \(move.amount == 1 ? "unit":"units")"
        case .activate(let activation):
            selected=nil;hintTarget=nil;hintApparatusID=activation.apparatusID
            notice="Activate \(state.apparatus.first(where:{$0.id==activation.apparatusID})?.title ?? "the apparatus")."
        }
    }
    func activateApparatus(_ id:Int,animated:Bool=true,automaticClock:Bool=true) {
        guard !busy else {return}
        let activation=LabApparatusActivation(apparatusID:id)
        guard let after=state.applying(activation),let tool=state.apparatus.first(where:{$0.id==id}) else {notice=state.apparatus.first(where:{$0.id==id}).map {state.apparatusGuidance($0).message} ?? "That apparatus is not available.";return}
        let followsHint=hintPlan.first == .activate(activation)
        cancelHint(clearPlan:!followsHint)
        if animated {
            let transition=LabApparatusTransition(before:state,after:after,apparatus:tool,reduceMotion:reduceTransformationMotion)
            transformation=transition;selected=nil;hintTarget=nil;hintApparatusID=nil
            if presentation == .fluid { renderer?.beginTransformation(transition) }
            if presentation == .fluid2D { fluid2D.beginTransformation(transition);planarDisplay.publish(fluid2D) }
            notice=transition.isSeparating ? "The mixture separates into two ingredients; total volume stays the same.":transition.isDensityChange ? (tool.direction == .heavier ? "The liquid becomes heavier; its volume stays the same.":"The liquid becomes lighter; its volume stays the same."):"The two inputs blend into one new color.";refresh()
            if automaticClock {startTransformationClock()}
            return
        }
        finishActivation(activation)
    }
    private func startTransformationClock() {
        classicTask?.cancel()
        classicTask=Task { @MainActor [weak self] in
            var last=ProcessInfo.processInfo.systemUptime
            while !Task.isCancelled {
                try? await Task.sleep(for:.milliseconds(16))
                guard !Task.isCancelled,let self,self.transformation != nil else {return}
                let now=ProcessInfo.processInfo.systemUptime
                self.advanceTransformation(deltaTime:Float(now-last));last=now
            }
        }
    }
    func advanceTransformation(deltaTime:Float) {
        guard !paused,!suspended,deltaTime.isFinite,var transition=transformation else {return}
        transition.time+=min(0.05,max(0,deltaTime))*effectiveSpeed
        transformation=transition
        if presentation == .fluid {renderer?.showTransformation(transition)}
        if presentation == .fluid2D {fluid2D.showTransformation(transition);planarDisplay.publish(fluid2D)}
        if transition.finished,transition.isRevealing {
            transformation=nil;classicTask?.cancel();classicTask=nil
            if presentation == .fluid {renderer?.finishTransformation(game);settledParticles=renderer?.particleSamples()}
            if presentation == .fluid2D {fluid2D.finishTransformation(game);planarDisplay.publish(fluid2D)}
            checkpoint();refresh()
        } else if transition.finished {
            finishActivation(.init(apparatusID:transition.apparatus.id))
        } else {refresh()}
    }
    private func finishActivation(_ activation:LabApparatusActivation) {
        guard game.activate(activation) else {return}
        if hintPlan.first == .activate(activation) {hintPlan.removeFirst()}
        let wasTransforming=transformation != nil
        transformation=nil;classicTask?.cancel();classicTask=nil
        undoParticles.append(nil);settledParticles=nil;selected=nil;hintTarget=nil;hintApparatusID=nil
        if presentation == .fluid {
            if wasTransforming {renderer?.finishTransformation(game);settledParticles=renderer?.particleSamples()}
            else {prepareFluid()}
        }
        if presentation == .fluid2D {
            if wasTransforming {fluid2D.finishTransformation(game)} else {fluid2D.install(game)}
            planarDisplay.publish(fluid2D)
        }
        notice="Transformation complete.";feedback.completed(solved:state.solved);checkpoint();refresh()
    }
    // A dismissed preview must release its clock even when it closes mid-pour.
    func discardPreview() {
        guard defaults == nil else { return }
        cancelConcurrent()
        classicTask?.cancel();classicTask=nil;clockRevision+=1
        if transformation != nil {transformation=nil;renderer?.install(game:game)}
        game.cancel();classicPour=nil;renderer?.paused=true;suspended=true;feedback.stop()
    }
    func setSuspended(_ value:Bool) { suspended=value;updatePause() }
    func togglePause() { paused.toggle();updatePause() }
    private func updatePause() { clockRevision+=1;renderer?.paused=paused || suspended || presentation != .fluid;updateFeedback() }
    private func updateFeedback() {
        let visibleStream:Bool
        if concurrentPoursEnabled {
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
        performance.context=["puzzle":boardID,"vialCount":state.stacks.count,"colorCount":Set(state.colors).count,"quality":quality.rawValue,"maximumRenderDimension":quality.maximumDimension,"particleCount":presentation == .fluid ? (renderer?.particleCount ?? 0):(presentation == .fluid2D ? fluid2D.particles.count:0)]
        if presentation == .fluid2D {
            performance.context["quality"]="canvas-native"
            performance.context.removeValue(forKey:"maximumRenderDimension")
            performance.context["frameCounter"]="controller updates, not compositor presents"
            performance.context["cpuCounter"]="2D worker solver only; excludes Canvas drawing"
            performance.context["physicsExecution"]="isolated actor, immutable value snapshots"
        }
        if concurrentPoursEnabled {
            performance.context["concurrentPourLimit"]="dependency constrained"
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
        if concurrentPoursEnabled { return await checkConcurrentControls() }
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
        let saveOK=reloaded?.games[gameKey]?.state==initial
        reset()
        return ["pause":pauseOK,"suspension":suspendOK,"resume":resumeOK,"reset":resetOK,"commit":commitOK,"undo":undoOK,"saveReload":saveOK]
    }
    // Explicit device diagnostic, isolated from saved play by --lab-trial.
    // Uses the live presentation and normal clock, rather than fast-forwarding
    // the offscreen harness. It is a functional check, not a battery benchmark.
    private func checkDensityTrial() async {
        let originalReducedMotion=reduceTransformationMotion
        defer {reduceTransformationMotion=originalReducedMotion}
        var results:[[String:Any]]=[]
        var failures:[String]=[]
        func check(_ condition:Bool,_ message:String) {if !condition {failures.append(message)}}
        func install(_ fixture:LabBoardState,_ level:LabBoardPuzzle,_ mode:LabBoardPresentation) {
            reset();puzzle=level;game=LabBoardGame(state:fixture)
            undoParticles=[];settledParticles=nil;presentation=mode;error=nil
            if mode == .fluid {prepareFluid()} else {renderer?.paused=true}
            if mode == .fluid2D {fluid2D.quickMotion=pace == .quick;fluid2D.install(game);planarDisplay.publish(fluid2D)}
            updatePause();refresh()
        }
        for mode in LabBoardPresentation.allCases {
            for (level,index,reduced) in [(LabBoardPuzzle.equalPartners,1,false),(.weightedOrange,4,false),(.twinProducts,10,false),(.weightedOrange,4,true)] {
                guard !Task.isCancelled,!suspended else {failures.append("Device trial interrupted");break}
                let label="\(mode.rawValue)/\(level.rawValue)/\(reduced ? "reduced":"normal")"
                let failureStart=failures.count
                guard let route=level.authoredRoute(),route.indices.contains(index) else {failures.append(label+": missing route");continue}
                var before=level.initial
                for operation in route.prefix(index) {before=before.applying(operation)!}
                guard case .activate(let activation)=route[index],let after=before.applying(route[index]) else {failures.append(label+": missing activation");continue}
                install(before,level,mode);reduceTransformationMotion=reduced
                try? await Task.sleep(for:.milliseconds(300))
                activateApparatus(activation.apparatusID)
                activateApparatus(activation.apparatusID) // Must not double-commit.
                check(transformation?.isDensityChange == true,label+": did not start")
                try? await Task.sleep(for:.milliseconds(300))
                togglePause()
                let frozen=transformation,planar=fluid2D.particles
                let metal=mode == .fluid ? renderer?.particleSamples().map(\.position):nil
                try? await Task.sleep(for:.milliseconds(250))
                check(frozen != nil && transformation?.time==frozen?.time && transformation?.densityPatternOffsets==frozen?.densityPatternOffsets,label+": pause advanced symbols")
                check(fluid2D.particles==planar,label+": pause advanced planar particles")
                if let metal {check(renderer?.particleSamples().map(\.position)==metal,label+": pause advanced Metal particles")}
                togglePause()
                let started=ProcessInfo.processInfo.systemUptime
                var previous=frozen?.densityPatternOffsets
                var samples=0
                while busy && !suspended && !Task.isCancelled && ProcessInfo.processInfo.systemUptime-started<10 {
                    if let transition=transformation {
                        let offsets=transition.densityPatternOffsets
                        check(state==before && moveCount==0,label+": premature commit")
                        if let previous {check(offsets.x>=previous.x-0.00001 && offsets.y<=previous.y+0.00001,label+": reversed drift")}
                        if reduced {check(offsets == .zero,label+": Reduced Motion drifted")}
                        previous=offsets;samples+=1
                    }
                    try? await Task.sleep(for:.milliseconds(30))
                }
                check(samples>0,label+": no resumed animation samples")
                check(!busy && state==after && moveCount==1,label+": final state or single commit failed")
                check(error == nil,label+": renderer error: \(error ?? "")")
                if mode == .fluid {check(renderer?.particleCount==before.colors.count*LabBoardRenderer.particlesPerUnit,label+": Metal inventory changed")}
                if mode == .fluid2D {check(fluid2D.particles.count==before.colors.count*LabFluid2D.particlesPerUnit,label+": planar inventory changed")}
                if !busy {undo();check(state==before && moveCount==0,label+": undo failed")}
                activateApparatus(activation.apparatusID)
                try? await Task.sleep(for:.milliseconds(100));reset()
                try? await Task.sleep(for:.milliseconds(100))
                check(!busy && state==level.initial && moveCount==0,label+": reset left a delayed commit")
                results.append(["case":label,"passed":failures.count==failureStart,"resumedSamples":samples])
            }
        }
        let report:[String:Any]=["date":ISO8601DateFormatter().string(from:Date()),"passed":failures.isEmpty && results.count==12,"cases":results,"failures":failures,"environment":performance.environment(),"notes":"Live app, automatic animation clocks, all three presentations. Functional checks only; no claim of visual acceptance, displayed frame rate or battery consumption."]
        do {
            let directory=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("FluidLabReports",isDirectory:true)
            try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
            let url=directory.appendingPathComponent("density-device-check.json")
            try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:url,options:.atomic)
            reportURL=url
        } catch {self.error=error.localizedDescription}
        reset()
        notice=failures.isEmpty && results.count==12 ? "Density checks passed in all three views.":"Density checks need attention. See diagnostic report."
    }

    // Opt-in, fixed-workload GPU comparison. No simulation or screen capture
    // runs in the measured command buffers; this is not displayed frame rate.
    private func profileDensitySurface() async {
        guard let device else {error="Metal unavailable for density profile";return}
        paused=true;updatePause()
        let environment=LabPerformanceRecorder(),start=environment.environment()
        var rows:[[String:Any]]=[]
        do {
            let pigments=[0,1,2,8,9,4]
            let layered=LabBoardState(layers:pigments.map {Array(repeating:$0,count:3)},capacities:Array(repeating:3,count:6),
                densityLayers:Array(repeating:[.heavy,.medium,.light],count:6),behavior:.density)
            let dense=LabBoardState(layers:(0..<10).map {Array(repeating:pigments[$0%6],count:3)},capacities:Array(repeating:3,count:10),
                densityLayers:Array(repeating:[.heavy,.medium,.light],count:10),behavior:.density)
            for (name,fixture) in [("six-density-vials",layered),("ten-density-vials",dense),("sixfold",LabBoardPuzzle.sixfold.initial)] {
                let surface=try LabBoardRenderer(device:device,library:library)
                surface.install(game:LabBoardGame(state:fixture));surface.paused=true;surface.quality = .high;surface.orbit=0.12
                for width in [720,1000] {
                    let height=width*3/5
                    let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm_srgb,width:width,height:height,mipmapped:false)
                    descriptor.storageMode = .private;descriptor.usage=[.renderTarget,.shaderRead]
                    guard let target=device.makeTexture(descriptor:descriptor) else {throw NSError(domain:"DensityProfile",code:1,userInfo:[NSLocalizedDescriptionKey:"Target allocation failed"])}
                    var gpu:[Double]=[],host:[Double]=[]
                    for frame in 0..<140 {
                        guard !Task.isCancelled,!suspended else {throw NSError(domain:"DensityProfile",code:2,userInfo:[NSLocalizedDescriptionKey:"Profile interrupted"])}
                        let began=ProcessInfo.processInfo.systemUptime
                        let command=surface.encodeFrame(target:target,deltaTime:0)
                        await command.completed()
                        guard command.status == .completed,command.gpuEndTime>command.gpuStartTime else {throw command.error ?? NSError(domain:"DensityProfile",code:3,userInfo:[NSLocalizedDescriptionKey:"No valid GPU timing"])}
                        if frame>=20 {gpu.append((command.gpuEndTime-command.gpuStartTime)*1000);host.append((ProcessInfo.processInfo.systemUptime-began)*1000)}
                        try await Task.sleep(for:.milliseconds(16))
                    }
                    gpu.sort();host.sort()
                    rows.append(["scene":name,"width":width,"height":height,"particleCount":surface.particleCount,"samples":gpu.count,
                        "gpuMedianMS":gpu[gpu.count/2],"gpuP95MS":gpu[Int(Double(gpu.count)*0.95)],"hostMedianMS":host[host.count/2],"gpuSamplesMS":gpu])
                }
            }
            let result:[String:Any]=["date":ISO8601DateFormatter().string(from:Date()),"start":start,"end":environment.environment(),"results":rows,
                "scope":"Physical-device offscreen surface command buffers. Frozen identical particle fixtures, 20 warm-up plus 120 samples per scene/resolution. Includes fluid reconstruction, glass and composition; excludes solver, presentation and UI. Not displayed FPS or battery evidence."]
            let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("FluidLabReports",isDirectory:true)
            try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
            let url=folder.appendingPathComponent("density-surface-profile.json")
            try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:url,options:.atomic)
            reportURL=url;notice="Surface profile saved. Reset to play again."
        } catch {self.error=error.localizedDescription;notice="Surface profile did not finish."}
    }

    func runTrialIfRequested() async {
        guard !trialStarted,let trial=LabTrialConfiguration.current else { return }
        trialStarted=true
        let arguments=ProcessInfo.processInfo.arguments
        #if os(iOS)
        let previousIdleTimer=UIApplication.shared.isIdleTimerDisabled
        if arguments.contains("--keep-awake") { UIApplication.shared.isIdleTimerDisabled=true }
        defer { UIApplication.shared.isIdleTimerDisabled=previousIdleTimer }
        #endif
        try? await Task.sleep(for:.seconds(2))
        if arguments.contains("--profile-density-surface") {await profileDensitySurface();return}
        if arguments.contains("--visual-review") {return}
        if arguments.contains("--check-density-controls") {await checkDensityTrial();return}
        // Freeze the two tester-reported transitions at useful inspection
        // points on a physical device. These diagnostic replays are isolated
        // from saved play by the trial configuration above.
        if arguments.contains("--level16-partial-return-check"),puzzle == .valveCircuit,presentation == .fluid {
            reset()
            guard let first=availableMove(from:1,to:6),begin(first),
                  let second=availableMove(from:2,to:6),begin(second) else { return }
            while busy && !Task.isCancelled {try? await Task.sleep(for:.milliseconds(16))}
            guard let partial=availableMove(from:0,to:2),begin(partial) else { return }
            var sawFinalSettle=false
            while busy && !Task.isCancelled {
                if fluidFinalSettling {sawFinalSettle=true}
                else if sawFinalSettle {
                    paused=true;updatePause();return
                }
                try? await Task.sleep(for:.milliseconds(8))
            }
            paused=true;updatePause();return
        }
        if arguments.contains("--level16-classic-stream-check"),puzzle == .valveCircuit,presentation == .classic {
            reset()
            guard let move=availableMove(from:1,to:6),begin(move) else { return }
            while busy && !Task.isCancelled {
                if concurrentClassicPours.contains(where:{$0.progress > 0.45 && $0.progress < 0.55}) {
                    paused=true;updatePause();return
                }
                try? await Task.sleep(for:.milliseconds(8))
            }
            paused=true;updatePause();return
        }
        // Deterministic physical-device visual replay for the tester-reported
        // Level 16 shared receiver. It intentionally does not write timing data.
        if arguments.contains("--level16-fill-check"),puzzle == .valveCircuit,presentation == .fluid {
            for repetition in 0..<2 {
                reset()
                guard let first=availableMove(from:1,to:6),begin(first),
                      let second=availableMove(from:2,to:6),begin(second) else { return }
                while busy && !Task.isCancelled {try? await Task.sleep(for:.milliseconds(16))}
                if repetition==0 {try? await Task.sleep(for:.seconds(1))}
            }
            paused=true;updatePause();return
        }
        let checks=arguments.contains("--check-controls") ? await checkTrialControls():[:]
        beginMeasurement()
        if !checks.isEmpty { performance.context["deviceControlChecks"]=checks }
        let concurrentLimit:Int = {
            guard let index=arguments.firstIndex(of:"--maximum-concurrent-pours"),index+1<arguments.count else {return 2}
            return min(state.stacks.count,max(2,Int(arguments[index+1]) ?? 2))
        }()
        if concurrentPoursEnabled,arguments.contains("--concurrent-pours") {
            performance.context["requestedConcurrentPourLimit"]=concurrentLimit
        }
        let start=ProcessInfo.processInfo.systemUptime
        var reason="completed"
        while !Task.isCancelled && ProcessInfo.processInfo.systemUptime-start<trial.seconds {
            if suspended { reason="application suspended";break }
            if concurrentPoursEnabled,arguments.contains("--concurrent-pours") {
                if solved { reset() }
                if pourQueue.items.count<concurrentLimit {
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
    static func name(_ color:Int) -> String {
        let names=["Tide","Ember","Leaf","Petal","Sun","Cream","Violet","Mint","Ruby","Cobalt","Lime","Pearl"]
        return names[(color % names.count+names.count)%names.count]
    }
    static func color(_ value:Int,mixedWith:Int?=nil,blend:Float=0) -> Color {
        let a=colorComponents(value),b=colorComponents(mixedWith ?? value),f=Double(min(1,max(0,blend)))
        let c=a+(b-a)*f
        return Color(red:c.x,green:c.y,blue:c.z)
    }
    private static func colorComponents(_ value:Int)->SIMD3<Double> {
        if value>=36 {return SIMD3(0.34,0.39,0.43)}
        let palette:[(Double,Double,Double)]=[(0.05,0.58,0.86),(0.96,0.34,0.07),(0.20,0.76,0.36),(0.94,0.34,0.65),(1.00,0.72,0.08),(0.98,0.71,0.61),(0.55,0.30,0.95),(0.12,0.78,0.62),(0.72,0.04,0.24),(0.08,0.24,0.88),(0.54,0.78,0.06),(0.82,0.78,0.68)]
        let pigment=(value%12+12)%12,base=palette[pigment]
        return SIMD3(base.0,base.1,base.2)
    }
    func accessibility(_ index:Int) -> String {
        let layers=state.stacks[index].reversed().map { state.isKnown($0) ? "\(state.densities[$0].title) \(Self.name(state.colors[$0]))":"Unknown liquid" }.joined(separator:", ")
        let roles=apparatus(forVial:index).map { tool in
            switch tool.kind {
            case .mixer:return tool.outputs.contains(index) ? "Mixer output.":"Mixer input."
            case .separator:return tool.outputs.contains(index) ? "Separator output.":"Separator input."
            case .densityModifier:return tool.direction == .heavier ? "Make heavier chamber.":"Make lighter chamber."
            }
        }.joined(separator:" ")
        let rule=state.valvePigment(index).map {" Color-keyed valve; its \(Self.name($0)) lid accepts only \(Self.name($0)) liquid, and it cannot pour out."}
            ?? (state.rules[index] == .sourceOnly ? " Apparatus output; it cannot receive a pour.":"")
        let target=state.target(index).map { target in
            " Target bottom to top: "+target.layers.map { "\($0.density.title) \(Self.name($0.pigment))" }.joined(separator:", ")+"."
        } ?? ""
        let vessel=state.helperName(index).map {"\($0) helper \(Self.letter(index))"} ?? "Vial \(Self.letter(index))"
        let helper=state.isHelper(index) ? " Helper vessels must be empty to finish.":""
        return "\(vessel), \(state.stacks[index].count) of \(state.capacity(index)) units.\(rule)\(helper) \(roles) \(layers.isEmpty ? "Empty":"Top to bottom: "+layers).\(target)"+(targetExplanation(index).map {" "+$0} ?? "")
    }
}

extension FluidBoardSession {
    @discardableResult private func beginConcurrent(_ move:LabBoardMove,automaticClock:Bool)->Bool {
        guard !solved,transformation == nil,availableMove(from:move.source,to:move.destination)==move else { return false }
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
        guard concurrentPoursEnabled,transformation == nil,busy,!paused,!suspended,deltaTime.isFinite else { return }
        for (id,time) in concurrentReveals {
            let next=time+min(max(deltaTime,0),0.05)*effectiveSpeed
            concurrentReveals[id]=next>=0.5 ? nil:next
        }
        var queue=pourQueue
        // Do not invalidate an in-progress receiver correction with a new
        // stream. It lasts only the settle interpolation; the next pour starts
        // while the earlier source returns, and each source releases on arrival.
        let settlingReceivers=presentation == .fluid ? Set(metalGroups.filter {$0.value.groupFinalSettling}.keys):Set<Int>()
        let starts=queue.startReady(excludingDestinations:settlingReceivers)
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
            fluid2D.setDisplayGame(game);fluid2D.setConcurrentReveals(concurrentReveals);planarDisplay.publish(fluid2D)
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
                if classicLanes[id]!.finished {
                    let receiver=classicLanes[id]!.move.destination
                    let predecessors=pourQueue.items.filter {$0.id<id && $0.move.destination==receiver}
                    if predecessors.allSatisfy({finished.contains($0.id)}) {finished.append(id)}
                }
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
            var vessels=LabBoardLayout.vessels(profiles:renderer.profiles,capacities:game.state.capacities,move:nil,time:0,tilt:0,cutoffTilt:nil,cutoffElapsed:0,returnElapsed:nil)
            var aggregate=LabBoardMetrics()
            let surfaceGPU=renderer.lastGPUWorkMilliseconds
            aggregate.gpuMilliseconds=surfaceGPU
            var completed:[LabLaneResult]=[],empty:[Int]=[]
            // At 60 Hz, Quick motion needs 3.2 fixed 120 Hz steps and uses a
            // fourth periodically for the remainder. More than four steps per
            // independent lane is therefore hitch recovery, not normal motion.
            // Let a lone lane catch up fully, but prevent two or more lanes
            // from amplifying one delayed callback into another long burst.
            let laneStepBudget=metalGroups.count>1 ? 4:12
            let pressureIterations=metalGroups.count>1 ? 3:5
            if measurementActive {
                performance.context["minimumLaneStepBudget"]=min(
                    performance.context["minimumLaneStepBudget"] as? Int ?? 12,laneStepBudget)
                performance.context["minimumLanePressureIterations"]=min(
                    performance.context["minimumLanePressureIterations"] as? Int ?? 5,pressureIterations)
            }
            for receiver in metalGroups.keys.sorted() {
                let engine=metalGroups[receiver]!
                engine.playbackSpeed=effectiveSpeed
                engine.maximumSimulationStepsPerAdvance=laneStepBudget
                engine.pressureIterationsPerStep=pressureIterations
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
            if state.knownParcels != nil {
                for i in compositeSamples.indices {compositeSamples[i].velocity.w=Float(state.visualDye(Int(compositeSamples[i].visual.y)))}
            }
            renderer.displayComposite(game:game,samples:compositeSamples,vessels:vessels)
            renderer.showConcurrentReveals(concurrentReveals)
            if !busy { settledParticles=compositeSamples }
            performance.recordFluidBreakdown(surfaceMS:surfaceGPU,laneMS:max(0,aggregate.gpuMilliseconds-surfaceGPU))
            performance.recordFrame(interval:Double(deltaTime),cpuMS:(ProcessInfo.processInfo.systemUptime-updateStart)*1000,gpuMS:aggregate.gpuMilliseconds)
        }
        if measurementActive {
            performance.context["maximumConcurrentPours"]=max(performance.context["maximumConcurrentPours"] as? Int ?? 0,pourQueue.active.count)
            let shared=Dictionary(grouping:pourQueue.active,by:{$0.move.destination}).values.map(\.count).max() ?? 0
            performance.context["maximumSharedReceiverPours"]=max(performance.context["maximumSharedReceiverPours"] as? Int ?? 0,shared)
            if presentation == .fluid {
                performance.context["fullBoardParticles"]=renderer?.particleCount ?? 0
                performance.context["maximumLaneSimulationParticles"]=max(
                    performance.context["maximumLaneSimulationParticles"] as? Int ?? 0,active3DSimulationParticleCount)
            }
        }
        refresh()
    }
    private func finishConcurrent(_ result:LabLaneResult) {
        guard let item=pourQueue.items.first(where:{$0.id==result.id}) else { return }
        let knownBefore=state.knownParcels ?? []
        let committed=result.committed && game.commitReserved(item.move)
        if committed,concurrentPoursEnabled {
            for id in (state.knownParcels ?? []).subtracting(knownBefore) {concurrentReveals[id]=0}
        }
        pourQueue.finish(result.id)
        if committed {
            undoParticles.append(nil);lastPour=concurrentExamples[result.id]
            if let message=targetExplanation(item.move.destination) {notice=message}
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
        pourQueue.cancelAll();concurrentExamples=[:];compositeSamples=[];concurrentReveals=[:]
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
        let reloadOK=save?.games[gameKey]?.state==initial
        reset()
        return ["pause":pauseOK,"suspension":suspendOK,"resume":resumeOK,"reset":resetOK,"commit":commitOK,"undo":undoOK,"saveReload":reloadOK]
    }
}

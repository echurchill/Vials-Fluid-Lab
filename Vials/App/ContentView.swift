import SwiftUI

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var feedbackPlayer = GameFeedbackPlayer()

    @State private var selectedMode: LevelMode
    @State private var currentLevel: VialLevel
    @State private var preparedNextLevel: VialLevel?
    @State private var preparedNextLevelKey: LevelGenerationKey?
    @State private var minimumMoveCount: Int?
    @State private var minimumMoveKey: LevelGenerationKey?
    @State private var zenSalt: UInt64
    @State private var vials: [Vial]
    @State private var cup: HelperCup?
    @State private var selectedContainer: ContainerRef?
    @State private var activePours: [PourAnimation]
    @State private var moveCount = 0
    @State private var containerCenters: [ContainerRef: CGPoint] = [:]
    @State private var history: [GameSnapshot] = []
    @State private var invalidContainer: ContainerRef?
    @State private var showWinCelebration = false
    @State private var pourProgresses: [UUID: CGFloat]
    @State private var isAwaitingCompletion = false
    @State private var hintStatus: HintStatus = .idle
    @State private var activeHint: ActiveHint?
    @State private var hintNotice: String?
    @State private var showDeadEndRecovery = false
    @State private var deadEndRecovery: HintRecoveryCandidate?
    @State private var hintRequestID = UUID()
    @State private var levelRating: LevelFeedbackRating?
    @State private var showTesterFeedback = false
    @State private var completionSummary: CompletionSummary?
    @State private var usedHintThisAttempt = false
    @State private var restartPenaltyApplied = false

    init() {
        let savedProgress = GameProgressStore.load()
        let initialVariant = LevelVariantStore.variant(
            for: savedProgress.mode,
            levelNumber: savedProgress.levelNumber,
            zenSalt: savedProgress.zenSalt
        ) ?? 0
        let initialLevel = VialLevelGenerator.generate(
            mode: savedProgress.mode,
            number: savedProgress.levelNumber,
            zenSalt: savedProgress.zenSalt,
            generationVariant: initialVariant
        )
        let initialFeedbackSalt = savedProgress.mode == .zen ? savedProgress.zenSalt : 0

        _selectedMode = State(initialValue: savedProgress.mode)
        _currentLevel = State(initialValue: initialLevel)
        _preparedNextLevel = State(initialValue: nil)
        _preparedNextLevelKey = State(initialValue: nil)
        _minimumMoveCount = State(initialValue: nil)
        _minimumMoveKey = State(initialValue: nil)
        _zenSalt = State(initialValue: savedProgress.zenSalt)
        _vials = State(initialValue: initialLevel.vials)
        _cup = State(initialValue: nil)
        _selectedContainer = State(initialValue: nil)
        _activePours = State(initialValue: [])
        _moveCount = State(initialValue: 0)
        _containerCenters = State(initialValue: [:])
        _history = State(initialValue: [])
        _invalidContainer = State(initialValue: nil)
        _showWinCelebration = State(initialValue: false)
        _pourProgresses = State(initialValue: [:])
        _isAwaitingCompletion = State(initialValue: false)
        _hintStatus = State(initialValue: .idle)
        _activeHint = State(initialValue: nil)
        _hintNotice = State(initialValue: nil)
        _showDeadEndRecovery = State(initialValue: false)
        _deadEndRecovery = State(initialValue: nil)
        _hintRequestID = State(initialValue: UUID())
        _levelRating = State(
            initialValue: LevelFeedbackStore.rating(
                mode: savedProgress.mode,
                levelNumber: savedProgress.levelNumber,
                zenSalt: initialFeedbackSalt
            )
        )
        _showTesterFeedback = State(initialValue: false)
        _completionSummary = State(initialValue: nil)
        _usedHintThisAttempt = State(initialValue: false)
        _restartPenaltyApplied = State(initialValue: false)
    }

    var body: some View {
        ZStack {
            GameBackground()

            VStack(spacing: 0) {
                header

                if isCompactWidth {
                    Color.clear
                        .frame(height: compactBoardTopGap)
                } else {
                    Spacer(minLength: 0)
                }

                vialBoard

                Spacer(minLength: 0)
            }
            .padding(.horizontal, screenPadding)
            .padding(.top, verticalPadding + statusBarClearance)
            .padding(.bottom, verticalPadding)

            hintFeedback

            if showWinCelebration {
                WinCelebrationView(
                    levelNumber: currentLevel.number,
                    moveCount: moveCount,
                    minimumMoveCount: minimumMoveCount,
                    masteryTier: completionSummary?.earnedTier ?? .completion,
                    bestMasteryTier: completionSummary?.bestTier ?? .completion,
                    flow: completionSummary?.flow ?? PlayerResultStore.flow(),
                    wasHintAssisted: completionSummary?.wasHintAssisted ?? false,
                    isFinalLevel: !canAdvance(from: currentLevel),
                    rating: levelRating,
                    ratingAction: rateCurrentLevel,
                    nextAction: {
                        feedbackPlayer.playNavigation()
                        goToLevel(currentLevel.number + 1)
                    },
                    replayAction: {
                        feedbackPlayer.playNavigation()
                        restart()
                    },
                    dismissAction: {
                        feedbackPlayer.playSelection()
                        showWinCelebration = false
                    }
                )
                .transition(.scale(scale: 0.92).combined(with: .opacity))
                .zIndex(4)
            }

            if showDeadEndRecovery {
                DeadEndRecoveryView(
                    undoCount: deadEndRecovery?.actionsToUndo,
                    undoAction: restoreSolvableState,
                    restartAction: restart,
                    dismissAction: dismissDeadEndRecovery
                )
                .zIndex(5)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.34, dampingFraction: 0.78), value: showWinCelebration)
        .onAppear {
            feedbackPlayer.prepare()

            if preparedNextLevelKey == nil {
                prepareNextLevel(after: currentLevel)
            }

            prepareMinimumMoveCount(for: currentLevel)
        }
        .sheet(isPresented: $showTesterFeedback) {
            TesterFeedbackView()
        }
    }

    private var levelZoom: CGFloat {
        currentLevel.zoom
    }

    private var vialWidth: CGFloat {
        82 * levelZoom
    }

    private var fluidUnitHeight: CGFloat {
        30 * levelZoom
    }

    private var boardItems: [BoardItem] {
        vials.indices.map(BoardItem.vial) + [.cup]
    }

    private var header: some View {
        HStack(spacing: 12) {
            gameMenu

            headerTitle

            Spacer(minLength: 8)

            iconButton(
                systemName: "arrow.uturn.backward",
                label: "Undo",
                width: compactControlSize,
                isDisabled: history.isEmpty || hasActivePours
            ) {
                feedbackPlayer.playNavigation()
                undoMove()
            }
        }
    }

    private var headerTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Vials")
                .font(.system(size: titleFontSize, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(levelSubtitle)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var levelSubtitle: String {
        let levelName = "\(selectedMode.displayName) Level \(currentLevel.number)"
        guard let rampMessage = currentLevel.rampMessage else { return levelName }
        return "\(levelName) · \(rampMessage)"
    }

    private var gameMenu: some View {
        Menu {
            Section("Level") {
                Button {
                    feedbackPlayer.playNavigation()
                    goToLevel(currentLevel.number - 1)
                } label: {
                    Label("Previous level", systemImage: "chevron.left")
                }
                .disabled(currentLevel.number == 1 || hasActivePours)

                Button {
                    feedbackPlayer.playNavigation()
                    goToLevel(currentLevel.number + 1)
                } label: {
                    Label("Next level", systemImage: "chevron.right")
                }
                .disabled(hasActivePours || !canAdvance(from: currentLevel))

                Button {
                    feedbackPlayer.playNavigation()
                    restart()
                } label: {
                    Label("Restart level", systemImage: "arrow.counterclockwise")
                }
                .disabled(hasActivePours)
            }

            Section("Difficulty") {
                ForEach(LevelMode.visibleCases) { mode in
                    Button {
                        feedbackPlayer.playNavigation()
                        switchMode(to: mode)
                    } label: {
                        Label(mode.displayName, systemImage: selectedMode == mode ? "checkmark" : mode.systemImage)
                    }
                }
            }

            Section("Progress") {
                Label("\(moveCount) moves", systemImage: "drop.fill")
            }

            Section("Help") {
                Button(action: requestHint) {
                    Label(hintStatus == .searching ? "Finding a route…" : "Find a hint", systemImage: "sparkles")
                }
                .disabled(hasActivePours || hintStatus == .searching || showWinCelebration)
            }

            Section("Tester") {
                Button {
                    showTesterFeedback = true
                } label: {
                    Label("View tester feedback", systemImage: "chart.bar.doc.horizontal")
                }
            }
        } label: {
            AppBadgeMark()
                .frame(width: appBadgeSize, height: appBadgeSize)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .background(.indigo.opacity(0.7), in: Circle())
                        .offset(x: 2, y: 2)
                }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(hasActivePours)
        .help("Game menu")
        .accessibilityLabel("Game menu")
    }

    private var vialBoard: some View {
        GeometryReader { proxy in
            let rows = boardRows(for: boardItems, availableWidth: proxy.size.width)

            ZStack {
                VStack(spacing: boardRowSpacing) {
                    ForEach(rows.indices, id: \.self) { rowIndex in
                        let slotHeight = slotHeight(for: rows[rowIndex])
                        HStack(spacing: boardColumnSpacing) {
                            ForEach(rows[rowIndex]) { item in
                                boardSlot(for: item, slotHeight: slotHeight)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.vertical, 4 * levelZoom)
                .frame(maxWidth: boardMaxWidth(for: proxy.size.width))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: boardContentAlignment)

                ForEach(activePours, id: \.id) { pour in
                    if let source = containerCenters[pour.source],
                       let destination = containerCenters[pour.destination] {
                        PourStreamView(
                            source: pourStart(from: source, toward: destination, container: pour.source),
                            destination: pourEnd(at: destination, container: pour.destination),
                            fluid: pour.fluid,
                            amount: pour.amount
                        )
                        .allowsHitTesting(false)
                        .id(pour.id)
                    }
                }

                if let activeHint,
                   let source = containerCenters[activeHint.source],
                   let destination = containerCenters[activeHint.destination] {
                    HintArcView(source: source, destination: destination)
                        .allowsHitTesting(false)
                }
            }
            .coordinateSpace(name: "vialBoard")
            .onPreferenceChange(ContainerCenterPreferenceKey.self) { centers in
                containerCenters = centers
            }
        }
        .frame(height: boardHeight)
    }

    @ViewBuilder
    private func boardSlot(for item: BoardItem, slotHeight: CGFloat) -> some View {
        switch item {
        case .vial(let index):
            let container = ContainerRef.vial(index)

            VialSlot(
                vial: vials[index],
                index: index,
                slotHeight: slotHeight,
                vialWidth: vialWidth,
                vialHeight: vialHeight(for: vials[index].capacity),
                unitHeight: fluidUnitHeight,
                isSelected: selectedContainer == container,
                isInvalid: invalidContainer == container,
                pourTilt: tiltForVial(at: index),
                visualPour: visualPourAdjustment(for: container),
                hintHighlight: hintHighlight(for: container)
            ) {
                handleTap(on: container)
            }
            .background {
                centerPreference(for: container)
            }

        case .cup:
            if let cup {
                HelperCupSlot(
                    cup: cup,
                    slotHeight: slotHeight,
                    vialWidth: vialWidth,
                    unitHeight: fluidUnitHeight,
                    isSelected: selectedContainer == .cup,
                    isInvalid: invalidContainer == .cup,
                    isPouring: activePours.contains { $0.source == .cup },
                    visualPour: visualPourAdjustment(for: .cup),
                    canIncreaseHeight: cup.capacity < currentLevel.maxCapacity,
                    hintHighlight: hintHighlight(for: .cup)
                ) {
                    handleTap(on: .cup)
                } increaseHeightAction: {
                    increaseCupHeight()
                }
                .background {
                    centerPreference(for: .cup)
                }
            } else {
                AddCupSlot(
                    slotHeight: slotHeight,
                    vialWidth: vialWidth,
                    unitHeight: fluidUnitHeight,
                    isDisabled: hasActivePours
                ) {
                    buyCup()
                }
            }
        }
    }

    private var isSolved: Bool {
        vials.allSatisfy { $0.fluids.isEmpty || $0.isComplete } && isHelperBeakerSettled
    }

    private var isHelperBeakerSettled: Bool {
        guard let cup, !cup.fluids.isEmpty else { return true }
        return Set(cup.fluids).count == 1
    }

    private var hasActivePours: Bool {
        !activePours.isEmpty
    }

    @ViewBuilder
    private var hintFeedback: some View {
        switch hintStatus {
        case .searching:
            HintSearchStatusView()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, hintFeedbackTopInset)
                .allowsHitTesting(false)
        case .idle:
            if activeHint != nil {
                HintMovePromptView(text: "Try this pour", dismissAction: dismissHint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, hintFeedbackTopInset)
            } else if let hintNotice {
                HintMovePromptView(text: hintNotice, dismissAction: dismissHint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, hintFeedbackTopInset)
            }
        }
    }

    private func centerPreference(for container: ContainerRef) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: ContainerCenterPreferenceKey.self,
                value: [container: proxy.frame(in: .named("vialBoard")).center]
            )
        }
    }

    private func iconButton(systemName: String, label: String, width: CGFloat = 44, isDisabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .black))
                .frame(width: width, height: compactControlSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isDisabled ? .white.opacity(0.28) : .white)
        .background(.white.opacity(isDisabled ? 0.05 : 0.11), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(isDisabled ? 0.06 : 0.16), lineWidth: 1)
        }
        .disabled(isDisabled)
        .help(label)
        .accessibilityLabel(label)
    }

    private func boardMaxWidth(for width: CGFloat) -> CGFloat {
        width
    }

    private func boardRows(for items: [BoardItem], availableWidth: CGFloat) -> [[BoardItem]] {
        let slotWidth = vialWidth + boardColumnSpacing
        let maxItemsPerRow = max(1, Int((availableWidth + boardColumnSpacing) / slotWidth))
        guard items.count > maxItemsPerRow else { return [items] }

        let preferredTopCount = Int(ceil(Double(items.count) / 2.0))

        if preferredTopCount <= maxItemsPerRow {
            return [Array(items.prefix(preferredTopCount)), Array(items.dropFirst(preferredTopCount))]
        }

        return stride(from: 0, to: items.count, by: maxItemsPerRow).map { start in
            let end = min(start + maxItemsPerRow, items.count)
            return Array(items[start..<end])
        }
    }

    private func slotHeight(for items: [BoardItem]) -> CGFloat {
        let largestCapacity = items.map(capacity(for:)).max() ?? 1
        let includesHelperBeaker = items.contains { item in
            if case .cup = item { return cup != nil }
            return false
        }
        let addControlHeight = includesHelperBeaker ? 28 * levelZoom : 0
        return vialHeight(for: largestCapacity) + addControlHeight
    }

    private func capacity(for item: BoardItem) -> Int {
        switch item {
        case .vial(let index):
            vials[index].capacity
        case .cup:
            cup?.capacity ?? 1
        }
    }

    private var boardColumnSpacing: CGFloat {
        max(8, 14 * levelZoom)
    }

    private var boardRowSpacing: CGFloat {
        (isCompactWidth ? 18 : 28) * levelZoom
    }

    private var compactControlSize: CGFloat {
        isCompactWidth ? 42 : 44
    }

    private var screenPadding: CGFloat {
        isCompactWidth ? 18 : 24
    }

    private var verticalPadding: CGFloat {
        isCompactWidth ? 18 : 24
    }

    private var compactBoardTopGap: CGFloat {
        8
    }

    private var boardContentAlignment: Alignment {
        isCompactWidth ? .top : .center
    }

    private var appBadgeSize: CGFloat {
        isCompactWidth ? 42 : 46
    }

    private var titleFontSize: CGFloat {
        isCompactWidth ? 30 : 34
    }

    private var isCompactWidth: Bool {
        horizontalSizeClass == .compact
    }

    private var boardHeight: CGFloat {
        let rows = boardRows(for: boardItems, availableWidth: estimatedBoardWidth)
        let contentHeight = rows.reduce(CGFloat.zero) { height, row in
            height + slotHeight(for: row)
        } + CGFloat(max(0, rows.count - 1)) * boardRowSpacing
        let preferredHeight = contentHeight + 12 * levelZoom

        if isCompactWidth {
            return max(240, preferredHeight)
        }

        return min(560, max(280, preferredHeight))
    }

    private var estimatedBoardWidth: CGFloat {
        isCompactWidth ? 390 : 900
    }

    private func vialHeight(for capacity: Int) -> CGFloat {
        (44 + CGFloat(capacity) * 30) * levelZoom
    }

    private var statusBarClearance: CGFloat {
        isCompactWidth ? 22 : 0
    }

    private var hintFeedbackTopInset: CGFloat {
        isCompactWidth ? 112 : 88
    }

    private func handleTap(on container: ContainerRef) {
        guard !showWinCelebration, !isAwaitingCompletion else { return }
        clearHint()

        if let selectedContainer {
            if selectedContainer == container {
                self.selectedContainer = nil
                feedbackPlayer.playSelection()
                return
            }

            attemptPour(from: selectedContainer, to: container)
        } else if topFluid(in: container) == nil || !canPourOut(from: container) || isLockedForOutgoing(container) {
            reject(container)
        } else {
            selectedContainer = container
            feedbackPlayer.playSelection()
        }
    }

    private func attemptPour(from source: ContainerRef, to destination: ContainerRef) {
        guard source != destination else { return }
        guard let move = pourMove(from: source, to: destination) else {
            selectedContainer = nil
            reject(destination)
            return
        }

        selectedContainer = nil
        let pour = PourAnimation(source: source, destination: destination, fluid: move.fluid, amount: move.amount)
        history.append(snapshot)
        apply(move, from: source, to: destination)
        moveCount += 1
        activePours.append(pour)
        pourProgresses[pour.id] = 0
        isAwaitingCompletion = isSolved
        feedbackPlayer.playPour(fluid: move.fluid)

        withAnimation(.easeInOut(duration: move.fluid.material.pourDuration)) {
            pourProgresses[pour.id] = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + move.fluid.material.pourDuration) {
            finish(pour)
        }
    }

    private func finish(_ pour: PourAnimation) {
        guard activePours.contains(where: { $0.id == pour.id }) else { return }
        activePours.removeAll { $0.id == pour.id }
        pourProgresses[pour.id] = nil

        if activePours.isEmpty, isSolved {
            isAwaitingCompletion = false
            if !showWinCelebration {
                feedbackPlayer.playLevelComplete()
                recordCompletion()
                showWinCelebration = true
            }
        }
    }

    private func buyCup() {
        guard !hasActivePours, cup == nil else { return }
        clearHint()
        showWinCelebration = false
        history.append(snapshot)
        cup = HelperCup()
        selectedContainer = nil
        feedbackPlayer.playCupReady()
    }

    private func rateCurrentLevel(_ rating: LevelFeedbackRating) {
        LevelFeedbackStore.record(
            rating: rating,
            mode: currentLevel.mode,
            levelNumber: currentLevel.number,
            zenSalt: generationSalt(for: currentLevel.mode),
            moveCount: moveCount,
            minimumMoveCount: minimumMoveCount
        )
        levelRating = rating
        feedbackPlayer.playSelection()
    }

    private func increaseCupHeight() {
        guard !hasActivePours,
              var cup,
              cup.capacity < currentLevel.maxCapacity else { return }

        clearHint()
        history.append(snapshot)
        cup.capacity += 1
        self.cup = cup
        feedbackPlayer.playSelection()
    }

    private var snapshot: GameSnapshot {
        GameSnapshot(vials: vials, cup: cup, moveCount: moveCount)
    }

    private func pourMove(from source: ContainerRef, to destination: ContainerRef) -> PourMove? {
        guard canSchedulePour(from: source, to: destination) else { return nil }
        guard canPourOut(from: source) else { return nil }
        guard let fluid = topFluid(in: source) else { return nil }
        guard availableSpace(in: destination) > 0 else { return nil }

        let destinationTop = topFluid(in: destination)
        guard destinationTop == nil || destinationTop == fluid else { return nil }

        return PourMove(
            fluid: fluid,
            amount: min(topRunLength(in: source), availableSpace(in: destination))
        )
    }

    private func canSchedulePour(from source: ContainerRef, to destination: ContainerRef) -> Bool {
        guard activePours.count < 3 else { return false }
        guard !isLockedForOutgoing(source) else { return false }
        guard !activePours.contains(where: { $0.source == destination }) else { return false }
        return true
    }

    private func isLockedForOutgoing(_ container: ContainerRef) -> Bool {
        activePours.contains { $0.source == container || $0.destination == container }
    }

    private func apply(_ move: PourMove, from source: ContainerRef, to destination: ContainerRef) {
        switch source {
        case .vial(let index):
            vials[index].fluids.removeLast(move.amount)
        case .cup:
            cup?.fluids.removeLast(move.amount)
        }

        switch destination {
        case .vial(let index):
            vials[index].fluids.append(contentsOf: Array(repeating: move.fluid, count: move.amount))
        case .cup:
            cup?.fluids.append(contentsOf: Array(repeating: move.fluid, count: move.amount))
        }
    }

    private func topFluid(in container: ContainerRef) -> Fluid? {
        switch container {
        case .vial(let index):
            vials[index].topFluid
        case .cup:
            cup?.topFluid
        }
    }

    private func canPourOut(from container: ContainerRef) -> Bool {
        switch container {
        case .vial(let index):
            vials[index].canPourOut
        case .cup:
            true
        }
    }

    private func availableSpace(in container: ContainerRef) -> Int {
        switch container {
        case .vial(let index):
            vials[index].availableSpace
        case .cup:
            cup?.availableSpace ?? 0
        }
    }

    private func topRunLength(in container: ContainerRef) -> Int {
        switch container {
        case .vial(let index):
            vials[index].topRunLength
        case .cup:
            cup?.topRunLength ?? 0
        }
    }

    private func requestHint() {
        guard !hasActivePours,
              !showWinCelebration,
              hintStatus != .searching else { return }

        clearHint()
        let requestID = UUID()
        let requestVials = vials
        let requestCup = cup
        let requestHistory = history
        let nodeLimit = hintNodeLimit(for: selectedMode)
        hintRequestID = requestID
        hintStatus = .searching

        Task.detached(priority: .userInitiated) {
            let result = VialLevelGenerator.hint(
                vials: requestVials,
                helperBeaker: requestCup,
                nodeLimit: nodeLimit
            )
            let recovery: HintRecoveryCandidate?

            if case .deadEnd = result {
                recovery = VialLevelGenerator.latestSolvableHistory(
                    requestHistory,
                    nodeLimit: max(45_000, nodeLimit / 2)
                )
            } else {
                recovery = nil
            }

            await MainActor.run {
                guard hintRequestID == requestID else { return }
                hintStatus = .idle

                switch result {
                case .move(let move):
                    guard let source = container(forHintIndex: move.sourceIndex),
                          let destination = container(forHintIndex: move.destinationIndex) else {
                        hintNotice = "That route is no longer available"
                        return
                    }

                    activeHint = ActiveHint(move: move, source: source, destination: destination)
                    usedHintThisAttempt = true
                    feedbackPlayer.playSelection()
                case .solved:
                    hintNotice = "This level is already solved"
                case .deadEnd:
                    deadEndRecovery = recovery
                    showDeadEndRecovery = true
                    feedbackPlayer.playInvalidMove()
                case .searchLimitReached:
                    hintNotice = "Route needs more time"
                }
            }
        }
    }

    private func hintNodeLimit(for mode: LevelMode) -> Int {
        switch mode {
        case .easy:
            140_000
        case .medium:
            300_000
        case .hard:
            300_000
        case .experiments:
            120_000
        case .zen:
            70_000
        }
    }

    private func container(forHintIndex index: Int) -> ContainerRef? {
        if vials.indices.contains(index) {
            return .vial(index)
        }

        if index == vials.count, cup != nil {
            return .cup
        }

        return nil
    }

    private func hintHighlight(for container: ContainerRef) -> HintHighlight? {
        guard let activeHint else { return nil }
        if container == activeHint.source { return .source }
        if container == activeHint.destination { return .destination }
        return nil
    }

    private func dismissHint() {
        activeHint = nil
        hintNotice = nil
    }

    private func clearHint() {
        hintRequestID = UUID()
        hintStatus = .idle
        activeHint = nil
        hintNotice = nil
        showDeadEndRecovery = false
        deadEndRecovery = nil
    }

    private func cancelActivePours() {
        activePours.removeAll()
        pourProgresses.removeAll()
        isAwaitingCompletion = false
    }

    private func dismissDeadEndRecovery() {
        showDeadEndRecovery = false
        deadEndRecovery = nil
    }

    private func restoreSolvableState() {
        guard let recovery = deadEndRecovery,
              history.indices.contains(recovery.historyIndex) else { return }

        let snapshot = history[recovery.historyIndex]
        clearHint()
        vials = snapshot.vials
        cup = snapshot.cup
        moveCount = snapshot.moveCount
        selectedContainer = nil
        cancelActivePours()
        history = Array(history.prefix(recovery.historyIndex))
        invalidContainer = nil
        feedbackPlayer.playNavigation()
    }

    private func reject(_ container: ContainerRef) {
        invalidContainer = container
        feedbackPlayer.playInvalidMove()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
            if invalidContainer == container {
                invalidContainer = nil
            }
        }
    }

    private func undoMove() {
        guard let previous = history.popLast() else { return }
        clearHint()
        vials = previous.vials
        cup = previous.cup
        moveCount = previous.moveCount
        selectedContainer = nil
        cancelActivePours()
        showWinCelebration = false
    }

    private func restart() {
        if moveCount > 0, !showWinCelebration, !restartPenaltyApplied {
            PlayerResultStore.applyRestartFlowPenalty()
            restartPenaltyApplied = true
        }
        clearHint()
        vials = currentLevel.vials
        cup = nil
        moveCount = 0
        selectedContainer = nil
        cancelActivePours()
        history.removeAll()
        invalidContainer = nil
        showWinCelebration = false
        completionSummary = nil
        usedHintThisAttempt = false
    }

    private func goToLevel(_ number: Int) {
        guard !hasActivePours else { return }
        clearHint()
        let maximumLevel = selectedMode.maximumLevel ?? Int.max
        let levelNumber = min(maximumLevel, max(1, number))
        let key = LevelGenerationKey(mode: selectedMode, number: levelNumber, zenSalt: generationSalt(for: selectedMode))
        let level: VialLevel

        if preparedNextLevelKey == key, let preparedNextLevel {
            level = preparedNextLevel
        } else {
            level = generatedLevel(mode: selectedMode, number: levelNumber)
        }

        load(level)
    }

    private func switchMode(to mode: LevelMode) {
        guard !hasActivePours, selectedMode != mode else { return }
        clearHint()
        selectedMode = mode
        load(generatedLevel(mode: mode, number: 1))
    }

    private func load(_ level: VialLevel) {
        clearHint()
        currentLevel = level
        levelRating = LevelFeedbackStore.rating(
            mode: level.mode,
            levelNumber: level.number,
            zenSalt: generationSalt(for: level.mode)
        )
        cup = nil
        vials = level.vials
        moveCount = 0
        selectedContainer = nil
        cancelActivePours()
        history.removeAll()
        invalidContainer = nil
        showWinCelebration = false
        completionSummary = nil
        usedHintThisAttempt = false
        restartPenaltyApplied = false
        GameProgressStore.save(mode: level.mode, levelNumber: level.number, zenSalt: zenSalt)
        prepareNextLevel(after: level)
        prepareMinimumMoveCount(for: level)
    }

    private func prepareMinimumMoveCount(for level: VialLevel) {
        if let exactMinimumMoveCount = level.exactMinimumMoveCount {
            minimumMoveCount = exactMinimumMoveCount
            minimumMoveKey = LevelGenerationKey(mode: level.mode, number: level.number, zenSalt: generationSalt(for: level.mode))
            return
        }

        let key = LevelGenerationKey(mode: level.mode, number: level.number, zenSalt: generationSalt(for: level.mode))
        let nodeLimit = minimumMoveNodeLimit(for: level.mode)
        minimumMoveCount = nil
        minimumMoveKey = key

        Task.detached(priority: .utility) {
            let minimumMoves = VialLevelGenerator.minimumMoveCount(level.vials, nodeLimit: nodeLimit)

            await MainActor.run {
                guard minimumMoveKey == key else { return }
                minimumMoveCount = minimumMoves
                if let minimumMoves {
                    PlayerResultStore.recordKnownMinimum(
                        mode: level.mode,
                        levelNumber: level.number,
                        zenSalt: generationSalt(for: level.mode),
                        minimumMoveCount: minimumMoves
                    )
                }
            }
        }
    }

    private func minimumMoveNodeLimit(for mode: LevelMode) -> Int {
        switch mode {
        case .easy:
            180_000
        case .medium:
            140_000
        case .hard:
            90_000
        case .experiments:
            120_000
        case .zen:
            70_000
        }
    }

    private func prepareNextLevel(after level: VialLevel) {
        guard canAdvance(from: level) else {
            preparedNextLevel = nil
            preparedNextLevelKey = nil
            return
        }

        let key = LevelGenerationKey(mode: level.mode, number: level.number + 1, zenSalt: generationSalt(for: level.mode))
        preparedNextLevel = nil
        preparedNextLevelKey = key

        Task.detached(priority: .utility) {
            let generatedLevel = VialLevelGenerator.generateTuned(
                mode: key.mode,
                number: key.number,
                zenSalt: key.zenSalt
            )

            await MainActor.run {
                guard currentLevel.mode == key.mode, currentLevel.number + 1 == key.number else { return }
                LevelVariantStore.save(
                    generatedLevel.generationVariant,
                    for: key.mode,
                    levelNumber: key.number,
                    zenSalt: key.zenSalt
                )
                preparedNextLevel = generatedLevel
                preparedNextLevelKey = key
            }
        }
    }

    private func generatedLevel(mode: LevelMode, number: Int) -> VialLevel {
        let salt = generationSalt(for: mode)
        return VialLevelGenerator.generate(
            mode: mode,
            number: number,
            zenSalt: salt,
            generationVariant: LevelVariantStore.variant(for: mode, levelNumber: number, zenSalt: salt) ?? 0
        )
    }

    private func generationSalt(for mode: LevelMode) -> UInt64 {
        mode == .zen ? zenSalt : 0
    }

    private func canAdvance(from level: VialLevel) -> Bool {
        guard let maximumLevel = level.mode.maximumLevel else { return true }
        return level.number < maximumLevel
    }

    private func recordCompletion() {
        completionSummary = PlayerResultStore.recordCompletion(
            mode: currentLevel.mode,
            levelNumber: currentLevel.number,
            zenSalt: generationSalt(for: currentLevel.mode),
            moveCount: moveCount,
            minimumMoveCount: minimumMoveCount,
            hintAssisted: usedHintThisAttempt
        )
    }

    private func tiltForVial(at index: Int) -> VialSlot.PourTilt? {
        guard let activePour = activePours.first(where: { $0.source == .vial(index) }) else { return nil }
        let sourceX = containerCenters[activePour.source]?.x ?? 0
        let destinationX = containerCenters[activePour.destination]?.x ?? sourceX
        return destinationX >= sourceX ? .right : .left
    }

    private func pourStart(from source: CGPoint, toward destination: CGPoint, container: ContainerRef) -> CGPoint {
        let direction: CGFloat = destination.x >= source.x ? 1 : -1

        switch container {
        case .vial:
            return CGPoint(x: source.x + direction * 34 * levelZoom, y: source.y - 52 * levelZoom)
        case .cup:
            return CGPoint(x: source.x + direction * 18 * levelZoom, y: source.y - 20 * levelZoom)
        }
    }

    private func pourEnd(at destination: CGPoint, container: ContainerRef) -> CGPoint {
        switch container {
        case .vial:
            CGPoint(x: destination.x, y: destination.y - 78 * levelZoom)
        case .cup:
            CGPoint(x: destination.x, y: destination.y - 18 * levelZoom)
        }
    }

    private func visualPourAdjustment(for container: ContainerRef) -> VisualPourAdjustment? {
        let outgoing = activePours.filter { $0.source == container }
        if !outgoing.isEmpty {
            return VisualPourAdjustment(
                role: .source,
                baseFluids: fluids(in: container),
                transfers: outgoing.map(transferVisual)
            )
        }

        let incoming = activePours.filter { $0.destination == container }
        if !incoming.isEmpty {
            let activeUnits = incoming.reduce(0) { $0 + $1.amount }
            let settledFluids = fluids(in: container)
            return VisualPourAdjustment(
                role: .destination,
                baseFluids: Array(settledFluids.dropLast(min(activeUnits, settledFluids.count))),
                transfers: incoming.map(transferVisual)
            )
        }

        return nil
    }

    private func transferVisual(for pour: PourAnimation) -> VisualPourAdjustment.Transfer {
        VisualPourAdjustment.Transfer(
            fluid: pour.fluid,
            amount: pour.amount,
            progress: pourProgresses[pour.id] ?? 0
        )
    }

    private func fluids(in container: ContainerRef) -> [Fluid] {
        switch container {
        case .vial(let index):
            vials[index].fluids
        case .cup:
            cup?.fluids ?? []
        }
    }
}

private struct LevelGenerationKey: Equatable {
    let mode: LevelMode
    let number: Int
    let zenSalt: UInt64
}

private enum HintStatus: Equatable {
    case idle
    case searching
}

private struct ActiveHint: Equatable {
    let move: HintMove
    let source: ContainerRef
    let destination: ContainerRef
}

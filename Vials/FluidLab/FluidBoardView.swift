import SwiftUI
import MetalKit
import Combine

private enum BoardSheet:String,Identifiable { case classic,study,journey,course;var id:String { rawValue } }

private struct LabSortingCourseBrowserView:View {
    let current:Int?
    let completed:Set<Int>
    let completion:(Int)->LabCompletionRecord?
    let choose:(Int)->Void
    let close:()->Void
    @State private var rangeStart:Int
    private let ink=Color(red:0.80,green:0.88,blue:0.90)
    private let accent=Color(red:0.28,green:0.85,blue:0.79)
    private var starts:[Int] {stride(from:1,through:LabSortingCourseBoard.levelCount,by:25).map {$0}}
    private var rangeEnd:Int {min(rangeStart+24,LabSortingCourseBoard.levelCount)}
    private var rangeCompleted:Int {(rangeStart...rangeEnd).filter(completed.contains).count}
    private var columns:[GridItem] {[GridItem(.adaptive(minimum:68,maximum:92),spacing:10)]}
    init(current:Int?,completed:Set<Int>,completion:@escaping (Int)->LabCompletionRecord?,choose:@escaping (Int)->Void,close:@escaping ()->Void) {
        self.current=current;self.completed=completed;self.completion=completion;self.choose=choose;self.close=close
        let selected=max(1,min(LabSortingCourseBoard.levelCount,current ?? 1))
        _rangeStart=State(initialValue:((selected-1)/25)*25+1)
    }
    private func accessibilityValue(_ number:Int)->String {
        var parts=[number.isMultiple(of:5) ? "Discovery level":"Sorting level"]
        if current==number {parts.append("current")}
        guard completed.contains(number) else {parts.append("not completed");return parts.joined(separator:", ")}
        parts.append("completed")
        if let record=completion(number) {
            if record.lastUsedHint {parts.append("last completed with a hint")}
            if record.lastUsedHelper {parts.append("last completed with a helper")}
            if !record.lastUsedHint && !record.lastUsedHelper {parts.append("last completed without hints or helpers")}
        }
        return parts.joined(separator:", ")
    }
    var body:some View {
        NavigationStack {
            VStack(alignment:.leading,spacing:18) {
                VStack(alignment:.leading,spacing:5) {
                    Text("Choose any level").font(.title2.weight(.semibold))
                    Text("\(completed.count) of \(LabSortingCourseBoard.levelCount) complete · \(rangeCompleted) in this group")
                        .font(.subheadline.monospacedDigit()).foregroundStyle(ink.opacity(0.68))
                }
                Picker("Level group",selection:$rangeStart) {
                    ForEach(starts,id:\.self) {start in
                        Text("\(start)–\(min(start+24,LabSortingCourseBoard.levelCount))").tag(start)
                    }
                }.pickerStyle(.segmented).accessibilityIdentifier("sortingCourse.browser.range")
                ScrollView {
                    LazyVGrid(columns:columns,spacing:10) {
                        ForEach(rangeStart...rangeEnd,id:\.self) {number in
                            let record=completion(number)
                            let isComplete=completed.contains(number)
                            let isCurrent=current==number
                            Button {choose(number)} label: {
                                VStack(spacing:7) {
                                    HStack(spacing:4) {
                                        Text("\(number)").font(.headline.monospacedDigit())
                                        Spacer(minLength:0)
                                        if number.isMultiple(of:5) {
                                            Image(systemName:"eye.slash.fill").font(.caption2).foregroundStyle(Color.cyan)
                                        }
                                    }
                                    HStack(spacing:6) {
                                        if isComplete {Image(systemName:"checkmark.circle.fill").foregroundStyle(accent)}
                                        if record?.lastUsedHint==true {Image(systemName:"lightbulb.fill").foregroundStyle(Color.yellow.opacity(0.88))}
                                        if record?.lastUsedHelper==true {Image(systemName:"cup.and.saucer.fill").foregroundStyle(Color.mint)}
                                        if !isComplete {Image(systemName:"circle").foregroundStyle(ink.opacity(0.22))}
                                        Spacer(minLength:0)
                                    }.font(.caption)
                                }
                                .padding(9).frame(maxWidth:.infinity,minHeight:64)
                                .background(isComplete ? accent.opacity(0.10):Color.white.opacity(0.035),in:RoundedRectangle(cornerRadius:10))
                                .overlay(RoundedRectangle(cornerRadius:10).stroke(isCurrent ? accent:ink.opacity(0.12),lineWidth:isCurrent ? 2:1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Level \(number)")
                            .accessibilityValue(accessibilityValue(number))
                            .accessibilityIdentifier("sortingCourse.browser.level.\(number)")
                        }
                    }.padding(.vertical,2)
                }
                VStack(alignment:.leading,spacing:7) {
                    HStack(spacing:14) {
                        Label("Completed",systemImage:"checkmark.circle.fill")
                        Label("Discovery",systemImage:"eye.slash.fill")
                        Label("Hint",systemImage:"lightbulb.fill")
                        Label("Helper",systemImage:"cup.and.saucer.fill")
                    }.font(.caption).foregroundStyle(ink.opacity(0.78))
                    Text("Hint and helper symbols describe the most recent completion. They do not affect progress or unlocks.")
                        .font(.caption).foregroundStyle(ink.opacity(0.58))
                }
            }
            .padding(22).background(Color(red:0.026,green:0.043,blue:0.060)).foregroundStyle(ink)
            .navigationTitle("Sorting Course")
            .toolbar {
                ToolbarItem(placement:.cancellationAction) {Button("Close",action:close)}
            }
        }.preferredColorScheme(.dark)
    }
}

struct FluidBoardView:View {
    @StateObject private var session=FluidBoardSession(allowsConcurrentPours:true)
    @State private var showResetProgress=false
    @State private var showLearningGuide=false
    @State private var learningTopics:[LabLearningTopic]=[]
    @State private var learningIndex=0
    @State private var inspectedApparatus:LabApparatus?
    @State private var connectionPreviewID:Int?
    @State private var sheet:BoardSheet?
    @State private var comparison:LabPourExample?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private let ink=Color(red:0.80,green:0.88,blue:0.90)
    private let accent=Color(red:0.28,green:0.85,blue:0.79)
    private let machineAccent=Color(red:0.78,green:0.62,blue:1)
    private func openSortingCourse(level:Int?=nil) {
        let number=min(LabSortingCourseBoard.levelCount,max(1,level ?? session.sortingCourseBoard?.number ?? 1))
        if let board=LabSortingCourseBoard.level(number) {session.changeSortingCourseBoard(board)}
    }
    private func openEndless(_ difficulty:LabEndlessDifficulty,level:Int?=nil) {
        let remembered=session.endlessBoard?.difficulty==difficulty ? session.endlessBoard?.number:nil
        let number=max(1,level ?? remembered ?? 1)
        session.changeEndlessBoard(.generated(difficulty:difficulty,number:number))
    }
    private func openValves(level:Int?=nil) {
        let number=min(LabValveBoard.levelCount,max(1,level ?? session.valveBoard?.number ?? 1))
        if let board=LabValveBoard.generated(number:number) {session.changeValveBoard(board)}
    }
    private var focusedApparatus:LabApparatus? {
        if let transition=session.transformation,!transition.isRevealing {return transition.apparatus}
        guard !session.busy else {return nil}
        let id=inspectedApparatus?.id ?? connectionPreviewID ?? session.hintApparatusID
        return session.state.apparatus.first {$0.id==id}
    }
    private func machineRoute(_ tool:LabApparatus)->String {
        let inputs=tool.inputs.map(FluidBoardSession.letter).joined(separator:" + ")
        if tool.kind == .densityModifier {return "Chamber "+inputs}
        let outputs=tool.outputs.map(FluidBoardSession.letter).joined(separator:" + ")
        return (tool.inputs.count==1 ? "Input ":"Inputs ")+inputs+" → "+(tool.outputs.count==1 ? "Output ":"Outputs ")+outputs
    }
    private func machineMembership(_ index:Int)->String {
        guard let tool=focusedApparatus else {return ""}
        if tool.kind == .densityModifier,tool.inputs.contains(index) {return tool.title+" chamber"}
        if tool.inputs.contains(index) {return tool.title+" input"}
        if tool.outputs.contains(index) {return tool.title+" output"}
        return ""
    }
    private func openLearningGuide(firstUse:Bool) {
        guard !session.busy,sheet==nil,comparison==nil,!showResetProgress,!showLearningGuide else {return}
        if firstUse {
            guard LabTrialConfiguration.current==nil,scenePhase == .active,session.moveCount==0,!session.solved,
                  session.selected==nil,inspectedApparatus==nil,!session.findingHint,
                  session.hintTarget==nil,session.hintApparatusID==nil else {return}
        }
        let topics=firstUse ? session.unseenLearningTopics:session.learningTopics
        guard !topics.isEmpty else {return}
        learningTopics=topics;learningIndex=0;showLearningGuide=true
    }
    private func completed(_ message:String)->String {
        message+(session.completionAssistanceSummary.map {" "+$0} ?? "")
    }
    private var learningGuide:some View {
        Group {
            if learningTopics.indices.contains(learningIndex) {
                let topic=learningTopics[learningIndex]
                LabLearningGuideView(topic:topic,position:learningIndex+1,total:learningTopics.count,
                    route:session.state.apparatus.first(where:{LabLearningTopic.topic(for:$0)==topic}).map(machineRoute),
                    advance:{
                        if learningIndex+1<learningTopics.count {learningIndex+=1}
                        else {showLearningGuide=false}
                    },close:{showLearningGuide=false})
                    .task(id:topic) {session.markLearningTopicSeen(topic)}
            }
        }.presentationCompactAdaptation(.popover)
    }
    private var boardNotice:String {
        if session.isSortingCourse,session.solved {return completed(session.sortingCourseBoard?.number == LabSortingCourseBoard.levelCount ? "Sorting course complete. Choose a level, or play again.":"Level complete. Continue when you are ready, or play again.")}
        if session.isEndlessSorting,session.solved {return completed("Generated level complete. Continue when you are ready, or play again.")}
        if session.isValveCourse,session.solved {return completed(session.valveBoard?.number == LabValveBoard.levelCount ? "Valve course complete. Choose a level, or play again.":"Circuit complete. Continue to the next valve level when you are ready.")}
        if session.journeyMode {
            if session.solved {
                return completed(session.journeyNext.isEmpty ? "Path complete. Explore another branch in Journey.":(session.journeyNext.count>1 ? "Step complete. Choose what you would like to learn next.":"Step complete. Continue your Journey when you are ready."))
            }
            if session.moveCount==0 && !session.busy && session.selected==nil && session.hintApparatusID==nil && session.hintTarget==nil {
                return LabJourney.stop(session.puzzle)?.lesson ?? session.notice
            }
        }
        if session.solved {
            return completed(session.puzzle.next == nil ? "Final level complete. Choose a level, or play again.":session.notice)
        }
        return session.notice
    }
    private var apparatusControls:some View {
        HStack(spacing:10) {
            ForEach(session.state.apparatus) { apparatus in
                let guide=session.state.apparatusGuidance(apparatus)
                HStack(spacing:2) {
                    Button(apparatus.title+(session.state.apparatus.filter {$0.kind==apparatus.kind}.count>1 ? " "+FluidBoardSession.letter(apparatus.inputs[0]):""),systemImage:apparatus.kind == .separator ? "arrow.triangle.branch":(apparatus.kind == .mixer ? "arrow.triangle.2.circlepath":"arrow.up.arrow.down")) {
                        if guide.ready {session.activateApparatus(apparatus.id)}
                        else {inspectedApparatus=apparatus}
                    }
                    .disabled(session.busy)
                    .tint(session.hintApparatusID==apparatus.id ? .orange:(focusedApparatus?.id==apparatus.id ? machineAccent:(guide.ready ? .purple:.gray)))
                    .help(guide.message).accessibilityHint(guide.message)
                    Button {inspectedApparatus=apparatus} label: {Image(systemName:"info.circle")}
                        .buttonStyle(.plain).frame(width:26,height:28).disabled(session.busy)
                        .accessibilityLabel(apparatus.title+" recipe and requirements")
                        .accessibilityHint("Highlights "+machineRoute(apparatus))
                }.popover(isPresented:Binding(get:{inspectedApparatus?.id==apparatus.id},set:{if !$0 {inspectedApparatus=nil}})) {
                    machineGuide(apparatus)
                }
            }
        }.buttonStyle(.borderedProminent).controlSize(.small)
    }

    private func machineGuide(_ tool:LabApparatus)->some View {
            let guide=session.state.apparatusGuidance(tool)
            return VStack(alignment:.leading,spacing:14) {
                Text(tool.title).font(.headline)
                Text(LabLearningTopic.topic(for:tool).explanation).font(.callout).fixedSize(horizontal:false,vertical:true)
                Text(machineRoute(tool)).font(.system(.callout,design:.monospaced).weight(.semibold))
                    .foregroundStyle(machineAccent).fixedSize(horizontal:false,vertical:true)
                Text(tool.kind == .densityModifier ? "The highlighted chamber changes the liquid’s density.":"Dashed outlines mark inputs; solid outlines and arrowheads mark outputs.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                Button(tool.kind == .densityModifier ? "Show chamber":"Show connections",
                       systemImage:tool.kind == .densityModifier ? "scope":"arrow.triangle.branch") {inspectedApparatus=nil}
                    .buttonStyle(.bordered)
                    .accessibilityHint(tool.kind == .densityModifier ? "Closes this guide and highlights the chamber for four seconds.":"Closes this guide and highlights the connected vials for four seconds.")
                Text(guide.ready ? "Ready to activate":"What this machine needs").font(.subheadline).foregroundStyle(.secondary)
                Text(guide.message).fixedSize(horizontal:false,vertical:true)
                if tool.kind == .mixer {
                    Text("Recipes: red + yellow = orange; yellow + blue = green; blue + red = purple. Each ingredient contributes one unit.").font(.callout).foregroundStyle(.secondary)
                }
                if guide.ready {
                    Button(tool.title) {inspectedApparatus=nil;session.activateApparatus(tool.id)}
                        .buttonStyle(.borderedProminent).disabled(session.busy)
                }
            }.padding(20).frame(width:320).presentationCompactAdaptation(.popover)

    }

    private var boardLayout:some View {
        GeometryReader { geometry in
            let compact=geometry.size.width<680
            let vialCount=session.state.stacks.count
            let showsAddHelperCard=session.supportsHelpers && session.state.canAddHelper
            let debugItemCount=vialCount+(showsAddHelperCard ? 1:0)
            let debugInset:CGFloat=compact ? 40:64
            let debugGap:CGFloat=debugItemCount>8 ? 5:8
            let debugCardWidth=(geometry.size.width-debugInset-debugGap*CGFloat(max(0,debugItemCount-1)))/CGFloat(max(1,debugItemCount))
            let denseDebug=debugCardWidth<82
            VStack(spacing:0) {
                HStack {
                    VStack(alignment:.leading,spacing:4) {
                        Text("VIALS / \(session.boardHeader)").font(.system(size:10,weight:.semibold,design:.monospaced)).tracking(3).foregroundStyle(ink.opacity(0.5))
                        Text(session.boardTitle).font(.system(size:compact ? 28:34,design:.serif)).foregroundStyle(ink)
                    }
                    Spacer()
                    if !session.learningTopics.isEmpty {
                        Button {openLearningGuide(firstUse:false)} label: {Image(systemName:"questionmark.circle").frame(width:32,height:32)}
                            .buttonStyle(.plain).disabled(session.busy)
                            .accessibilityLabel("Learning guide").accessibilityHint("Replay explanations for this level’s tools and liquids.")
                            .accessibilityIdentifier("lab.learningGuide")
                            .popover(isPresented:$showLearningGuide) {learningGuide}
                    }
                    Button { session.diagnostics.toggle() } label: { Image(systemName:"slider.horizontal.3").frame(width:34,height:34) }
                        .buttonStyle(.plain).accessibilityLabel("Board diagnostics")
                    Menu {
                        Toggle("Pouring sound",isOn:$session.soundEnabled)
                        #if os(iOS)
                        Toggle("Haptics",isOn:$session.hapticsEnabled)
                        #endif
                        Picker("Fluid detail",selection:$session.quality) { ForEach(LabRenderQuality.allCases,id:\.self) { Text($0.title).tag($0) } }.disabled(session.busy || session.presentation != .fluid)
                        Divider()
                        Button(session.lastPour == nil ? "Compare a pour":"Compare last pour") { comparison=session.comparisonExample }.disabled(!session.canComparePour)
                        Button("Pour study") { sheet = .study }
                        Button("Original game (legacy)") { sheet = .classic }
                        Divider()
                        Button("Reset all progress…",role:.destructive) { showResetProgress=true }
                    } label: { Image(systemName:"ellipsis.circle").frame(width:32,height:32) }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Board options")
                }.padding(.horizontal,compact ? 20:32).padding(.top,20).padding(.bottom,12)
                HStack(spacing:12) {
                    Button("Journey",systemImage:"map") {sheet = .journey}
                        .buttonStyle(.borderedProminent).tint(session.journeyMode ? accent:Color.gray.opacity(0.35))
                        .foregroundStyle(session.journeyMode ? Color.black:ink)
                        .accessibilityIdentifier("lab.journey")
                    Menu {
                        ForEach(LabEndlessDifficulty.allCases) { difficulty in
                            Button(difficulty.title) {openEndless(difficulty)}
                        }
                    } label: {Label("Endless",systemImage:"infinity")}
                    .buttonStyle(.borderedProminent).tint(session.isEndlessSorting ? accent:Color.gray.opacity(0.35))
                    .foregroundStyle(session.isEndlessSorting ? Color.black:ink)
                    .accessibilityLabel("Endless Sorting")
                    Menu(session.isValveCourse ? "Valve Lab":(session.isSortingCourse ? "Sorting Course":(session.journeyMode || session.isEndlessSorting ? "Explore labs":session.discipline.title+" Lab"))) {
                        Button("Sorting Course",systemImage:"list.number") {openSortingCourse()}
                            .accessibilityIdentifier("lab.sortingCourse")
                        Divider()
                        ForEach(LabDiscipline.availableLabs,id:\.self) { discipline in
                            Button(discipline.title+" Lab") {session.changeDiscipline(discipline)}
                        }
                        Divider()
                        Button("Valve Lab",systemImage:"arrow.down.circle") {openValves()}
                            .accessibilityIdentifier("lab.valveCourse")
                    }.buttonStyle(.borderedProminent)
                        .tint(session.isValveCourse || session.isSortingCourse ? accent:Color.gray.opacity(0.35))
                        .foregroundStyle(session.isValveCourse || session.isSortingCourse ? Color.black:ink)
                        .accessibilityLabel("Choose laboratory")
                    Spacer(minLength:0)
                }.disabled(session.busy).padding(.horizontal,compact ? 20:32).padding(.bottom,8)
                HStack(spacing:12) {
                    Picker("Presentation",selection:Binding(get:{session.presentation},set:session.changePresentation)) {
                        ForEach(LabBoardPresentation.allCases,id:\.self) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented).frame(maxWidth:330)
                    Picker("Pace",selection:Binding(get:{session.pace},set:session.changePace)) {
                        ForEach(LabBoardPace.allCases,id:\.self) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented).frame(maxWidth:220)
                    Spacer(minLength:0)
                    if session.isSortingCourse {
                        Button {sheet = .course} label: {Image(systemName:"square.grid.2x2").frame(width:28,height:28)}
                            .buttonStyle(.plain).accessibilityLabel("Browse Sorting Course levels")
                            .accessibilityIdentifier("sortingCourse.browser")
                    } else {
                        Menu {
                            boardChoices
                        } label: { Image(systemName:"square.grid.2x2").frame(width:28,height:28) }.accessibilityLabel("Choose puzzle")
                    }
                }.disabled(session.busy).padding(.horizontal,compact ? 20:32).padding(.bottom,8)
                HStack { Text(session.boardDetail);Spacer();Text(session.boardProgressSummary) }.font(.system(size:10,design:.monospaced)).foregroundStyle(ink.opacity(0.55)).padding(.horizontal,compact ? 20:32)
                HStack {
                    Text(session.paused ? "Paused":session.phase).font(.system(size:compact ? 19:24,weight:.light,design:.serif))
                    Spacer()
                    Text("\(session.moveCount) \(session.moveCount == 1 ? "move":"moves")").font(.system(size:12,design:.monospaced)).foregroundStyle(ink.opacity(0.6))
                }.padding(.horizontal,compact ? 20:32).frame(height:38)
                GeometryReader { board in
                    let capExclusions=Set([session.selected].compactMap { $0 }+session.activeMoves.flatMap { [$0.source,$0.destination] })
                    ZStack {
                        if session.presentation == .classic { LabClassicBoardView(state:session.state,pour:session.classicPour,additionalPours:session.concurrentClassicPours,capExclusions:capExclusions,transformation:session.transformation,reveals:session.concurrentReveals,twoRows:session.twoRowLayout) }
                        else if session.presentation == .fluid2D { LabPlanarSurface(display:session.planarDisplay,animateIdle:!session.paused && !session.busy && scenePhase == .active && sheet == nil && comparison == nil && !showResetProgress,points:session.points,selected:session.selected,destinations:session.validDestinations,rejected:session.rejectedVial,capExclusions:capExclusions,twoRows:session.twoRowLayout) }
                        else if let renderer=session.renderer { BoardMetalSurface(renderer:renderer,capExclusions:capExclusions).accessibilityHidden(true) }
                        else { ContentUnavailableView("Metal unavailable",systemImage:"cube.transparent",description:Text(session.error ?? "Unable to start the fluid renderer.")) }
                        if let tool=focusedApparatus {
                            LabMachineConnectionOverlay(tool:tool,rects:session.state.stacks.indices.map {hitRect($0,size:board.size)},tint:machineAccent)
                                .allowsHitTesting(false).accessibilityHidden(true)
                                .transition(.opacity)
                        }
                        ForEach(session.state.stacks.indices,id:\.self) { index in
                            let rect=hitRect(index,size:board.size)
                            Button { session.select(index) } label: {
                                RoundedRectangle(cornerRadius:20)
                                    .fill(Color.white.opacity(0.001))
                                    .overlay(alignment:.bottom) {
                                        Label(cueLabel(index),systemImage:cueSymbol(index)).font(.system(size:10,weight:.semibold))
                                            .fixedSize().padding(.horizontal,7).padding(.vertical,4).background(.black.opacity(0.75),in:Capsule())
                                            .foregroundStyle(cueColor(index) == .clear ? ink.opacity(0.75):cueColor(index)).opacity(cueLabel(index).isEmpty ? 0:1).offset(y:17)
                                    }
                                    .overlay(alignment:.top) {
                                        let tools=session.apparatus(forVial:index)
                                        if !tools.isEmpty {
                                            // A separator output may also feed a mixer. Stack the
                                            // roles upward so neither is hidden and the vial stays put.
                                            VStack(spacing:3) {
                                                ForEach(tools) { apparatus in
                                                    Label(apparatusPortLabel(apparatus,index:index)+(focusedApparatus?.id==apparatus.id ? " "+FluidBoardSession.letter(index):""),systemImage:apparatus.kind == .separator ? "arrow.triangle.branch":(apparatus.kind == .mixer ? "arrow.triangle.2.circlepath":"arrow.up.arrow.down"))
                                                        .font(.system(size:8,weight:.bold,design:.monospaced))
                                                        .fixedSize(horizontal:true,vertical:false)
                                                        .padding(.horizontal,5).padding(.vertical,3)
                                                        .background(focusedApparatus?.id==apparatus.id ? machineAccent:Color.black.opacity(0.72),in:Capsule())
                                                        .foregroundStyle(focusedApparatus?.id==apparatus.id ? Color.black:(session.hintApparatusID==apparatus.id ? Color.orange:Color.purple))
                                                }
                                            }.fixedSize().offset(y:-13-CGFloat(tools.count-1)*18)
                                        } else if session.target(index) != nil {
                                            Label(session.vialComplete(index) ? "TARGET ✓":"TARGET",systemImage:"scope")
                                                .font(.system(size:8,weight:.bold,design:.monospaced))
                                                .fixedSize(horizontal:true,vertical:false)
                                                .padding(.horizontal,5).padding(.vertical,3).background(.black.opacity(0.72),in:Capsule())
                                                .foregroundStyle(session.vialComplete(index) ? Color.green:Color.purple).offset(y:-13)
                                        } else if let helper=session.state.helperName(index) {
                                            Label(helper.uppercased(),systemImage:"cup.and.saucer.fill")
                                                .font(.system(size:8,weight:.bold,design:.monospaced))
                                                .fixedSize(horizontal:true,vertical:false)
                                                .padding(.horizontal,5).padding(.vertical,3).background(.black.opacity(0.72),in:Capsule())
                                                .foregroundStyle(Color.mint).offset(y:-13)
                                        }
                                    }
                                    .overlay {
                                        let target=session.validDestinations.contains(index)
                                        let outline=RoundedRectangle(cornerRadius:20)
                                        let style=StrokeStyle(lineWidth:session.selected==index ? 3:2.5,lineCap:.round,dash:target ? [6,4]:[])
                                        outline.stroke(.black.opacity(cueColor(index) == .clear ? 0:0.45),style:StrokeStyle(lineWidth:style.lineWidth+2,lineCap:.round,dash:style.dash))
                                        outline.stroke(cueColor(index).opacity(0.95),style:style)
                                    }
                            }
                            .buttonStyle(LabVialPressStyle()).frame(width:rect.width,height:rect.height).position(x:rect.midX,y:rect.midY)
                            .disabled(!session.canTap(index))
                            .accessibilityLabel(session.accessibility(index)).accessibilityHint(machineMembership(index)).accessibilityValue(session.vialComplete(index) && cueLabel(index).isEmpty ? "Complete":cueLabel(index))
                        }
                        if session.diagnostics {
                            diagnostics.frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading).padding(14)
                        }
                        if let error=session.error { Text(error).font(.callout).padding().background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:12)) }
                    }.animation(reduceMotion ? nil:.easeOut(duration:0.18),value:focusedApparatus?.id)
                }.frame(minHeight:220)
                VStack(spacing:14) {
                    LazyVGrid(columns:Array(repeating:GridItem(.flexible(minimum:0),spacing:debugGap),count:max(1,session.twoRowLayout ? (debugItemCount+1)/2:debugItemCount)),spacing:debugGap) {
                        ForEach(session.state.stacks.indices,id:\.self) { index in
                            ZStack(alignment:.topTrailing) {
                                Button { session.select(index) } label: {
                                VStack(spacing:denseDebug ? 3:5) {
                                    HStack(spacing:denseDebug ? 2:5) {
                                        Text(FluidBoardSession.letter(index)).font(.system(size:denseDebug ? 10:13,weight:.semibold,design:.monospaced))
                                        Text(session.vialComplete(index) ? "✓":"\(session.state.stacks[index].count) / \(session.state.capacity(index))")
                                            .font(.system(size:denseDebug ? 9:11,design:.monospaced)).foregroundStyle(ink.opacity(0.7))
                                        if let key=session.state.valvePigment(index) {
                                            Image(systemName:"lock.fill").font(.system(size:denseDebug ? 7:9,weight:.bold)).foregroundStyle(FluidBoardSession.color(key))
                                        }
                                        if session.state.rules[index] == .sourceOnly { Image(systemName:"arrow.up").font(.system(size:denseDebug ? 7:9,weight:.bold)).foregroundStyle(Color.purple) }
                                        if session.state.isHelper(index) {Image(systemName:"cup.and.saucer.fill").font(.system(size:denseDebug ? 7:9,weight:.bold)).foregroundStyle(Color.mint)}
                                    }
                                    .lineLimit(1).minimumScaleFactor(0.72)
                                    HStack(spacing:denseDebug ? 1.5:3) {
                                        ForEach(0..<session.state.capacity(index),id:\.self) { layer in
                                            let parcel=layer<session.state.stacks[index].count ? session.state.stacks[index][layer]:nil
                                            LabDensitySwatch(color:parcel.map {FluidBoardSession.color(session.state.visualDye($0))} ?? ink.opacity(0.09),
                                                density:session.state.behavior.settlesByDensity ? parcel.map {session.state.densities[$0]}:nil)
                                                .frame(height:session.state.behavior.settlesByDensity || session.state.knownParcels != nil ? 14:4)
                                                .overlay {
                                                    if let parcel,!session.state.isKnown(parcel) {Text("?").font(.system(size:10,weight:.bold)).foregroundStyle(.white).accessibilityHidden(true)}
                                                }
                                        }
                                    }
                                    if let target=session.target(index) {
                                        HStack(spacing:denseDebug ? 1.5:3) {
                                            Text("TARGET").font(.system(size:denseDebug ? 6:7,weight:.bold,design:.monospaced)).foregroundStyle(ink.opacity(0.5))
                                            ForEach(Array(target.layers.enumerated()),id:\.offset) { _,material in
                                                LabDensitySwatch(color:FluidBoardSession.color(material.pigment),density:material.density,target:true)
                                                    .frame(height:14)
                                            }
                                        }
                                        Text(session.busy ? "Updating…":(session.state.targetAssessment(index)?.shortLabel ?? ""))
                                            .font(.system(size:denseDebug ? 9:11,weight:.medium))
                                            .foregroundStyle(session.vialComplete(index) ? Color.green:ink.opacity(0.85))
                                            .lineLimit(1).minimumScaleFactor(0.8).frame(height:14)
                                    }
                                }.frame(maxWidth:.infinity).padding(.vertical,denseDebug ? 8:12).padding(.horizontal,denseDebug ? 3:9)
                                    .background(cueLabel(index).isEmpty ? ink.opacity(0.04):cueColor(index).opacity(0.13),in:RoundedRectangle(cornerRadius:10))
                                    .overlay(RoundedRectangle(cornerRadius:10).stroke(cueColor(index).opacity(0.65),lineWidth:1))
                                    .overlay {
                                        if !machineMembership(index).isEmpty {
                                            RoundedRectangle(cornerRadius:10).stroke(machineAccent,lineWidth:2)
                                        }
                                    }
                                    .scaleEffect(!reduceMotion && session.selected==index ? 1.025:1)
                                    .offset(x:!reduceMotion && session.rejectedVial==index ? 3:0)
                                    .animation(reduceMotion ? nil:.easeInOut(duration:0.18),value:session.selected)
                                    .animation(reduceMotion ? nil:.easeInOut(duration:0.12),value:session.rejectedVial)
                                }.buttonStyle(LabVialPressStyle()).disabled(!session.canTap(index))
                                    .accessibilityLabel("Select "+session.accessibility(index)).accessibilityHint(machineMembership(index)).accessibilityValue(session.vialComplete(index) && cueLabel(index).isEmpty ? "Complete":cueLabel(index))
                                if session.state.isHelper(index) && session.state.canUpgradeHelper(index) {
                                    Button {session.upgradeHelper(index)} label: {
                                        Image(systemName:"arrow.up.circle.fill")
                                            .font(.system(size:denseDebug ? 15:18,weight:.semibold))
                                            .foregroundStyle(Color.mint)
                                            .background(Circle().fill(Color.black.opacity(0.72)).padding(1))
                                            .frame(width:44,height:44)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!session.canUpgradeHelper(index))
                                    .accessibilityLabel("Upgrade \(FluidBoardSession.letter(index)) \(session.state.helperName(index) ?? "helper")")
                                    .accessibilityHint("Increases this helper's capacity by one unit.")
                                    .accessibilityIdentifier("sorting.helper.\(index).upgrade")
                                }
                            }
                        }
                        if showsAddHelperCard {
                            Button {session.addHelper()} label: {
                                VStack(spacing:denseDebug ? 3:5) {
                                    HStack(spacing:denseDebug ? 2:5) {
                                        Image(systemName:"cup.and.saucer.fill").foregroundStyle(Color.mint)
                                        Text("HELPERS").font(.system(size:denseDebug ? 8:11,weight:.semibold,design:.monospaced))
                                        Text("\(session.state.helpers.count) / 2").font(.system(size:denseDebug ? 8:10,design:.monospaced)).foregroundStyle(ink.opacity(0.7))
                                    }.lineLimit(1).minimumScaleFactor(0.65)
                                    HStack(spacing:denseDebug ? 3:6) {
                                        ForEach(0..<2,id:\.self) {slot in
                                            Image(systemName:slot<session.state.helpers.count ? "cup.and.saucer.fill":"plus.circle")
                                                .foregroundStyle(slot<session.state.helpers.count ? Color.mint:ink.opacity(0.38))
                                        }
                                        Text("ADD TEA CUP")
                                            .font(.system(size:denseDebug ? 7:9,weight:.bold,design:.monospaced)).foregroundStyle(ink.opacity(0.65))
                                    }.frame(height:14)
                                }.frame(maxWidth:.infinity).padding(.vertical,denseDebug ? 8:12).padding(.horizontal,denseDebug ? 3:9)
                                    .background(ink.opacity(0.04),in:RoundedRectangle(cornerRadius:10))
                                    .overlay(RoundedRectangle(cornerRadius:10).stroke(Color.mint.opacity(0.45),lineWidth:1))
                            }.buttonStyle(LabVialPressStyle()).frame(maxWidth:.infinity).disabled(!session.canAddHelper)
                                .accessibilityLabel("Add helper tea cup, \(session.state.helpers.count) of 2 helpers added")
                                .accessibilityHint("Adds one empty one-unit helper vessel.")
                                .accessibilityIdentifier("sorting.helpers.add")
                        }
                    }
                    if session.state.behavior.settlesByDensity || !session.state.apparatus.isEmpty {
                        ViewThatFits(in:.horizontal) {
                            HStack(spacing:16) {
                                if session.state.behavior.settlesByDensity {LabDensityLegend().fixedSize()}
                                if !session.state.apparatus.isEmpty {apparatusControls.fixedSize()}
                            }
                            VStack(spacing:8) {
                                if session.state.behavior.settlesByDensity {LabDensityLegend()}
                                if !session.state.apparatus.isEmpty {apparatusControls}
                            }
                        }
                    }
                    Text(boardNotice).font(.system(size:12)).foregroundStyle(ink.opacity(0.65)).frame(maxWidth:.infinity).lineLimit(2).frame(height:34).multilineTextAlignment(.center)
                    HStack(spacing:12) {
                        Button("Undo",systemImage:"arrow.uturn.backward") { session.undo() }.disabled(session.busy || !session.canUndo)
                        Button(session.findingHint ? "Finding…":"Hint",systemImage:"lightbulb") { session.hint() }.disabled(session.busy || session.solved || session.findingHint)
                        Spacer(minLength:8)
                        if let course=session.sortingCourseBoard,course.number<LabSortingCourseBoard.levelCount {
                            Button("Next: \(course.number+1)",systemImage:"arrow.right") {openSortingCourse(level:course.number+1)}
                                .lineLimit(1).minimumScaleFactor(0.75)
                                .buttonStyle(.borderedProminent).tint(accent).foregroundStyle(.black)
                                .opacity(session.solved ? 1:0).disabled(!session.solved)
                                .allowsHitTesting(session.solved).accessibilityHidden(!session.solved)
                                .accessibilityIdentifier("sortingCourse.nextLevel")
                        } else if session.isSortingCourse {
                            Button("Choose level",systemImage:"square.grid.2x2") {sheet = .course}
                                .lineLimit(1).minimumScaleFactor(0.75)
                                .buttonStyle(.borderedProminent).tint(accent).foregroundStyle(.black)
                                .opacity(session.solved ? 1:0).disabled(!session.solved)
                                .allowsHitTesting(session.solved).accessibilityHidden(!session.solved)
                                .accessibilityIdentifier("sortingCourse.chooseLevel")
                        } else if let endless=session.endlessBoard {
                            Button("Next: \(endless.number+1)",systemImage:"arrow.right") {openEndless(endless.difficulty,level:endless.number+1)}
                                .lineLimit(1).minimumScaleFactor(0.75)
                                .buttonStyle(.borderedProminent).tint(accent).foregroundStyle(.black)
                                .opacity(session.solved ? 1:0).disabled(!session.solved)
                                .allowsHitTesting(session.solved).accessibilityHidden(!session.solved)
                                .accessibilityIdentifier("endless.nextLevel")
                        } else if let valve=session.valveBoard,valve.number<LabValveBoard.levelCount {
                            Button("Next: \(valve.number+1)",systemImage:"arrow.right") {openValves(level:valve.number+1)}
                                .lineLimit(1).minimumScaleFactor(0.75)
                                .buttonStyle(.borderedProminent).tint(accent).foregroundStyle(.black)
                                .opacity(session.solved ? 1:0).disabled(!session.solved)
                                .allowsHitTesting(session.solved).accessibilityHidden(!session.solved)
                                .accessibilityIdentifier("valves.nextLevel")
                        } else if session.journeyMode && session.journeyNext.count != 1 {
                            Group {
                                if session.journeyNext.isEmpty {
                                    Button("Journey map",systemImage:"map") {sheet = .journey}
                                        .accessibilityIdentifier("journey.finish")
                                } else {
                                    Menu("Choose path") {
                                        ForEach(session.journeyNext,id:\.self) { stop in
                                            Button(stop.discipline.title+": "+stop.title) {session.startJourney(at:stop)}
                                        }
                                        Divider()
                                        Button("View Journey map") {sheet = .journey}
                                    }.menuStyle(.button).accessibilityIdentifier("journey.choosePath")
                                }
                            }.buttonStyle(.borderedProminent).tint(accent).foregroundStyle(.black)
                                .lineLimit(1).minimumScaleFactor(0.75)
                                .opacity(session.solved ? 1:0).disabled(!session.solved)
                                .allowsHitTesting(session.solved).accessibilityHidden(!session.solved)
                        } else if let next=session.nextSuggestedPuzzle {
                            // Keep the slot in the toolbar while playing so
                            // completion never inserts a row or resizes the board.
                            Button("Next: \(next.title)",systemImage:"arrow.right") { session.nextPuzzle() }
                                .lineLimit(1).minimumScaleFactor(0.75)
                                .buttonStyle(.borderedProminent).tint(accent).foregroundStyle(.black)
                                .opacity(session.solved ? 1:0).disabled(!session.solved)
                                .allowsHitTesting(session.solved).accessibilityHidden(!session.solved)
                                .accessibilityIdentifier("lab.nextPuzzle")
                        } else {
                            // Reserve the final-level action too, so solving it
                            // never changes the board or toolbar layout.
                            Menu { boardChoices } label: {
                                Label("Choose level",systemImage:"square.grid.2x2")
                                    .lineLimit(1).minimumScaleFactor(0.75)
                            }
                            .menuStyle(.button).buttonStyle(.borderedProminent)
                            .tint(accent).foregroundStyle(.black)
                            .opacity(session.solved ? 1:0).disabled(!session.solved)
                            .allowsHitTesting(session.solved).accessibilityHidden(!session.solved)
                            .accessibilityLabel("Choose level").accessibilityIdentifier("lab.chooseLevel")
                        }
                        Spacer(minLength:8)
                        Button { session.togglePause() } label: { Image(systemName:session.paused ? "play.fill":"pause.fill") }.accessibilityLabel(session.paused ? "Resume board":"Pause board")
                        Button(session.solved ? "Play again":"Reset",systemImage:"arrow.counterclockwise") { session.reset() }
                    }.buttonStyle(.bordered).controlSize(.regular).frame(minHeight:44)
                }.padding(.horizontal,compact ? 20:32).padding(.vertical,18).background(Color(red:0.065,green:0.060,blue:0.075))
            }.background(Color(red:0.026,green:0.043,blue:0.060)).foregroundStyle(ink)
                .onAppear {session.updateAdaptiveLayout(portrait:geometry.size.height>geometry.size.width)}
                .onChange(of:geometry.size) { _,size in session.updateAdaptiveLayout(portrait:size.height>size.width) }
                .onChange(of:vialCount) { _,_ in session.updateAdaptiveLayout(portrait:geometry.size.height>geometry.size.width) }
        }
    }

    private var interactiveBoard:some View {
        boardLayout.preferredColorScheme(.dark)
        .task {
            await session.runTrialIfRequested()
            // Isolated device-review launches can expose a guide without
            // depending on touch forwarding through the screen-sharing host.
            let args=ProcessInfo.processInfo.arguments
            if LabTrialConfiguration.current != nil,args.contains("--visual-review"),args.contains("--journey-map") {sheet = .journey}
            if LabTrialConfiguration.current != nil,args.contains("--visual-review"),
               let option=args.firstIndex(of:"--inspect-machine"),option+1<args.count,
               let id=Int(args[option+1]) {
                inspectedApparatus=session.state.apparatus.first {$0.id==id}
            }
        }
        .task(id:"\(session.boardID)/\(sheet?.rawValue ?? "board")/\(scenePhase)") {
            // Let a Journey sheet or lab menu finish dismissing before opening
            // the introduction. Navigation cancels stale presentation requests.
            do {try await Task.sleep(for:.milliseconds(400))} catch {return}
            openLearningGuide(firstUse:true)
        }
        .task(id:inspectedApparatus?.id) {
            if let id=inspectedApparatus?.id {connectionPreviewID=id;return}
            // The popover may cover a port on iPad. Retain its route briefly
            // after dismissal so the unobstructed board explains the connection.
            do {try await Task.sleep(for:.seconds(4))} catch {return}
            connectionPreviewID=nil
        }
        .onChange(of:session.boardID) { _,_ in inspectedApparatus=nil;connectionPreviewID=nil;showLearningGuide=false }
        .onChange(of:session.busy) { _,busy in if busy {inspectedApparatus=nil;connectionPreviewID=nil} }
        .onChange(of:session.selected) { _,_ in connectionPreviewID=nil }
        .onChange(of:session.hintApparatusID) { _,_ in connectionPreviewID=nil }
    }

    var body:some View {
        interactiveBoard
        .onChange(of:reduceTransparency,initial:true) { _,value in session.renderer?.reduceTransparency=value }
        .onChange(of:session.presentation) { _,_ in session.renderer?.reduceTransparency=reduceTransparency }
        .onChange(of:reduceMotion,initial:true) { _,value in session.reduceTransformationMotion=value }
        .onAppear { if reduceMotion { session.paused=true;session.renderer?.paused=true } }
        .onChange(of:sheet) { _,value in session.setSuspended(value != nil || comparison != nil || showResetProgress || showLearningGuide || scenePhase != .active) }
        .onChange(of:scenePhase) { _,value in session.setSuspended(value != .active || sheet != nil || comparison != nil || showResetProgress || showLearningGuide) }
        .onChange(of:comparison?.id) { _,value in session.setSuspended(value != nil || sheet != nil || showResetProgress || showLearningGuide || scenePhase != .active) }
        .onChange(of:showResetProgress) { _,value in session.setSuspended(value || sheet != nil || comparison != nil || showLearningGuide || scenePhase != .active) }
        .onChange(of:showLearningGuide) { _,value in session.setSuspended(value || sheet != nil || comparison != nil || showResetProgress || scenePhase != .active) }
        .confirmationDialog("Reset all progress?",isPresented:$showResetProgress,titleVisibility:.visible) {
            Button("Reset all progress",role:.destructive) {
                session.resetAllProgress()
                GameProgressStore.resetAll()
            }
            Button("Cancel",role:.cancel) {}
        } message: {
            Text("Start again at Level 1. This clears all saved Lab puzzles, completion marks, undo history, Sorting Course, Endless Sorting, and Valve Lab progress. This can’t be undone.")
        }
        .confirmationDialog("No hint from here",isPresented:Binding(get:{session.hintUndoOffer},set:{if !$0 {session.dismissHintUndoOffer()}}),titleVisibility:.visible) {
            Button("Undo until a hint is available") {session.undoUntilHintAvailable()}
                .accessibilityIdentifier("hint.undoUntilAvailable")
            Button("Cancel",role:.cancel) {session.dismissHintUndoOffer()}
        } message: {
            Text("Undo recent moves until the nearest earlier position with a hint is found? In Discovery levels, revealed colors stay known.")
        }
        .sheet(item:$comparison) { example in LabPourComparisonView(example:example) }
        .sheet(item:$sheet) { item in
            if item == .journey {
                LabJourneyMapView(current:session.journeyMode ? session.puzzle:nil,
                    completed:Set(LabJourney.stops.map(\.puzzle).filter(session.hasCompleted)),
                    choose:{session.startJourney(at:$0);sheet=nil},close:{sheet=nil})
                    .frame(minWidth:360,idealWidth:960,minHeight:640,idealHeight:800)
            } else if item == .course {
                LabSortingCourseBrowserView(current:session.sortingCourseBoard?.number,
                    completed:Set((1...LabSortingCourseBoard.levelCount).filter(session.hasCompletedSortingCourseLevel)),
                    completion:session.sortingCourseCompletion,
                    choose:{openSortingCourse(level:$0);sheet=nil},close:{sheet=nil})
                    .frame(minWidth:360,idealWidth:760,minHeight:520,idealHeight:720)
            } else {
                ZStack(alignment:.topTrailing) {
                    if item == .study { FluidLabView() } else { ContentView() }
                    Button("Return to board",systemImage:"xmark.circle.fill") { sheet=nil }.buttonStyle(.bordered).padding()
                }.frame(minWidth:360,minHeight:640)
            }
        }
    }
    @ViewBuilder private var puzzleChoices:some View {
        ForEach(session.discipline.levels,id:\.self) { puzzle in
            Button("\(puzzle.number). \(puzzle.title)\(session.hasCompleted(puzzle) ? " ✓":"")") { session.changePuzzle(puzzle) }
        }
    }
    @ViewBuilder private var boardChoices:some View {
        if let valve=session.valveBoard {
            Button("Previous level") {openValves(level:valve.number-1)}.disabled(valve.number==1)
            Button("Next level") {openValves(level:valve.number+1)}.disabled(valve.number==LabValveBoard.levelCount)
            Divider()
            ForEach(1...LabValveBoard.levelCount,id:\.self) {number in
                Button("\(number). \(LabValveBoard.title(for:number))\(session.hasCompletedValveLevel(number) ? " ✓":"")") {openValves(level:number)}
            }
            Divider()
            Button("Return to Sorting Lab") {session.changeDiscipline(.sorting)}
        } else if let course=session.sortingCourseBoard {
            Button("Previous level") {openSortingCourse(level:course.number-1)}.disabled(course.number==1)
            Button("Next level") {openSortingCourse(level:course.number+1)}.disabled(course.number==LabSortingCourseBoard.levelCount)
            Divider()
            ForEach(stride(from:1,through:LabSortingCourseBoard.levelCount,by:25).map {$0},id:\.self) {start in
                let end=min(start+24,LabSortingCourseBoard.levelCount)
                Menu("Levels \(start)–\(end)") {
                    ForEach(start...end,id:\.self) {number in
                        Button("\(number). Level \(number)\(number.isMultiple(of:5) ? " · Discovery":"")\(session.hasCompletedSortingCourseLevel(number) ? " ✓":"")") {openSortingCourse(level:number)}
                    }
                }
            }
            Divider()
            Button("Return to Sorting Lab") {session.changeDiscipline(.sorting)}
        } else if let endless=session.endlessBoard {
            Button("Previous level") {openEndless(endless.difficulty,level:endless.number-1)}.disabled(endless.number==1)
            Button("Next level") {openEndless(endless.difficulty,level:endless.number+1)}
            Divider()
            ForEach(LabEndlessDifficulty.allCases) {difficulty in
                Button(difficulty.title+(difficulty==endless.difficulty ? " ✓":"")) {openEndless(difficulty,level:difficulty==endless.difficulty ? endless.number:1)}
            }
            Divider()
            Button("Return to Sorting Lab") {session.changeDiscipline(.sorting)}
        } else {
            puzzleChoices
        }
    }
    private func cueLabel(_ index:Int)->String {
        if let item=session.pourQueue.items.first(where:{$0.move.source==index}) { return item.started ? "Pouring":"Queued" }
        if session.busy && !session.concurrentPoursEnabled { return "" }
        if session.rejectedVial==index { return "Cannot pour" }
        if session.selected==index { return "Selected" }
        if session.hintTarget==index { return "Hint" }
        if session.validDestinations.contains(index) { return "Pour here" }
        return ""
    }
    private func cueSymbol(_ index:Int)->String {
        if let item=session.pourQueue.items.first(where:{$0.move.source==index}) { return item.started ? "drop":"clock" }
        if session.rejectedVial==index { return "xmark.circle" }
        if session.selected==index { return "drop.fill" }
        if session.hintTarget==index { return "lightbulb" }
        return session.validDestinations.contains(index) ? "arrow.down":"checkmark.circle"
    }
    private func cueColor(_ index:Int)->Color {
        if session.busy && !session.concurrentPoursEnabled { return .clear }
        if session.rejectedVial==index || session.hintTarget==index { return .orange }
        if session.selected==index || session.validDestinations.contains(index) { return accent }
        return .clear
    }
    private func apparatusPortLabel(_ apparatus:LabApparatus,index:Int)->String {
        if apparatus.kind == .separator {return apparatus.outputs.contains(index) ? "SEP OUT":"SEP IN"}
        if apparatus.kind == .mixer {return apparatus.output==index ? "MIX OUT":"MIX IN"}
        return apparatus.direction == .heavier ? "HEAVY":"LIGHT"
    }
    private var diagnostics:some View {
        VStack(alignment:.leading,spacing:7) {
            Text(session.presentation.title.uppercased()+" STUDY").font(.system(size:9,weight:.bold,design:.monospaced)).tracking(2)
            if session.presentation == .fluid {
            Text("\(session.renderer?.particleCount ?? 0) particles · \(session.metrics.gpuMilliseconds,specifier:"%.1f") ms GPU")
            Text("Outside: \(session.metrics.outside) · Wrong layer: \(session.metrics.wrongParcel)")
            Text("Pour assist: \(session.metrics.guided) particles")
            if session.captured>0 { Text("Captured: \(session.captured*100,specifier:"%.1f")% · Cleanup: \(session.correction)") }
            }
            if session.presentation == .fluid2D {
                LabPlanarDiagnostics(display:session.planarDisplay)
                Toggle("Show particles",isOn:$session.points).toggleStyle(.switch).controlSize(.mini)
            }
            Toggle("Slow motion",isOn:$session.slow).toggleStyle(.switch).controlSize(.mini)
            if session.presentation == .fluid {
            Toggle("Show particles",isOn:$session.points).toggleStyle(.switch).controlSize(.mini)
            HStack { Text("View");Slider(value:$session.orbit,in: -0.3...0.4).frame(width:120) }
            }
            Button(session.measurementActive ? "Finish measurement":"Record session") { session.toggleMeasurement() }
            if let report=session.reportURL { ShareLink("Share measurements",item:report) }
        }.font(.system(size:10,design:.monospaced)).padding(12).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:12))
    }
    private func hitRect(_ index:Int,size:CGSize) -> CGRect {
        let profiles=LabBoardLayout.profiles(state:session.state)
        if session.presentation == .fluid2D {
            let layout=LabClassicLayout(size:size,vesselCount:profiles.count,twoRows:session.twoRowLayout),profile=session.fluid2D.profiles[index]
            let base=layout.base(index)
            let bodyRadius=CGFloat((profile.source.radii.max() ?? 0.6)*profile.scale)
            let lidRadius=CGFloat(profile.source.radii.last ?? 0.6)+0.07
            let hasValveLid=session.state.valvePigment(index) != nil
            let radius=max(bodyRadius,hasValveLid ? lidRadius:0)*layout.scale
            let handle=session.state.isHelper(index) ? layout.scale*0.48:0
            let lidHeight=hasValveLid ? layout.scale*0.20:0
            return CGRect(x:base.x-radius-8,y:base.y-CGFloat(profile.height)*layout.scale-8-lidHeight,
                          width:radius*2+16+handle,height:CGFloat(profile.height)*layout.scale+16+lidHeight)
        }
        if session.presentation == .classic {
            return LabClassicLayout(size:size,vesselCount:session.state.stacks.count,twoRows:session.twoRowLayout)
                .hitRect(index,profile:profiles[index],includesHandle:session.state.isHelper(index),
                         includesValveLid:session.state.valvePigment(index) != nil)
        }
        let matrix=LabBoardLayout.camera(aspect:Float(size.width/max(size.height,1)),azimuth:Float(session.orbit),vesselCount:session.state.stacks.count,twoRows:session.twoRowLayout).0
        let home=LabBoardLayout.homes(count:session.state.stacks.count,twoRows:session.twoRowLayout)[index]
        let hasValveLid=session.state.valvePigment(index) != nil
        let lidRadius=(profiles[index].radii.last ?? 0.6)+0.07
        let r=max((profiles[index].radii.max() ?? 0.6)+0.05,hasValveLid ? lidRadius:0)+(session.state.isHelper(index) ? 0.42:0)
        let height=profiles[index].height+(hasValveLid ? 0.20:0)
        var xs:[CGFloat]=[],ys:[CGFloat]=[]
        for x in [-r,r] { for z in [-r,r] { for y:Float in [0,height] {
            let p=matrix*SIMD4(home+SIMD3(x,y,z),1)
            xs.append(CGFloat(p.x/p.w+1)*size.width/2);ys.append(CGFloat(1-p.y/p.w)*size.height/2)
        }}}
        return CGRect(x:xs.min()!-6,y:ys.min()!-6,width:xs.max()!-xs.min()!+12,height:ys.max()!-ys.min()!+12)
    }
}

#if os(macOS)
struct BoardMetalSurface:NSViewRepresentable {
    let renderer:LabBoardRenderer
    var capExclusions:Set<Int>=[]
    func makeNSView(context:Context) -> MTKView { makeBoardView(renderer,capExclusions:capExclusions) }
    func updateNSView(_ view:MTKView,context:Context) { renderer.capExclusions=capExclusions }
    static func dismantleNSView(_ view:MTKView,coordinator:()) { view.isPaused=true;view.delegate=nil }
}
#else
struct BoardMetalSurface:UIViewRepresentable {
    let renderer:LabBoardRenderer
    var capExclusions:Set<Int>=[]
    func makeUIView(context:Context) -> MTKView { makeBoardView(renderer,capExclusions:capExclusions) }
    func updateUIView(_ view:MTKView,context:Context) { renderer.capExclusions=capExclusions }
    static func dismantleUIView(_ view:MTKView,coordinator:()) { view.isPaused=true;view.delegate=nil }
}
#endif
@MainActor private func makeBoardView(_ renderer:LabBoardRenderer,capExclusions:Set<Int>) -> MTKView {
    renderer.capExclusions=capExclusions
    let view=MTKView(frame:.zero,device:renderer.device)
    view.colorPixelFormat = .bgra8Unorm_srgb;view.preferredFramesPerSecond=60
    view.autoResizeDrawable=false;view.delegate=renderer
    return view
}

/// Touch-down feedback does not wait for the button action on release.
private struct LabVialPressStyle:ButtonStyle {
    func makeBody(configuration:Configuration)->some View {
        configuration.label.overlay {
            RoundedRectangle(cornerRadius:16).fill(.white.opacity(configuration.isPressed ? 0.09:0))
                .overlay(RoundedRectangle(cornerRadius:16).stroke(.white.opacity(configuration.isPressed ? 0.4:0),lineWidth:1))
        }
    }
}

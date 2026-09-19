import SwiftUI
import MetalKit
import Combine

private enum BoardSheet:String,Identifiable { case classic,study;var id:String { rawValue } }

struct FluidBoardView:View {
    @StateObject private var session=FluidBoardSession(allowsConcurrentPours:true)
    @State private var showResetProgress=false
    @State private var sheet:BoardSheet?
    @State private var comparison:LabPourExample?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private let ink=Color(red:0.80,green:0.88,blue:0.90)
    private let accent=Color(red:0.28,green:0.85,blue:0.79)
    var body:some View {
        GeometryReader { geometry in
            let compact=geometry.size.width<680
            let vialCount=session.state.stacks.count
            let debugInset:CGFloat=compact ? 40:64
            let debugGap:CGFloat=vialCount>8 ? 5:8
            let debugCardWidth=(geometry.size.width-debugInset-debugGap*CGFloat(max(0,vialCount-1)))/CGFloat(max(1,vialCount))
            let denseDebug=debugCardWidth<82
            VStack(spacing:0) {
                HStack {
                    VStack(alignment:.leading,spacing:4) {
                        Text("VIALS / \(session.discipline.header)").font(.system(size:10,weight:.semibold,design:.monospaced)).tracking(3).foregroundStyle(ink.opacity(0.5))
                        Text(session.puzzle.title).font(.system(size:compact ? 28:34,design:.serif)).foregroundStyle(ink)
                    }
                    Spacer()
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
                        Button("Original game") { sheet = .classic }
                        Divider()
                        Button("Reset all progress…",role:.destructive) { showResetProgress=true }
                    } label: { Image(systemName:"ellipsis.circle").frame(width:32,height:32) }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Board options")
                }.padding(.horizontal,compact ? 20:32).padding(.top,20).padding(.bottom,12)
                HStack(spacing:12) {
                    if compact {
                        Menu(session.discipline.title+" Lab") {
                            ForEach(LabDiscipline.allCases,id:\.self) { discipline in
                                Button(discipline.title+" Lab") {session.changeDiscipline(discipline)}
                            }
                        }.buttonStyle(.bordered).accessibilityLabel("Choose laboratory")
                    } else {
                        Picker("Laboratory",selection:Binding(get:{session.discipline},set:session.changeDiscipline)) {
                            ForEach(LabDiscipline.allCases,id:\.self) {Text($0.title).tag($0)}
                        }.pickerStyle(.segmented).frame(maxWidth:520)
                    }
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
                    Menu {
                        ForEach(session.discipline.levels,id:\.self) { puzzle in Button("\(puzzle.number). \(puzzle.title)\(session.hasCompleted(puzzle) ? " ✓":"")") { session.changePuzzle(puzzle) } }
                    } label: { Image(systemName:"square.grid.2x2").frame(width:28,height:28) }.accessibilityLabel("Choose puzzle")
                }.disabled(session.busy).padding(.horizontal,compact ? 20:32).padding(.bottom,8)
                HStack { Text(session.puzzle.detail);Spacer();Text("\(session.completedPuzzleCount) complete") }.font(.system(size:10,design:.monospaced)).foregroundStyle(ink.opacity(0.55)).padding(.horizontal,compact ? 20:32)
                HStack {
                    Text(session.paused ? "Paused":session.phase).font(.system(size:compact ? 19:24,weight:.light,design:.serif))
                    Spacer()
                    Text("\(session.moveCount) \(session.moveCount == 1 ? "move":"moves")").font(.system(size:12,design:.monospaced)).foregroundStyle(ink.opacity(0.6))
                }.padding(.horizontal,compact ? 20:32).frame(height:38)
                GeometryReader { board in
                    let capExclusions=Set([session.selected].compactMap { $0 }+session.activeMoves.flatMap { [$0.source,$0.destination] })
                    ZStack {
                        if session.presentation == .classic { LabClassicBoardView(state:session.state,pour:session.classicPour,additionalPours:session.concurrentClassicPours,capExclusions:capExclusions) }
                        else if session.presentation == .fluid2D { LabPlanarSurface(display:session.planarDisplay,animateIdle:!session.paused && !session.busy && scenePhase == .active && sheet == nil && comparison == nil && !showResetProgress,points:session.points,selected:session.selected,destinations:session.validDestinations,rejected:session.rejectedVial,capExclusions:capExclusions) }
                        else if let renderer=session.renderer { BoardMetalSurface(renderer:renderer,capExclusions:capExclusions).accessibilityHidden(true) }
                        else { ContentUnavailableView("Metal unavailable",systemImage:"cube.transparent",description:Text(session.error ?? "Unable to start the fluid renderer.")) }
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
                                        if let apparatus=session.apparatus(forVial:index) {
                                            Label(apparatusPortLabel(apparatus,index:index),systemImage:apparatus.kind == .mixer ? "arrow.triangle.2.circlepath":"arrow.up.arrow.down")
                                                .font(.system(size:8,weight:.bold,design:.monospaced))
                                                .padding(.horizontal,5).padding(.vertical,3).background(.black.opacity(0.72),in:Capsule())
                                                .foregroundStyle(session.hintApparatusID==apparatus.id ? Color.orange:Color.purple).offset(y:-13)
                                        } else if session.state.rules[index] == .receiveOnly {
                                            Label("FILL",systemImage:"arrow.down").font(.system(size:8,weight:.bold,design:.monospaced))
                                                .padding(.horizontal,5).padding(.vertical,3).background(.black.opacity(0.72),in:Capsule())
                                                .foregroundStyle(Color.cyan).offset(y:-13)
                                        } else if session.target(index) != nil {
                                            Label(session.vialComplete(index) ? "TARGET ✓":"TARGET",systemImage:"scope")
                                                .font(.system(size:8,weight:.bold,design:.monospaced))
                                                .padding(.horizontal,5).padding(.vertical,3).background(.black.opacity(0.72),in:Capsule())
                                                .foregroundStyle(session.vialComplete(index) ? Color.green:Color.purple).offset(y:-13)
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
                            .accessibilityLabel(session.accessibility(index)).accessibilityValue(session.vialComplete(index) && cueLabel(index).isEmpty ? "Complete":cueLabel(index))
                        }
                        if session.diagnostics {
                            diagnostics.frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading).padding(14)
                        }
                        if let error=session.error { Text(error).font(.callout).padding().background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:12)) }
                    }
                }.frame(minHeight:220)
                VStack(spacing:14) {
                    HStack(spacing:debugGap) {
                        ForEach(session.state.stacks.indices,id:\.self) { index in
                            Button { session.select(index) } label: {
                                VStack(spacing:denseDebug ? 3:5) {
                                    HStack(spacing:denseDebug ? 2:5) {
                                        Text(FluidBoardSession.letter(index)).font(.system(size:denseDebug ? 10:13,weight:.semibold,design:.monospaced))
                                        Text(session.vialComplete(index) ? "✓":"\(session.state.stacks[index].count) / \(session.state.capacity(index))")
                                            .font(.system(size:denseDebug ? 9:11,design:.monospaced)).foregroundStyle(ink.opacity(0.7))
                                        if session.state.rules[index] == .receiveOnly { Image(systemName:"arrow.down").font(.system(size:denseDebug ? 7:9,weight:.bold)).foregroundStyle(Color.cyan) }
                                        if session.state.rules[index] == .sourceOnly { Image(systemName:"arrow.up").font(.system(size:denseDebug ? 7:9,weight:.bold)).foregroundStyle(Color.purple) }
                                    }
                                    .lineLimit(1).minimumScaleFactor(0.72)
                                    HStack(spacing:denseDebug ? 1.5:3) {
                                        ForEach(0..<session.state.capacity(index),id:\.self) { layer in
                                            let parcel=layer<session.state.stacks[index].count ? session.state.stacks[index][layer]:nil
                                            Capsule().fill(parcel.map {FluidBoardSession.color(session.state.visualDye($0))} ?? ink.opacity(0.09))
                                                .overlay {
                                                    if let parcel,session.state.behavior.settlesByDensity {
                                                        Text(session.state.densities[parcel].shortTitle).font(.system(size:5,weight:.bold,design:.monospaced)).foregroundStyle(ink.opacity(0.78))
                                                    }
                                                }.frame(height:session.state.behavior.settlesByDensity ? 7:4)
                                        }
                                    }
                                    if let target=session.target(index) {
                                        HStack(spacing:denseDebug ? 1.5:3) {
                                            Text("TARGET").font(.system(size:denseDebug ? 6:7,weight:.bold,design:.monospaced)).foregroundStyle(ink.opacity(0.5))
                                            ForEach(Array(target.layers.enumerated()),id:\.offset) { _,material in
                                                Capsule().fill(FluidBoardSession.color(material.pigment+material.density.visualBank*12).opacity(0.34))
                                                    .overlay(Capsule().stroke(ink.opacity(0.35),lineWidth:0.5))
                                                    .overlay(Text(material.density.shortTitle).font(.system(size:5,weight:.bold,design:.monospaced)).foregroundStyle(ink.opacity(0.75)))
                                                    .frame(height:7)
                                            }
                                        }
                                    }
                                }.frame(maxWidth:.infinity).padding(.vertical,denseDebug ? 8:12).padding(.horizontal,denseDebug ? 3:9)
                                    .background(cueLabel(index).isEmpty ? ink.opacity(0.04):cueColor(index).opacity(0.13),in:RoundedRectangle(cornerRadius:10))
                                    .overlay(RoundedRectangle(cornerRadius:10).stroke(cueColor(index).opacity(0.65),lineWidth:1))
                                    .scaleEffect(!reduceMotion && session.selected==index ? 1.025:1)
                                    .offset(x:!reduceMotion && session.rejectedVial==index ? 3:0)
                                    .animation(reduceMotion ? nil:.easeInOut(duration:0.18),value:session.selected)
                                    .animation(reduceMotion ? nil:.easeInOut(duration:0.12),value:session.rejectedVial)
                            }.buttonStyle(LabVialPressStyle()).disabled(!session.canTap(index))
                            .accessibilityLabel("Select "+session.accessibility(index)).accessibilityValue(session.vialComplete(index) && cueLabel(index).isEmpty ? "Complete":cueLabel(index))
                        }
                    }
                    if !session.state.apparatus.isEmpty {
                        HStack(spacing:10) {
                            ForEach(session.state.apparatus) { apparatus in
                                Button(apparatus.title,systemImage:apparatus.kind == .mixer ? "arrow.triangle.2.circlepath":"arrow.up.arrow.down") {
                                    session.activateApparatus(apparatus.id)
                                }
                                .disabled(session.busy || !session.state.canActivate(.init(apparatusID:apparatus.id)))
                                .tint(session.hintApparatusID==apparatus.id ? .orange:.purple)
                            }
                        }.buttonStyle(.borderedProminent).controlSize(.small)
                    }
                    if session.solved,let next=session.puzzle.next {
                        Button("Next: \(next.title)",systemImage:"arrow.right") { session.nextPuzzle() }.buttonStyle(.borderedProminent).tint(accent).foregroundStyle(.black)
                    }
                    Text(session.notice).font(.system(size:12)).foregroundStyle(ink.opacity(0.65)).frame(maxWidth:.infinity,minHeight:30).multilineTextAlignment(.center)
                    HStack(spacing:12) {
                        Button("Undo",systemImage:"arrow.uturn.backward") { session.undo() }.disabled(session.busy || session.moveCount == 0)
                        Button(session.findingHint ? "Finding…":"Hint",systemImage:"lightbulb") { session.hint() }.disabled(session.busy || session.solved || session.findingHint)
                        Spacer(minLength:0)
                        Button { session.togglePause() } label: { Image(systemName:session.paused ? "play.fill":"pause.fill") }.accessibilityLabel(session.paused ? "Resume board":"Pause board")
                        Button(session.solved ? "Play again":"Reset",systemImage:"arrow.counterclockwise") { session.reset() }
                    }.buttonStyle(.bordered).controlSize(.regular)
                }.padding(.horizontal,compact ? 20:32).padding(.vertical,18).background(Color(red:0.065,green:0.060,blue:0.075))
            }.background(Color(red:0.026,green:0.043,blue:0.060)).foregroundStyle(ink)
        }
        .preferredColorScheme(.dark)
        .task { await session.runTrialIfRequested() }
        .onChange(of:reduceTransparency,initial:true) { _,value in session.renderer?.reduceTransparency=value }
        .onChange(of:session.presentation) { _,_ in session.renderer?.reduceTransparency=reduceTransparency }
        .onAppear { if reduceMotion { session.paused=true;session.renderer?.paused=true } }
        .onChange(of:sheet) { _,value in session.setSuspended(value != nil || comparison != nil || showResetProgress || scenePhase != .active) }
        .onChange(of:scenePhase) { _,value in session.setSuspended(value != .active || sheet != nil || comparison != nil || showResetProgress) }
        .onChange(of:comparison?.id) { _,value in session.setSuspended(value != nil || sheet != nil || showResetProgress || scenePhase != .active) }
        .onChange(of:showResetProgress) { _,value in session.setSuspended(value || sheet != nil || comparison != nil || scenePhase != .active) }
        .confirmationDialog("Reset all progress?",isPresented:$showResetProgress,titleVisibility:.visible) {
            Button("Reset all progress",role:.destructive) {
                session.resetAllProgress()
                GameProgressStore.resetAll()
            }
            Button("Cancel",role:.cancel) {}
        } message: {
            Text("Start again at Level 1. This clears all saved puzzles, completion marks, undo history, and Original game progress, scores, and ratings. This can’t be undone.")
        }
        .sheet(item:$comparison) { example in LabPourComparisonView(example:example) }
        .sheet(item:$sheet) { item in
            ZStack(alignment:.topTrailing) {
                if item == .study { FluidLabView() } else { ContentView() }
                Button("Return to board",systemImage:"xmark.circle.fill") { sheet=nil }.buttonStyle(.bordered).padding()
            }.frame(minWidth:360,minHeight:640)
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
        let profiles=LabBoardLayout.profiles(capacities:session.state.capacities)
        if session.presentation == .fluid2D {
            let layout=LabClassicLayout(size:size,vesselCount:profiles.count),profile=session.fluid2D.profiles[index]
            let base=layout.base(index),radius=CGFloat((profile.source.radii.max() ?? 0.6)*profile.scale)*layout.scale
            return CGRect(x:base.x-radius-8,y:base.y-CGFloat(profile.height)*layout.scale-8,width:radius*2+16,height:CGFloat(profile.height)*layout.scale+16)
        }
        if session.presentation == .classic { return LabClassicLayout(size:size,vesselCount:session.state.stacks.count).hitRect(index,profile:profiles[index]) }
        let matrix=LabBoardLayout.camera(aspect:Float(size.width/max(size.height,1)),azimuth:Float(session.orbit),vesselCount:session.state.stacks.count).0
        let home=LabBoardLayout.homes(count:session.state.stacks.count)[index],r=(profiles[index].radii.max() ?? 0.6)+0.05
        var xs:[CGFloat]=[],ys:[CGFloat]=[]
        for x in [-r,r] { for z in [-r,r] { for y:Float in [0,profiles[index].height] {
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

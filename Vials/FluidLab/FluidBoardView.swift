import SwiftUI
import MetalKit
import Combine

private enum BoardSheet:String,Identifiable { case classic,study;var id:String { rawValue } }

struct FluidBoardView:View {
    @StateObject private var session=FluidBoardSession()
    @State private var sheet:BoardSheet?
    @State private var comparison:LabPourExample?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let ink=Color(red:0.80,green:0.88,blue:0.90)
    private let accent=Color(red:0.28,green:0.85,blue:0.79)
    var body:some View {
        GeometryReader { geometry in
            let compact=geometry.size.width<680
            VStack(spacing:0) {
                HStack {
                    VStack(alignment:.leading,spacing:4) {
                        Text("VIALS / FLUID LAB").font(.system(size:10,weight:.semibold,design:.monospaced)).tracking(3).foregroundStyle(ink.opacity(0.5))
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
                    } label: { Image(systemName:"ellipsis.circle").frame(width:32,height:32) }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Board options")
                }.padding(.horizontal,compact ? 20:32).padding(.top,20).padding(.bottom,12)
                HStack(spacing:12) {
                    Picker("Presentation",selection:Binding(get:{session.presentation},set:session.changePresentation)) {
                        ForEach(LabBoardPresentation.allCases,id:\.self) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented).frame(maxWidth:330)
                    Picker("Pace",selection:Binding(get:{session.pace},set:session.changePace)) {
                        ForEach(LabBoardPace.allCases,id:\.self) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented).frame(maxWidth:220)
                    Spacer(minLength:0)
                    Menu {
                        ForEach(LabBoardPuzzle.allCases,id:\.self) { puzzle in Button("\(puzzle.number). \(puzzle.title)\(session.hasCompleted(puzzle) ? " ✓":"")") { session.changePuzzle(puzzle) } }
                    } label: { Image(systemName:"square.grid.2x2").frame(width:28,height:28) }.accessibilityLabel("Choose puzzle")
                }.disabled(session.busy).padding(.horizontal,compact ? 20:32).padding(.bottom,8)
                HStack { Text(session.puzzle.detail);Spacer();Text("\(session.completedPuzzleCount) complete") }.font(.system(size:10,design:.monospaced)).foregroundStyle(ink.opacity(0.55)).padding(.horizontal,compact ? 20:32)
                HStack {
                    Text(session.paused ? "Paused":session.phase).font(.system(size:compact ? 19:24,weight:.light,design:.serif))
                    Spacer()
                    Text("\(session.moveCount) \(session.moveCount == 1 ? "move":"moves")").font(.system(size:12,design:.monospaced)).foregroundStyle(ink.opacity(0.6))
                }.padding(.horizontal,compact ? 20:32).frame(height:38)
                GeometryReader { board in
                    ZStack {
                        if session.presentation == .classic { LabClassicBoardView(state:session.state,pour:session.classicPour) }
                        else if session.presentation == .fluid2D { LabPlanarSurface(display:session.planarDisplay,points:session.points,selected:session.selected,destinations:session.validDestinations,completed:Set(session.state.stacks.indices.filter { session.vialComplete($0) }),rejected:session.rejectedVial) }
                        else if let renderer=session.renderer { BoardMetalSurface(renderer:renderer).accessibilityHidden(true) }
                        else { ContentUnavailableView("Metal unavailable",systemImage:"cube.transparent",description:Text(session.error ?? "Unable to start the fluid renderer.")) }
                        ForEach(session.state.stacks.indices,id:\.self) { index in
                            let rect=hitRect(index,size:board.size)
                            Button { session.select(index) } label: {
                                RoundedRectangle(cornerRadius:20)
                                    .fill(Color.white.opacity(0.001))
                                    .overlay(alignment:.bottom) {
                                        Label(cueLabel(index),systemImage:cueSymbol(index)).font(.system(size:10,weight:.semibold))
                                            .fixedSize().padding(.horizontal,7).padding(.vertical,4).background(.black.opacity(0.75),in:Capsule())
                                            .foregroundStyle(cueColor(index)).opacity(cueLabel(index).isEmpty ? 0:1).offset(y:17)
                                    }
                                    .overlay(RoundedRectangle(cornerRadius:20).stroke(cueColor(index).opacity(session.presentation == .fluid2D ? 0:0.7),style:StrokeStyle(lineWidth:1.5,dash:session.validDestinations.contains(index) ? [4,4]:[])))
                            }
                            .buttonStyle(.plain).frame(width:rect.width,height:rect.height).position(x:rect.midX,y:rect.midY)
                            .disabled(session.busy || session.state.solved)
                            .accessibilityLabel(session.accessibility(index)).accessibilityValue(cueLabel(index))
                        }
                        if session.diagnostics {
                            diagnostics.frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading).padding(14)
                        }
                        if let error=session.error { Text(error).font(.callout).padding().background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:12)) }
                    }
                }.frame(minHeight:220)
                VStack(spacing:14) {
                    LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:8),count:compact && session.state.stacks.count>4 ? 3:session.state.stacks.count),spacing:8) {
                        ForEach(session.state.stacks.indices,id:\.self) { index in
                            Button { session.select(index) } label: {
                                VStack(spacing:5) {
                                    HStack(spacing:5) {
                                        Text(FluidBoardSession.letter(index)).font(.system(size:13,weight:.semibold,design:.monospaced))
                                        Text(session.vialComplete(index) ? "✓":"\(session.state.stacks[index].count) / 4").font(.system(size:11,design:.monospaced)).foregroundStyle(ink.opacity(0.7))
                                    }
                                    HStack(spacing:3) {
                                        ForEach(0..<4,id:\.self) { layer in
                                            Capsule().fill(layer<session.state.stacks[index].count ? FluidBoardSession.color(session.state.colors[session.state.stacks[index][layer]]):ink.opacity(0.09)).frame(height:4)
                                        }
                                    }
                                }.frame(maxWidth:.infinity).padding(.vertical,12).padding(.horizontal,9)
                                    .background(cueLabel(index).isEmpty ? ink.opacity(0.04):cueColor(index).opacity(0.13),in:RoundedRectangle(cornerRadius:10))
                                    .overlay(RoundedRectangle(cornerRadius:10).stroke(cueColor(index).opacity(0.65),lineWidth:1))
                                    .scaleEffect(!reduceMotion && session.selected==index ? 1.025:1)
                                    .offset(x:!reduceMotion && session.rejectedVial==index ? 3:0)
                                    .animation(reduceMotion ? nil:.easeInOut(duration:0.18),value:session.selected)
                                    .animation(reduceMotion ? nil:.easeInOut(duration:0.12),value:session.rejectedVial)
                            }.buttonStyle(.plain).disabled(session.busy || session.state.solved)
                            .accessibilityLabel("Select "+session.accessibility(index)).accessibilityValue(cueLabel(index))
                        }
                    }
                    if session.state.solved,let next=session.puzzle.next {
                        Button("Next: \(next.title)",systemImage:"arrow.right") { session.nextPuzzle() }.buttonStyle(.borderedProminent).tint(accent).foregroundStyle(.black)
                    }
                    Text(session.notice).font(.system(size:12)).foregroundStyle(ink.opacity(0.65)).frame(maxWidth:.infinity,minHeight:30).multilineTextAlignment(.center)
                    HStack(spacing:12) {
                        Button("Undo",systemImage:"arrow.uturn.backward") { session.undo() }.disabled(session.busy || session.moveCount == 0)
                        Button("Hint",systemImage:"lightbulb") { session.hint() }.disabled(session.busy || session.state.solved)
                        Spacer(minLength:0)
                        Button { session.togglePause() } label: { Image(systemName:session.paused ? "play.fill":"pause.fill") }.accessibilityLabel(session.paused ? "Resume board":"Pause board")
                        Button(session.state.solved ? "Play again":"Reset",systemImage:"arrow.counterclockwise") { session.reset() }
                    }.buttonStyle(.bordered).controlSize(.regular)
                }.padding(.horizontal,compact ? 20:32).padding(.vertical,18).background(Color(red:0.065,green:0.060,blue:0.075))
            }.background(Color(red:0.026,green:0.043,blue:0.060)).foregroundStyle(ink)
        }
        .preferredColorScheme(.dark)
        .task { await session.runTrialIfRequested() }
        .onAppear { if reduceMotion { session.paused=true;session.renderer?.paused=true } }
        .onChange(of:sheet) { _,value in session.setSuspended(value != nil || comparison != nil || scenePhase != .active) }
        .onChange(of:scenePhase) { _,value in session.setSuspended(value != .active || sheet != nil || comparison != nil) }
        .onChange(of:comparison?.id) { _,value in session.setSuspended(value != nil || sheet != nil || scenePhase != .active) }
        .sheet(item:$comparison) { example in LabPourComparisonView(example:example) }
        .sheet(item:$sheet) { item in
            ZStack(alignment:.topTrailing) {
                if item == .study { FluidLabView() } else { ContentView() }
                Button("Return to board",systemImage:"xmark.circle.fill") { sheet=nil }.buttonStyle(.bordered).padding()
            }.frame(minWidth:360,minHeight:640)
        }
    }
    private func cueLabel(_ index:Int)->String {
        if session.busy { return "" }
        if session.rejectedVial==index { return "Cannot pour" }
        if session.selected==index { return "Selected" }
        if session.hintTarget==index { return "Hint" }
        if session.validDestinations.contains(index) { return "Pour here" }
        return session.vialComplete(index) ? "Complete":""
    }
    private func cueSymbol(_ index:Int)->String {
        if session.rejectedVial==index { return "xmark.circle" }
        if session.selected==index { return "drop.fill" }
        if session.hintTarget==index { return "lightbulb" }
        return session.validDestinations.contains(index) ? "arrow.down":"checkmark.circle"
    }
    private func cueColor(_ index:Int)->Color {
        if session.busy { return .clear }
        if session.rejectedVial==index || session.hintTarget==index { return .orange }
        if session.selected==index || session.validDestinations.contains(index) || session.vialComplete(index) { return accent }
        return .clear
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
        let profiles=LabBoardLayout.profiles(count:session.state.stacks.count)
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
    func makeNSView(context:Context) -> MTKView { makeBoardView(renderer) }
    func updateNSView(_ view:MTKView,context:Context) {}
    static func dismantleNSView(_ view:MTKView,coordinator:()) { view.isPaused=true;view.delegate=nil }
}
#else
struct BoardMetalSurface:UIViewRepresentable {
    let renderer:LabBoardRenderer
    func makeUIView(context:Context) -> MTKView { makeBoardView(renderer) }
    func updateUIView(_ view:MTKView,context:Context) {}
    static func dismantleUIView(_ view:MTKView,coordinator:()) { view.isPaused=true;view.delegate=nil }
}
#endif
@MainActor private func makeBoardView(_ renderer:LabBoardRenderer) -> MTKView {
    let view=MTKView(frame:.zero,device:renderer.device)
    view.colorPixelFormat = .bgra8Unorm_srgb;view.preferredFramesPerSecond=60
    view.delegate=renderer;view.autoResizeDrawable=false;view.drawableSize=CGSize(width:1000,height:650)
    return view
}

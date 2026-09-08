import SwiftUI
import MetalKit
import Combine

@MainActor final class FluidBoardSession:ObservableObject {
    @Published var state=LabBoardState.firstSort
    @Published var selected:Int?
    @Published var hintTarget:Int?
    @Published var phase="Choose a vial"
    @Published var notice="Tap a filled vial, then a matching color or an empty vial."
    @Published var moveCount=0
    @Published var busy=false
    @Published var paused=false
    @Published var slow=false
    @Published var points=false
    @Published var diagnostics=false
    @Published var orbit:Double=0.12
    @Published var metrics=LabBoardMetrics()
    @Published var correction=0
    @Published var captured:Float=0
    @Published var error:String?
    let renderer:LabBoardRenderer?
    init() {
        do {
            guard let device=MTLCreateSystemDefaultDevice() else { throw LabError.message("Metal is unavailable on this device.") }
            let renderer=try LabBoardRenderer(device:device)
            self.renderer=renderer
            renderer.onError={ [weak self] in self?.error=$0 }
            renderer.onUpdate={ [weak self] _,_,_ in self?.refresh() }
        } catch { renderer=nil;self.error=error.localizedDescription }
    }
    func refresh() {
        guard let renderer else { return }
        state=renderer.game.state;moveCount=renderer.game.moveCount;busy=renderer.game.pending != nil
        phase=renderer.phase;metrics=renderer.lastMetrics;correction=renderer.correctionCount;captured=renderer.arrivalBeforeCorrection
        if state.solved { notice="Every color has a home. Undo to explore, or play again." }
        else if !busy && renderer.lastOutcome.localizedCaseInsensitiveContains("try") { notice=renderer.lastOutcome }
    }
    func select(_ index:Int) {
        guard !busy,!state.solved,let renderer else { return }
        if let source=selected {
            if source == index { selected=nil;hintTarget=nil;notice="Choose another vial.";return }
            guard let move=state.move(from:source,to:index) else {
                notice=state.stacks[index].count == state.capacity ? "That vial is full." : "Choose the same top color or an empty vial."
                return
            }
            if renderer.begin(from:source,to:index) {
                selected=nil;hintTarget=nil;paused=false
                notice="\(move.amount) \(move.amount == 1 ? "unit":"units") of \(Self.name(move.color)) · \(Self.letter(source)) → \(Self.letter(index))"
                refresh()
            }
        } else {
            guard !state.stacks[index].isEmpty else { notice="Choose a vial that contains liquid first.";return }
            selected=index;hintTarget=nil;notice="Now choose a matching color or an empty vial."
        }
    }
    func reset() { renderer?.reset();selected=nil;hintTarget=nil;paused=false;notice="Tap a filled vial, then a matching color or an empty vial.";refresh() }
    func undo() {
        if renderer?.undo() == true { selected=nil;hintTarget=nil;paused=false;notice="Move undone. Try a different route.";refresh() }
    }
    func hint() {
        guard !busy,!state.solved else { return }
        if let move=state.solution()?.first {
            selected=move.source;hintTarget=move.destination
            notice="Try \(Self.letter(move.source)) → \(Self.letter(move.destination)) · \(move.amount) \(Self.name(move.color)) \(move.amount == 1 ? "unit":"units")"
        } else { notice="No solution from here. Undo a move to try another route." }
    }
    func togglePause() { paused.toggle();renderer?.paused=paused }
    static func letter(_ index:Int) -> String { String(UnicodeScalar(65+index)!) }
    static func name(_ color:Int) -> String { color == 0 ? "Tide":"Ember" }
    static func color(_ value:Int) -> Color { value == 0 ? Color(red:0.05,green:0.58,blue:0.86):Color(red:0.96,green:0.34,blue:0.07) }
    func accessibility(_ index:Int) -> String {
        let layers=state.stacks[index].reversed().map { Self.name(state.colors[$0]) }.joined(separator:", ")
        return "Vial \(Self.letter(index)), \(state.stacks[index].count) of 4 units. \(layers.isEmpty ? "Empty":"Top to bottom: "+layers)."
    }
}

private enum BoardSheet:String,Identifiable { case classic,study;var id:String { rawValue } }

struct FluidBoardView:View {
    @StateObject private var session=FluidBoardSession()
    @State private var sheet:BoardSheet?
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
                        Text("First sort").font(.system(size:compact ? 28:34,design:.serif)).foregroundStyle(ink)
                    }
                    Spacer()
                    Button { session.diagnostics.toggle() } label: { Image(systemName:"slider.horizontal.3").frame(width:34,height:34) }
                        .buttonStyle(.plain).accessibilityLabel("Board diagnostics")
                    Menu {
                        Button("Pour study") { sheet = .study }
                        Button("Classic game") { sheet = .classic }
                    } label: { Image(systemName:"ellipsis.circle").frame(width:32,height:32) }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Other experiments")
                }.padding(.horizontal,compact ? 20:32).padding(.top,20).padding(.bottom,12)
                HStack {
                    Text(session.paused ? "Paused":session.phase).font(.system(size:compact ? 19:24,weight:.light,design:.serif))
                    Spacer()
                    Text("\(session.moveCount) \(session.moveCount == 1 ? "move":"moves")").font(.system(size:12,design:.monospaced)).foregroundStyle(ink.opacity(0.6))
                }.padding(.horizontal,compact ? 20:32).frame(height:38)
                GeometryReader { board in
                    ZStack {
                        if let renderer=session.renderer { BoardMetalSurface(renderer:renderer).accessibilityHidden(true) }
                        else { ContentUnavailableView("Metal unavailable",systemImage:"cube.transparent",description:Text(session.error ?? "Unable to start the fluid renderer.")) }
                        ForEach(0..<4,id:\.self) { index in
                            let rect=hitRect(index,size:board.size)
                            Button { session.select(index) } label: {
                                RoundedRectangle(cornerRadius:20)
                                    .fill(Color.white.opacity(0.001))
                                    .overlay(RoundedRectangle(cornerRadius:20).stroke(session.selected == index ? accent:(session.hintTarget == index ? Color.orange:Color.clear),lineWidth:1.5))
                            }
                            .buttonStyle(.plain).frame(width:rect.width,height:rect.height).position(x:rect.midX,y:rect.midY)
                            .disabled(session.busy || session.state.solved)
                            .accessibilityLabel(session.accessibility(index)).accessibilityValue(session.selected == index ? "Selected source":"")
                        }
                        if session.diagnostics {
                            diagnostics.frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading).padding(14)
                        }
                        if let error=session.error { Text(error).font(.callout).padding().background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:12)) }
                    }
                }.frame(minHeight:220)
                VStack(spacing:14) {
                    HStack(spacing:8) {
                        ForEach(0..<4,id:\.self) { index in
                            Button { session.select(index) } label: {
                                VStack(spacing:5) {
                                    HStack(spacing:5) {
                                        Text(FluidBoardSession.letter(index)).font(.system(size:13,weight:.semibold,design:.monospaced))
                                        Text("\(session.state.stacks[index].count) / 4").font(.system(size:11,design:.monospaced)).foregroundStyle(ink.opacity(0.7))
                                    }
                                    HStack(spacing:3) {
                                        ForEach(0..<4,id:\.self) { layer in
                                            Capsule().fill(layer<session.state.stacks[index].count ? FluidBoardSession.color(session.state.colors[session.state.stacks[index][layer]]):ink.opacity(0.09)).frame(height:4)
                                        }
                                    }
                                }.frame(maxWidth:.infinity).padding(.vertical,12).padding(.horizontal,9)
                                    .background((session.selected == index ? accent.opacity(0.16):ink.opacity(0.04)),in:RoundedRectangle(cornerRadius:10))
                            }.buttonStyle(.plain).disabled(session.busy || session.state.solved)
                            .accessibilityLabel("Select "+session.accessibility(index))
                        }
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
        .onAppear { if reduceMotion { session.paused=true;session.renderer?.paused=true } }
        .onChange(of:session.slow) { _,value in session.renderer?.playbackSpeed=value ? 0.35:1 }
        .onChange(of:session.points) { _,value in session.renderer?.pointMode=value }
        .onChange(of:session.orbit) { _,value in session.renderer?.orbit=Float(value) }
        .onChange(of:sheet) { _,value in session.renderer?.paused=value != nil || session.paused || scenePhase != .active }
        .onChange(of:scenePhase) { _,value in session.renderer?.paused=value != .active || session.paused || sheet != nil }
        .sheet(item:$sheet) { item in
            ZStack(alignment:.topTrailing) {
                if item == .study { FluidLabView() } else { ContentView() }
                Button("Return to board",systemImage:"xmark.circle.fill") { sheet=nil }.buttonStyle(.bordered).padding()
            }.frame(minWidth:360,minHeight:640)
        }
    }
    private var diagnostics:some View {
        VStack(alignment:.leading,spacing:7) {
            Text("BOARD STUDY").font(.system(size:9,weight:.bold,design:.monospaced)).tracking(2)
            Text("\(session.renderer?.particleCount ?? 0) particles · \(session.metrics.gpuMilliseconds,specifier:"%.1f") ms GPU")
            Text("Outside: \(session.metrics.outside) · Wrong layer: \(session.metrics.wrongParcel)")
            if session.captured>0 { Text("Captured: \(session.captured*100,specifier:"%.1f")% · Cleanup: \(session.correction)") }
            Toggle("Slow motion",isOn:$session.slow).toggleStyle(.switch).controlSize(.mini)
            Toggle("Show particles",isOn:$session.points).toggleStyle(.switch).controlSize(.mini)
            HStack { Text("View");Slider(value:$session.orbit,in: -0.3...0.4).frame(width:120) }
        }.font(.system(size:10,design:.monospaced)).padding(12).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:12))
    }
    private func hitRect(_ index:Int,size:CGSize) -> CGRect {
        let profiles=session.renderer?.profiles ?? LabBoardLayout.profiles()
        let matrix=LabBoardLayout.camera(aspect:Float(size.width/max(size.height,1)),azimuth:Float(session.orbit)).0
        let home=LabBoardLayout.homes[index],r=(profiles[index].radii.max() ?? 0.6)+0.05
        var xs:[CGFloat]=[],ys:[CGFloat]=[]
        for x in [-r,r] { for z in [-r,r] { for y:Float in [0,profiles[index].height] {
            let p=matrix*SIMD4(home+SIMD3(x,y,z),1)
            xs.append(CGFloat(p.x/p.w+1)*size.width/2);ys.append(CGFloat(1-p.y/p.w)*size.height/2)
        }}}
        return CGRect(x:xs.min()!-6,y:ys.min()!-6,width:xs.max()!-xs.min()!+12,height:ys.max()!-ys.min()!+12)
    }
}

#if os(macOS)
private struct BoardMetalSurface:NSViewRepresentable {
    let renderer:LabBoardRenderer
    func makeNSView(context:Context) -> MTKView { makeBoardView(renderer) }
    func updateNSView(_ view:MTKView,context:Context) {}
    static func dismantleNSView(_ view:MTKView,coordinator:()) { view.isPaused=true;view.delegate=nil }
}
#else
private struct BoardMetalSurface:UIViewRepresentable {
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

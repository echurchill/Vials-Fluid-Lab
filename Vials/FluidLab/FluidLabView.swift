import SwiftUI
import MetalKit
import Combine

@MainActor
final class FluidLabSession: ObservableObject {
    @Published var phase = "Ready to pour"
    @Published var stats = LabFrameStats()
    @Published var isPouring = false
    @Published var isPaused = false
    @Published var points = false
    @Published var material = 0
    @Published var error: String?
    @Published var diagnostics = false
    @Published var orbit: Double = 0.35
    let renderer: LabRenderer?

    init() {
        do {
            guard let device=MTLCreateSystemDefaultDevice() else { throw LabError.message("This device does not support Metal.") }
            let renderer=try LabRenderer(device:device)
            self.renderer=renderer
            renderer.onError = { [weak self] error in self?.error=error }
            renderer.onUpdate = { [weak self] stats, phase, _ in
                self?.stats=stats
                self?.phase=phase
            }
        } catch {
            renderer=nil
            self.error=error.localizedDescription
        }
    }
    func pour() { renderer?.beginPour(); isPouring=true; isPaused=false }
    func reset() {
        renderer?.reset(twoColors:material == 2)
        renderer?.viscosity = material == 1 ? 0.32 : 0.08
        phase="Ready to pour"; isPouring=false; isPaused=false
        stats=renderer?.snapshot() ?? LabFrameStats()
    }
    func pause() { isPaused.toggle(); renderer?.paused=isPaused; stats=renderer?.snapshot() ?? stats }
}

struct FluidLabView: View {
    @StateObject private var session=FluidLabSession()
    @State private var classic=false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let ink=Color(red:0.80,green:0.88,blue:0.90)
    private let teal=Color(red:0.28,green:0.85,blue:0.79)

    var body: some View {
        GeometryReader { proxy in
            let compact=proxy.size.width < 680
            VStack(spacing:0) {
                header(compact:compact)
                    .padding(.horizontal,compact ? 22:36).padding(.top,22).padding(.bottom,18)
                ZStack(alignment:.topLeading) {
                    if let renderer=session.renderer {
                        LabMetalSurface(renderer:renderer)
                            .accessibilityElement(children:.ignore)
                            .accessibilityLabel("3D fluid experiment. A rounded vial pours into a bulb flask.")
                            .accessibilityValue(session.isPaused ? "Paused" : session.phase)
                    } else {
                        ContentUnavailableView("Metal unavailable",systemImage:"cube.transparent",description:Text(session.error ?? "The renderer could not start."))
                    }
                    VStack(alignment:.leading,spacing:7) {
                        Text("01 / VOLUME & MOTION")
                            .font(.system(size:10,weight:.semibold,design:.monospaced)).tracking(2).foregroundStyle(teal.opacity(0.8))
                        Text(session.isPaused ? "Paused" : session.phase).font(.system(size:compact ? 20:26,weight:.light,design:.serif)).foregroundStyle(ink)
                        Text("Equal volumes. Different silhouettes.")
                            .font(.system(size:12)).foregroundStyle(ink.opacity(0.52))
                    }.padding(compact ? 22:36).allowsHitTesting(false)
                    if let error=session.error, session.renderer != nil {
                        Text(error).font(.callout).padding().background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:12)).padding(22)
                    }
                    if session.diagnostics {
                        diagnostics.frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.bottomLeading).padding(22)
                    }
                }
                .frame(maxWidth:.infinity,maxHeight:.infinity)
                footer(compact:compact)
            }
            .background(Color(red:0.026,green:0.043,blue:0.060))
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if reduceMotion { session.isPaused=true; session.renderer?.paused=true }
        }
        .sheet(isPresented:$classic) {
            ZStack(alignment:.topTrailing) {
                ContentView()
                Button("Return to Fluid Lab",systemImage:"xmark.circle.fill") { classic=false }
                    .buttonStyle(.bordered).padding()
            }.frame(minWidth:320,minHeight:560)
        }
        .onChange(of:session.material) { _,_ in session.reset() }
        .onChange(of:session.points) { _,value in session.renderer?.pointMode=value }
        .onChange(of:session.orbit) { _,value in session.renderer?.orbit=Float(value) }
        .onChange(of:classic) { _,value in session.renderer?.paused=value || session.isPaused }
        .onChange(of:scenePhase) { _,phase in
            session.renderer?.paused=phase != .active || session.isPaused || classic
        }
    }

    private func header(compact:Bool) -> some View {
        HStack(alignment:.center) {
            VStack(alignment:.leading,spacing:4) {
                Text("VIALS").font(.system(size:11,weight:.semibold)).tracking(5).foregroundStyle(ink.opacity(0.50))
                Text("Fluid Lab").font(.system(size:compact ? 28:34,weight:.regular,design:.serif)).foregroundStyle(ink)
            }
            Spacer()
            Button { session.diagnostics.toggle() } label: {
                Image(systemName:"slider.horizontal.3").font(.system(size:16)).frame(width:36,height:36)
            }.buttonStyle(.plain).foregroundStyle(ink.opacity(0.7)).accessibilityLabel("Show simulation diagnostics")
            Button("Classic") { classic=true }.buttonStyle(.bordered).tint(ink.opacity(0.7))
        }
    }

    private func footer(compact:Bool) -> some View {
        VStack(spacing:18) {
            HStack(alignment:.top) {
                vesselLabel("A",name:"Rounded vial",amount:amount(source:true),alignment:.leading)
                Spacer()
                Image(systemName:"arrow.right").foregroundStyle(teal.opacity(0.6)).padding(.top,10)
                Spacer()
                vesselLabel("B",name:"Bulb flask",amount:amount(source:false),alignment:.trailing)
            }
            Rectangle().fill(ink.opacity(0.10)).frame(height:1)
            ViewThatFits(in:.horizontal) {
                HStack(spacing:18) { materialPicker.frame(width:250); Spacer(minLength:8); controls }
                VStack(spacing:14) { materialPicker; controls }
            }
            if reduceMotion {
                Text("For reduced motion, pause the scene and inspect the vessels with the view control.")
                    .font(.caption).foregroundStyle(ink.opacity(0.5))
            } else {
                Text("A live fluid study · Reset to try another material")
                    .font(.system(size:11)).foregroundStyle(ink.opacity(0.38))
            }
        }
        .padding(.horizontal,compact ? 22:36).padding(.vertical,20)
        .background(Color(red:0.08,green:0.054,blue:0.069))
    }

    private var materialPicker: some View {
        Picker("Liquid",selection:$session.material) {
            Text("Water").tag(0); Text("Thick").tag(1); Text("Two dyes").tag(2)
        }.pickerStyle(.segmented).accessibilityHint("Changing material resets the experiment.")
    }
    private var controls: some View {
        HStack(spacing:10) {
            Button { session.reset() } label: { Image(systemName:"arrow.counterclockwise").frame(width:24,height:22) }
                .buttonStyle(.bordered).accessibilityLabel("Reset experiment")
            Button { session.pause() } label: { Image(systemName:session.isPaused ? "play.fill":"pause.fill").frame(width:24,height:22) }
                .buttonStyle(.bordered).accessibilityLabel(session.isPaused ? "Resume simulation":"Pause simulation")
            Button { session.pour() } label: {
                Label("Pour liquid",systemImage:"drop.fill").font(.system(size:13,weight:.semibold)).padding(.horizontal,10).padding(.vertical,4)
            }.buttonStyle(.borderedProminent).tint(teal).foregroundStyle(Color(red:0.03,green:0.16,blue:0.16))
                .disabled(session.isPouring || session.renderer == nil)
        }
    }
    private func vesselLabel(_ letter:String,name:String,amount:String,alignment:HorizontalAlignment) -> some View {
        VStack(alignment:alignment,spacing:5) {
            Text("\(letter)  /  \(name.uppercased())").font(.system(size:10,weight:.medium,design:.monospaced)).tracking(1.2).foregroundStyle(ink.opacity(0.48))
            Text(amount).font(.system(size:18,weight:.light)).foregroundStyle(ink)
        }
    }
    private func amount(source:Bool) -> String {
        guard let renderer=session.renderer else { return "—" }
        let count=source ? session.stats.source:session.stats.destination
        if !session.isPouring { return source ? "3.00 units":"Empty · 4 unit capacity" }
        return String(format:"%.2f units",Float(count)/Float(renderer.particleCount)*3)
    }
    private var diagnostics: some View {
        VStack(alignment:.leading,spacing:9) {
            Text("SIMULATION").font(.system(size:9,weight:.bold,design:.monospaced)).tracking(2)
            Text("\(session.renderer?.particleCount ?? 0) particles · \(session.stats.gpuMilliseconds,specifier:"%.1f") ms GPU")
            Text("In flight: \(session.stats.airborne) · On tray: \(session.stats.spilled)")
            Toggle("Show particles",isOn:$session.points).toggleStyle(.switch).controlSize(.mini)
            HStack { Text("View"); Slider(value:$session.orbit,in: -0.65...0.8).frame(width:140) }
            if session.material == 2 { Text("Passive dyes: no chemistry or density separation yet.").font(.caption2) }
        }
        .font(.system(size:11,design:.monospaced)).foregroundStyle(ink.opacity(0.8))
        .padding(14).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:14))
    }
}

#if os(macOS)
struct LabMetalSurface: NSViewRepresentable {
    let renderer:LabRenderer
    func makeNSView(context:Context) -> MTKView { makeLabMetalView(renderer) }
    func updateNSView(_ view:MTKView,context:Context) {}
    static func dismantleNSView(_ view:MTKView,coordinator:()) { view.isPaused=true; view.delegate=nil }
}
#else
struct LabMetalSurface: UIViewRepresentable {
    let renderer:LabRenderer
    func makeUIView(context:Context) -> MTKView { makeLabMetalView(renderer) }
    func updateUIView(_ view:MTKView,context:Context) {}
    static func dismantleUIView(_ view:MTKView,coordinator:()) { view.isPaused=true; view.delegate=nil }
}
#endif

@MainActor
private func makeLabMetalView(_ renderer:LabRenderer) -> MTKView {
    let view=MTKView(frame:.zero,device:renderer.device)
    view.colorPixelFormat = .bgra8Unorm_srgb
    view.preferredFramesPerSecond=60
    view.delegate=renderer
    view.clearColor=MTLClearColorMake(0.025,0.04,0.06,1)
    // Keep the initial prototype's offscreen passes bounded on Retina displays.
    view.autoResizeDrawable=false
    #if os(macOS)
    view.drawableSize=CGSize(width:1200,height:800)
    #else
    view.drawableSize=CGSize(width:900,height:1000)
    #endif
    return view
}

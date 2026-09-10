import SwiftUI
import MetalKit

struct LabPourComparisonView:View {
    @StateObject private var comparison:LabPourComparison
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    init(example:LabPourExample) { _comparison=StateObject(wrappedValue:LabPourComparison(example:example)) }
    var body:some View {
        LabPourComparisonContent(comparison:comparison,session:comparison.session,close:{ dismiss() })
            .task { await comparison.prepare() }
            .onChange(of:scenePhase) { _,phase in comparison.session.setSuspended(phase != .active) }
            .onDisappear { comparison.session.discardPreview() }
            .preferredColorScheme(.dark)
    }
}

private struct LabPourComparisonContent:View {
    @ObservedObject var comparison:LabPourComparison
    @ObservedObject var session:FluidBoardSession
    var close:()->Void
    var body:some View {
        VStack(spacing:16) {
            HStack {
                VStack(alignment:.leading,spacing:5) {
                    Text("Compare a pour").font(.title2.weight(.semibold))
                    Text("\(FluidBoardSession.letter(comparison.example.move.source)) → \(FluidBoardSession.letter(comparison.example.move.destination)) · \(comparison.example.move.amount) \(comparison.example.move.amount==1 ? "unit":"units") of \(FluidBoardSession.name(comparison.example.move.color))").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done",action:close).buttonStyle(.bordered)
            }
            Picker("Presentation",selection:Binding(get:{session.presentation},set:comparison.choose)) {
                ForEach(LabBoardPresentation.allCases,id:\.self) { mode in
                    Text(mode.title).tag(mode).disabled(comparison.durations[mode]==nil)
                }
            }.pickerStyle(.segmented).disabled(session.busy || comparison.preparing)
            ZStack {
                if session.presentation == .classic { LabClassicBoardView(state:session.state,pour:session.classicPour) }
                else if session.presentation == .fluid2D { LabFluid2DView(engine:session.fluid2D,frame:session.planarFrame) }
                else if let renderer=session.renderer { BoardMetalSurface(renderer:renderer).id(ObjectIdentifier(renderer)) }
            }.frame(maxWidth:.infinity,maxHeight:.infinity).frame(minHeight:220)
                .background(Color(red:0.026,green:0.043,blue:0.060),in:RoundedRectangle(cornerRadius:18))
            if comparison.preparing { HStack { ProgressView().controlSize(.small);Text(comparison.status).font(.callout) } }
            else {
                Toggle("Match duration · about 5 seconds",isOn:$comparison.matchDuration).disabled(session.busy)
                Text(comparison.matchDuration ? "Playback speed is adjusted for this pour. Fluid motion and rules stay the same.":"Uses each view’s normal Quick pace.").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button(session.busy ? (session.paused ? "Resume":"Pause"):"Replay pour",systemImage:session.busy ? (session.paused ? "play.fill":"pause.fill"):"arrow.clockwise") {
                        if session.busy { session.togglePause() } else { _=comparison.play() }
                    }.buttonStyle(.borderedProminent).tint(.teal)
                    if session.busy { Button("Stop",systemImage:"stop.fill",action:comparison.stop).buttonStyle(.bordered) }
                }
                Text(comparison.status).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }.padding(24).frame(minWidth:340,minHeight:560).background(Color(red:0.045,green:0.060,blue:0.075))
    }
}

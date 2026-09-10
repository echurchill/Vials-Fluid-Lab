import SwiftUI

/// The frame subscription ends here; the board and comparison controls observe
/// only the slower-changing session. Canvas still receives an immutable value.
struct LabPlanarSurface:View {
    @ObservedObject var display:LabPlanarDisplay
    var points=false
    var selected:Int?
    var destinations:Set<Int>=[]
    var rejected:Int?
    var body:some View {
        LabFluid2DView(engine:display.snapshot,points:points,frame:display.frame,selected:selected,destinations:destinations,rejected:rejected)
    }
}

struct LabPlanarDiagnostics:View {
    @ObservedObject var display:LabPlanarDisplay
    var body:some View {
        Text("\(display.snapshot.particles.count) particles · \(display.snapshot.cpuMilliseconds,specifier:"%.1f") ms solver CPU")
        Text("Arrived: \(display.snapshot.arrived) · Cleanup: \(display.snapshot.cleanupPercent,specifier:"%.1f")%")
    }
}

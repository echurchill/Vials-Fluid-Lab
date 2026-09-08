import SwiftUI

@main
struct VialsApp: App {
    var body: some Scene {
        WindowGroup {
            FluidLabView()
                #if os(macOS)
                .frame(minWidth:680,minHeight:720)
                #endif
        }
    }
}

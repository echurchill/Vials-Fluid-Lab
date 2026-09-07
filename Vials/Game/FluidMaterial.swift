import SwiftUI

struct FluidMaterial: Equatable {
    enum Kind: Equatable {
        case clear
        case fizzy
        case sparkling
        case creamy
        case dense
        case glowing
        case iridescent
    }

    let kind: Kind
    let streamWidth: CGFloat
    let pourDuration: Double
    let waveAmplitude: CGFloat
    let particleCount: Int
}

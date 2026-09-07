import SwiftUI

enum Fluid: String, CaseIterable, Identifiable {
    case ember
    case tide
    case fern
    case petal
    case sun
    case cream
    case violet
    case mint
    case ruby
    case cobalt
    case lime
    case pearl

    var id: String { rawValue }

    nonisolated init?(levelCode: Character) {
        switch levelCode {
        case "0": self = .ember
        case "1": self = .tide
        case "2": self = .fern
        case "3": self = .petal
        case "4": self = .sun
        case "5": self = .cream
        case "6": self = .violet
        case "7": self = .mint
        case "8": self = .ruby
        case "9": self = .cobalt
        case "A": self = .lime
        case "B": self = .pearl
        default: return nil
        }
    }

    var displayName: String {
        switch self {
        case .ember: "Ember"
        case .tide: "Tide"
        case .fern: "Fern"
        case .petal: "Petal"
        case .sun: "Sun"
        case .cream: "Cream"
        case .violet: "Violet"
        case .mint: "Mint"
        case .ruby: "Ruby"
        case .cobalt: "Cobalt"
        case .lime: "Lime"
        case .pearl: "Pearl"
        }
    }

    var color: Color {
        switch self {
        case .ember: Color(red: 0.96, green: 0.34, blue: 0.07)
        case .tide: Color(red: 0.05, green: 0.58, blue: 0.86)
        case .fern: Color(red: 0.00, green: 0.36, blue: 0.18)
        case .petal: Color(red: 0.94, green: 0.34, blue: 0.65)
        case .sun: Color(red: 1.00, green: 0.72, blue: 0.08)
        case .cream: Color(red: 0.98, green: 0.71, blue: 0.61)
        case .violet: Color(red: 0.55, green: 0.30, blue: 0.95)
        case .mint: Color(red: 0.12, green: 0.78, blue: 0.62)
        case .ruby: Color(red: 0.72, green: 0.04, blue: 0.24)
        case .cobalt: Color(red: 0.08, green: 0.24, blue: 0.88)
        case .lime: Color(red: 0.54, green: 0.78, blue: 0.06)
        case .pearl: Color(red: 0.82, green: 0.78, blue: 0.68)
        }
    }

    var shine: Color {
        switch self {
        case .ember: Color(red: 1.00, green: 0.58, blue: 0.20)
        case .tide: Color(red: 0.16, green: 0.75, blue: 0.98)
        case .fern: Color(red: 0.10, green: 0.56, blue: 0.28)
        case .petal: Color(red: 1.00, green: 0.55, blue: 0.78)
        case .sun: Color(red: 1.00, green: 0.86, blue: 0.18)
        case .cream: Color(red: 1.00, green: 0.82, blue: 0.73)
        case .violet: Color(red: 0.74, green: 0.52, blue: 1.00)
        case .mint: Color(red: 0.30, green: 0.96, blue: 0.78)
        case .ruby: Color(red: 0.92, green: 0.16, blue: 0.38)
        case .cobalt: Color(red: 0.24, green: 0.46, blue: 1.00)
        case .lime: Color(red: 0.72, green: 0.94, blue: 0.16)
        case .pearl: Color(red: 0.96, green: 0.91, blue: 0.78)
        }
    }

    var material: FluidMaterial {
        switch self {
        case .ember:
            FluidMaterial(kind: .glowing, streamWidth: 8, pourDuration: 0.50, waveAmplitude: 3.4, particleCount: 8)
        case .tide:
            FluidMaterial(kind: .clear, streamWidth: 7, pourDuration: 0.42, waveAmplitude: 4.0, particleCount: 10)
        case .fern:
            FluidMaterial(kind: .dense, streamWidth: 9, pourDuration: 0.60, waveAmplitude: 2.2, particleCount: 5)
        case .petal:
            FluidMaterial(kind: .sparkling, streamWidth: 7, pourDuration: 0.46, waveAmplitude: 3.2, particleCount: 12)
        case .sun:
            FluidMaterial(kind: .fizzy, streamWidth: 8, pourDuration: 0.48, waveAmplitude: 3.8, particleCount: 14)
        case .cream:
            FluidMaterial(kind: .creamy, streamWidth: 10, pourDuration: 0.64, waveAmplitude: 1.8, particleCount: 4)
        case .violet:
            FluidMaterial(kind: .iridescent, streamWidth: 8, pourDuration: 0.52, waveAmplitude: 3.0, particleCount: 9)
        case .mint:
            FluidMaterial(kind: .clear, streamWidth: 7, pourDuration: 0.44, waveAmplitude: 3.6, particleCount: 9)
        case .ruby:
            FluidMaterial(kind: .glowing, streamWidth: 8, pourDuration: 0.54, waveAmplitude: 2.8, particleCount: 7)
        case .cobalt:
            FluidMaterial(kind: .sparkling, streamWidth: 7, pourDuration: 0.46, waveAmplitude: 3.4, particleCount: 11)
        case .lime:
            FluidMaterial(kind: .fizzy, streamWidth: 8, pourDuration: 0.48, waveAmplitude: 3.8, particleCount: 13)
        case .pearl:
            FluidMaterial(kind: .creamy, streamWidth: 9, pourDuration: 0.62, waveAmplitude: 2.0, particleCount: 5)
        }
    }
}

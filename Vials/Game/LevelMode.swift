import Foundation

enum LevelMode: String, CaseIterable, Identifiable {
    case easy
    case medium
    case hard
    case experiments
    case zen

    var id: String { rawValue }

    static var visibleCases: [LevelMode] {
        [.easy, .medium, .hard, .experiments]
    }

    var maximumLevel: Int? {
        self == .experiments ? 15 : nil
    }

    nonisolated var displayName: String {
        switch self {
        case .easy: "Easy"
        case .medium: "Medium"
        case .hard: "Hard"
        case .experiments: "Experiments"
        case .zen: "Zen"
        }
    }

    nonisolated var systemImage: String {
        switch self {
        case .easy: "leaf.fill"
        case .medium: "dial.medium.fill"
        case .hard: "flame.fill"
        case .experiments: "flask.fill"
        case .zen: "sparkles"
        }
    }

    nonisolated var seedNamespace: UInt64 {
        switch self {
        case .easy: 0xEA5E_EA5E_EA5E_EA5E
        case .medium: 0x0DED_1A00_0000_0001
        case .hard: 0xA11D_A11D_A11D_A11D
        case .experiments: 0xE7E7_E7E7_E7E7_E7E7
        case .zen: 0x2E11_2E11_2E11_2E11
        }
    }
}

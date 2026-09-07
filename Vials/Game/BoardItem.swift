import SwiftUI

enum BoardItem: Identifiable {
    case vial(Int)
    case cup

    var id: String {
        switch self {
        case .vial(let index): "vial-\(index)"
        case .cup: "cup"
        }
    }
}

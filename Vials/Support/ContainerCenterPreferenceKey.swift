import SwiftUI

struct ContainerCenterPreferenceKey: PreferenceKey {
    static var defaultValue: [ContainerRef: CGPoint] = [:]

    static func reduce(value: inout [ContainerRef: CGPoint], nextValue: () -> [ContainerRef: CGPoint]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

import Foundation

enum LevelVariantStore {
    private static let storageKey = "vials.levelGenerationVariants"

    static func variant(for mode: LevelMode, levelNumber: Int, zenSalt: UInt64) -> Int? {
        variants[key(for: mode, levelNumber: levelNumber, zenSalt: zenSalt)]
    }

    static func save(_ variant: Int, for mode: LevelMode, levelNumber: Int, zenSalt: UInt64) {
        var updated = variants
        updated[key(for: mode, levelNumber: levelNumber, zenSalt: zenSalt)] = variant
        UserDefaults.standard.set(updated, forKey: storageKey)
    }

    static func reset(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }

    private static var variants: [String: Int] {
        UserDefaults.standard.dictionary(forKey: storageKey) as? [String: Int] ?? [:]
    }

    private static func key(for mode: LevelMode, levelNumber: Int, zenSalt: UInt64) -> String {
        "\(mode.rawValue)-\(levelNumber)-\(zenSalt)"
    }
}

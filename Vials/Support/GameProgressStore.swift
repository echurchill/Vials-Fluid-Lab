import Foundation

enum GameProgressStore {
    // Invalidate detached preparation and delayed completions from an old run.
    private(set) static var resetGeneration=UUID()
    struct Progress {
        let mode: LevelMode
        let levelNumber: Int
        let zenSalt: UInt64
    }

    private static let modeKey = "progress.mode"
    private static let levelNumberKey = "progress.levelNumber"
    private static let zenSaltKey = "progress.zenSalt"

    static func load(defaults: UserDefaults = .standard) -> Progress {
        let savedMode = defaults.string(forKey: modeKey).flatMap(LevelMode.init(rawValue:)) ?? .easy
        let mode = LevelMode.visibleCases.contains(savedMode) ? savedMode : .easy
        let savedLevelNumber = defaults.object(forKey: levelNumberKey) as? Int ?? 1
        let savedZenSalt = defaults.string(forKey: zenSaltKey).flatMap(UInt64.init) ?? UInt64.random(in: 1...UInt64.max)

        return Progress(
            mode: mode,
            levelNumber: max(1, savedLevelNumber),
            zenSalt: savedZenSalt
        )
    }

    /// Only progress owned by the bundled Original game is removed.
    static func resetAll(defaults: UserDefaults = .standard) {
        resetGeneration=UUID()
        for key in [modeKey, levelNumberKey, zenSaltKey] { defaults.removeObject(forKey: key) }
        PlayerResultStore.reset(defaults: defaults)
        LevelVariantStore.reset(defaults: defaults)
        LevelFeedbackStore.clear(defaults: defaults)
    }

    static func save(mode: LevelMode, levelNumber: Int, zenSalt: UInt64) {
        guard mode != .experiments else { return }
        let defaults = UserDefaults.standard
        defaults.set(mode.rawValue, forKey: modeKey)
        defaults.set(max(1, levelNumber), forKey: levelNumberKey)
        defaults.set(String(zenSalt), forKey: zenSaltKey)
    }
}

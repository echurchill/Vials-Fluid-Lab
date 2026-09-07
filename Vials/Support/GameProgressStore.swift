import Foundation

enum GameProgressStore {
    struct Progress {
        let mode: LevelMode
        let levelNumber: Int
        let zenSalt: UInt64
    }

    private static let modeKey = "progress.mode"
    private static let levelNumberKey = "progress.levelNumber"
    private static let zenSaltKey = "progress.zenSalt"

    static func load() -> Progress {
        let defaults = UserDefaults.standard
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

    static func save(mode: LevelMode, levelNumber: Int, zenSalt: UInt64) {
        guard mode != .experiments else { return }
        let defaults = UserDefaults.standard
        defaults.set(mode.rawValue, forKey: modeKey)
        defaults.set(max(1, levelNumber), forKey: levelNumberKey)
        defaults.set(String(zenSalt), forKey: zenSaltKey)
    }
}

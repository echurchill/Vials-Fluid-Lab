import Foundation

enum LevelFeedbackRating: String, Codable, CaseIterable, Identifiable {
    case up
    case neutral
    case down

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .up: "hand.thumbsup.fill"
        case .neutral: "minus.circle.fill"
        case .down: "hand.thumbsdown.fill"
        }
    }

    var label: String {
        switch self {
        case .up: "Liked this level"
        case .neutral: "Felt neutral about this level"
        case .down: "Did not like this level"
        }
    }
}

struct LevelFeedback: Codable, Identifiable {
    let id: String
    let mode: String
    let levelNumber: Int
    let zenSalt: String
    let rating: LevelFeedbackRating
    let moveCount: Int
    let minimumMoveCount: Int?
    let recordedAt: Date
}

enum LevelFeedbackStore {
    private static let feedbackKey = "tester.levelFeedback"

    static func rating(mode: LevelMode, levelNumber: Int, zenSalt: UInt64) -> LevelFeedbackRating? {
        load().first { $0.id == feedbackID(mode: mode, levelNumber: levelNumber, zenSalt: zenSalt) }?.rating
    }

    static func allFeedback() -> [LevelFeedback] {
        load().sorted {
            if $0.mode != $1.mode { return $0.mode < $1.mode }
            return $0.levelNumber < $1.levelNumber
        }
    }

    static func record(
        rating: LevelFeedbackRating,
        mode: LevelMode,
        levelNumber: Int,
        zenSalt: UInt64,
        moveCount: Int,
        minimumMoveCount: Int?
    ) {
        let id = feedbackID(mode: mode, levelNumber: levelNumber, zenSalt: zenSalt)
        let entry = LevelFeedback(
            id: id,
            mode: mode.rawValue,
            levelNumber: levelNumber,
            zenSalt: String(zenSalt),
            rating: rating,
            moveCount: moveCount,
            minimumMoveCount: minimumMoveCount,
            recordedAt: Date()
        )
        var feedback = load().filter { $0.id != id }
        feedback.append(entry)
        save(feedback)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: feedbackKey)
    }

    private static func feedbackID(mode: LevelMode, levelNumber: Int, zenSalt: UInt64) -> String {
        "\(mode.rawValue)-\(levelNumber)-\(zenSalt)"
    }

    private static func load() -> [LevelFeedback] {
        guard let data = UserDefaults.standard.data(forKey: feedbackKey) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([LevelFeedback].self, from: data)) ?? []
    }

    private static func save(_ feedback: [LevelFeedback]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        UserDefaults.standard.set(try? encoder.encode(feedback), forKey: feedbackKey)
    }
}

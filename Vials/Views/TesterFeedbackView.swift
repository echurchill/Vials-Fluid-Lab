import SwiftUI

struct TesterFeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var feedback = LevelFeedbackStore.allFeedback()
    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                GameBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        summary

                        if feedback.isEmpty {
                            ContentUnavailableView(
                                "No ratings yet",
                                systemImage: "hand.thumbsup",
                                description: Text("Level ratings will appear here after a player finishes a level."))
                                .frame(maxWidth: .infinity)
                                .padding(.top, 92)
                        } else {
                            if !experimentFeedback.isEmpty {
                                experimentFeedbackSection
                            }

                            ForEach(LevelMode.visibleCases.filter { $0 != .experiments }) { mode in
                                let modeFeedback = feedback.filter { $0.mode == mode.rawValue }
                                if !modeFeedback.isEmpty {
                                    feedbackSection(mode: mode, entries: modeFeedback)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Tester Feedback")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear", role: .destructive) {
                        showClearConfirmation = true
                    }
                    .disabled(feedback.isEmpty)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: dismiss.callAsFunction)
                }
            }
            .onAppear {
                feedback = LevelFeedbackStore.allFeedback()
            }
            .alert("Clear all tester feedback?", isPresented: $showClearConfirmation) {
                Button("Clear Feedback", role: .destructive) {
                    LevelFeedbackStore.clear()
                    feedback = []
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes every saved rating from this device.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private var summary: some View {
        HStack(spacing: 10) {
            FeedbackSummaryPill(rating: .up, count: count(for: .up))
            FeedbackSummaryPill(rating: .neutral, count: count(for: .neutral))
            FeedbackSummaryPill(rating: .down, count: count(for: .down))
        }
    }

    private var experimentFeedback: [LevelFeedback] {
        feedback.filter { $0.mode == LevelMode.experiments.rawValue }
    }

    private var experimentFeedbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label(LevelMode.experiments.displayName, systemImage: LevelMode.experiments.systemImage)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.cyan)

                Spacer(minLength: 8)

                Text("\(experimentFeedback.count) / \(LevelMode.experiments.maximumLevel ?? 0) rated")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                FeedbackSummaryPill(rating: .up, count: experimentCount(for: .up))
                FeedbackSummaryPill(rating: .neutral, count: experimentCount(for: .neutral))
                FeedbackSummaryPill(rating: .down, count: experimentCount(for: .down))
            }

            ForEach(experimentFeedback) { entry in
                feedbackRow(entry)
            }
        }
    }

    private func feedbackSection(mode: LevelMode, entries: [LevelFeedback]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(mode.displayName, systemImage: mode.systemImage)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))

            ForEach(entries) { entry in
                feedbackRow(entry)
            }
        }
    }

    private func feedbackRow(_ entry: LevelFeedback) -> some View {
        HStack(spacing: 12) {
            Image(systemName: entry.rating.systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(color(for: entry.rating))
                .frame(width: 24)

            Text("Level \(entry.levelNumber)")
                .font(.system(size: 16, weight: .bold, design: .rounded))

            Spacer(minLength: 8)

            Text(moveText(for: entry))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func count(for rating: LevelFeedbackRating) -> Int {
        feedback.filter { $0.rating == rating }.count
    }

    private func experimentCount(for rating: LevelFeedbackRating) -> Int {
        experimentFeedback.filter { $0.rating == rating }.count
    }

    private func moveText(for entry: LevelFeedback) -> String {
        if let minimumMoveCount = entry.minimumMoveCount {
            return "\(entry.moveCount) / \(minimumMoveCount)"
        }
        return "\(entry.moveCount) moves"
    }

    private func color(for rating: LevelFeedbackRating) -> Color {
        switch rating {
        case .up: .mint
        case .neutral: .yellow
        case .down: .pink
        }
    }
}

private struct FeedbackSummaryPill: View {
    let rating: LevelFeedbackRating
    let count: Int

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: rating.systemImage)
                .font(.system(size: 15, weight: .bold))
            Text("\(count)")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var color: Color {
        switch rating {
        case .up: .mint
        case .neutral: .yellow
        case .down: .pink
        }
    }
}

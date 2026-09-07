import SwiftUI

struct GameBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.16)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.07, blue: 0.22).opacity(0.96),
                    Color(red: 0.04, green: 0.06, blue: 0.14).opacity(0.98)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            BackgroundSweep()
                .fill(.white.opacity(0.025))
                .ignoresSafeArea()
        }
    }
}

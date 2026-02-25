import SwiftUI

struct EcoScoreRingView: View {
    let score: Int
    let title: String
    let subtitle: String
    let theme: EcoTheme

    @State private var animatedProgress: Double = 0

    private var progress: Double {
        Double(max(0, min(score, 100))) / 100
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(theme.borderColor.opacity(theme.isDark ? 0.6 : 1), lineWidth: 16)

                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        AngularGradient(
                            colors: [Color(hex: 0x49C97A), Color(hex: 0x32B768), Color(hex: 0x0F9D58)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(score)%")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(theme.primaryText)
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(width: 138, height: 138)

            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(theme.primaryText)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) {
            withAnimation(.easeOut(duration: 0.5)) {
                animatedProgress = progress
            }
        }
    }
}

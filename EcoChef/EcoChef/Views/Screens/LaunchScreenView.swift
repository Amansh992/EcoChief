import SwiftUI

struct LaunchScreenView: View {
    let theme: EcoTheme

    @State private var float = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(theme.elevatedBackground)
                    .frame(width: 120, height: 120)
                    .shadow(color: theme.shadowDark, radius: 16, x: 8, y: 8)
                    .shadow(color: theme.shadowLight, radius: 14, x: -6, y: -6)

                Text("🥬")
                    .font(.system(size: 70))
            }
            .offset(y: float ? -10 : 10)

            Text("EcoChef")
                .font(.largeTitle.bold())
                .foregroundStyle(theme.accentGradient)

            Text("Smart Kitchen Companion")
                .font(.callout.weight(.medium))
                .foregroundStyle(theme.secondaryText)

            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                float = true
            }
        }
    }
}

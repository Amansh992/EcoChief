import SwiftUI

struct AboutPrototypeView: View {
    @ObservedObject var viewModel: EcoChefViewModel
    let theme: EcoTheme
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(spacing: 30) {
                    appInfoCard
                    impactCard
                    missionCard
                }
                .padding(.horizontal, 30)
                .padding(.top, 22)
                .padding(.bottom, 122)
            }
        }
    }

    private var header: some View {
        HStack {
            Button {
                HapticsService.tap()
                onBack()
            } label: {
                Text("←")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(theme.accent)
                    .frame(width: 44, height: 44)
                    .ecoCardStyle(theme: theme, cornerRadius: 12)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("About EcoChef")
                .font(.headline.weight(.heavy))
                .foregroundStyle(theme.primaryText)

            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 46)
    }

    private var appInfoCard: some View {
        VStack(spacing: 10) {
            Text("🥬")
                .font(.system(size: 80))
            Text("EcoChef")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(theme.accentGradient)
            Text("Version 1.0")
                .font(.body.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
            //Text("Created for Swift Student Challenge 2026")
                .font(.subheadline)
                .foregroundStyle(theme.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .padding(30)
        .frame(maxWidth: .infinity)
        .ecoCardStyle(theme: theme, cornerRadius: 24)
    }

    private var impactCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your Impact")
                .font(.title3.weight(.heavy))
                .foregroundStyle(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack {
                Spacer()
                statPill(value: "\(savedItems)", label: "Items Saved", colors: [Color(hex: 0x66BB6A), Color(hex: 0x4CAF50)])
                Spacer()
                statPill(value: "\(wastedItems)", label: "Items Wasted", colors: [Color(hex: 0xEF5350), Color(hex: 0xE53935)])
                Spacer()
            }

            Rectangle()
                .fill(theme.borderColor)
                .frame(height: 1)

            detailRow("Money Saved", "₹\(viewModel.monthlyMoneySaved)")
            detailRow("CO₂ Reduced", String(format: "%.1fkg", viewModel.monthlyCO2SavedKg))
            detailRow("Meals Cooked", "\(viewModel.mealsFromRescuedFood)")
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .ecoCardStyle(theme: theme, cornerRadius: 24)
    }

    private var missionCard: some View {
        Text("Helping reduce food waste, one meal at a time! 🌍")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(theme.secondaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(24)
            .ecoCardStyle(theme: theme, cornerRadius: 24)
    }

    private func statPill(value: String, label: String, colors: [Color]) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 42, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.tertiaryText)
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(theme.primaryText)
        }
    }

    private var savedItems: Int {
        viewModel.totalSavedItems
    }

    private var wastedItems: Int {
        viewModel.totalWastedItems
    }
}

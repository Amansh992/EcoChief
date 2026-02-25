import SwiftUI

struct FreshnessCardView: View {
    let food: FoodItem
    let language: AppLanguage
    let theme: EcoTheme
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var shakeOffset: CGFloat = 0
    @State private var shakeTask: Task<Void, Never>?
    @State private var suppressNextCardTap = false

    private var progressColor: Color {
        switch food.freshnessState {
        case .safe:
            return Color(hex: 0x66BB6A)
        case .warning:
            return Color(hex: 0xFF9800)
        case .critical:
            return Color(hex: 0xF44336)
        }
    }

    private var progress: CGFloat {
        CGFloat(min(max(food.freshnessProgress, 0.05), 1))
    }

    private var daysLabel: String {
        let days = max(food.daysLeft, 1)
        if food.expiryStage == .expired {
            return "Expired - remove now"
        }
        if food.freshnessState == .critical {
            return "Expires in 1 day"
        }
        return days == 1 ? "Expires in 1 day" : "Expires in \(days) days"
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color(hex: 0xA3B1C6, opacity: 0.2), lineWidth: 5)
                        .frame(width: 48, height: 48)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            progressColor,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 48, height: 48)

                    Text(food.emoji)
                        .font(.system(size: 24))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(food.localizedName(for: language))
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(theme.primaryText)

                    if food.freshnessState == .critical {
                        HStack(spacing: 4) {
                            Text("⚠️")
                                .font(.system(size: 14))
                            Text(daysLabel)
                                .font(.system(size: 14, weight: .heavy))
                        }
                        .foregroundStyle(progressColor)
                    } else {
                        Text(daysLabel)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(progressColor)
                    }
                }

                Spacer()

                // Reserve trailing space so delete control never overlaps labels.
                Color.clear
                    .frame(width: 28, height: 1)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if food.freshnessState == .critical {
                    Text(food.expiryStage == .expired ? "REMOVE NOW" : "USE TODAY")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            LinearGradient(
                                colors: food.expiryStage == .expired
                                ? [Color(hex: 0xD32F2F), Color(hex: 0xF44336)]
                                : [Color(hex: 0xFF6B6B), Color(hex: 0xFF8787)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(.trailing, 12)
                        .offset(y: -5)
                }
            }
            .shadow(color: theme.shadowDark, radius: 12, x: 10, y: 10)
            .shadow(color: theme.shadowLight, radius: 12, x: -10, y: -10)
            .offset(x: shakeOffset)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .onTapGesture {
                if suppressNextCardTap {
                    suppressNextCardTap = false
                    return
                }
                HapticsService.tap()
                onTap()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("\(food.emoji) \(food.localizedName(for: language))")
            .accessibilityValue(daysLabel)
            .accessibilityHint("Double tap to view item details")

            Button(role: .destructive) {
                suppressNextCardTap = true
                onDelete()
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: 0xFF6B6B))
                    .frame(width: 30, height: 30)
                    .background(theme.backgroundBottom)
                    .clipShape(Circle())
                    .shadow(color: theme.shadowDarkSoft, radius: 2, x: 1, y: 1)
                    .shadow(color: theme.shadowLightSoft, radius: 2, x: -1, y: -1)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 14)
            .accessibilityLabel("Delete \(food.localizedName(for: language))")
            .accessibilityHint("Double tap to remove this item from your fridge list")
        }
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Item", systemImage: "trash")
            }
        }
        .onAppear {
            startUrgentShakeIfNeeded()
        }
        .onDisappear {
            stopUrgentShake()
        }
        .onChange(of: food.freshnessState) {
            startUrgentShakeIfNeeded()
        }
    }

    private func startUrgentShakeIfNeeded() {
        stopUrgentShake()
        guard food.freshnessState == .critical else { return }

        shakeTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_900_000_000)
                guard !Task.isCancelled else { break }

                withAnimation(.easeInOut(duration: 0.04)) { shakeOffset = -3 }
                try? await Task.sleep(nanoseconds: 40_000_000)

                withAnimation(.easeInOut(duration: 0.04)) { shakeOffset = 3 }
                try? await Task.sleep(nanoseconds: 40_000_000)

                withAnimation(.easeInOut(duration: 0.04)) { shakeOffset = -3 }
                try? await Task.sleep(nanoseconds: 40_000_000)

                withAnimation(.easeInOut(duration: 0.04)) { shakeOffset = 0 }
            }
        }
    }

    private func stopUrgentShake() {
        shakeTask?.cancel()
        shakeTask = nil
        shakeOffset = 0
    }
}

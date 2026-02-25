import SwiftUI

struct AlertsPrototypeView: View {
    @ObservedObject var viewModel: EcoChefViewModel
    let theme: EcoTheme

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Alerts")
                            .font(.system(size: 36, weight: .black))
                            .foregroundStyle(theme.accentGradient)
                        Spacer()
                    }
                    .padding(.bottom, 2)

                    ForEach(alertRows) { row in
                        alertCard(row)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 46)
                .padding(.bottom, 122)
            }
        }
    }

    private var alertRows: [AlertRow] {
        var rows: [AlertRow] = viewModel.alertItems.prefix(3).map { item in
            let days = max(item.daysLeft, 1)
            let stage = item.expiryStage
            let isCritical = stage == .oneDay || stage == .expired
            let title = viewModel.localized(
                hinglish: "\(item.localizedName(for: viewModel.selectedLanguage)) needs you \(item.emoji)",
                english: "\(item.localizedName(for: viewModel.selectedLanguage)) needs you \(item.emoji)",
                spanish: "\(item.localizedName(for: viewModel.selectedLanguage)) te necesita \(item.emoji)"
            )
            let time: String
            let body: String
            switch stage {
            case .expired:
                time = viewModel.localized(hinglish: "Expired", english: "Expired", spanish: "Caducado")
                body = viewModel.localized(
                    hinglish: "Remove or use this item now to keep your fridge data clean.",
                    english: "Remove or use this item now to keep your fridge data clean.",
                    spanish: "Elimina o usa este item ahora para mantener tus datos limpios."
                )
            case .oneDay:
                time = viewModel.localized(hinglish: "Today", english: "Today", spanish: "Hoy")
                body = viewModel.localized(
                    hinglish: "Use it now to avoid waste. Recipe suggestions are ready.",
                    english: "Use it now to avoid waste. Recipe suggestions are ready.",
                    spanish: "Úsalo ahora para evitar desperdicio. Las recetas ya están listas."
                )
            case .threeDays:
                time = viewModel.localized(
                    hinglish: "\(days) day(s) left",
                    english: "\(days) day(s) left",
                    spanish: "\(days) día(s) restantes"
                )
                body = viewModel.localized(
                    hinglish: "Plan this ingredient in your next meal and keep your score high.",
                    english: "Plan this ingredient in your next meal and keep your score high.",
                    spanish: "Inclúyelo en tu próxima comida para mantener tu puntaje alto."
                )
            case .fresh:
                time = viewModel.localized(hinglish: "Fresh", english: "Fresh", spanish: "Fresco")
                body = viewModel.localized(
                    hinglish: "Item looks fresh and healthy.",
                    english: "Item looks fresh and healthy.",
                    spanish: "El item se ve fresco."
                )
            }
            return AlertRow(
                icon: stage == .expired ? "⛔️" : (isCritical ? "⚠️" : "🥬"),
                title: title,
                time: time,
                body: body,
                stripe: stage == .expired
                ? Color(hex: 0xE53935)
                : (isCritical ? Color(hex: 0xF44336) : Color(hex: 0xFF9800))
            )
        }

        rows.append(
            AlertRow(
                icon: "🎉",
                title: viewModel.localized(
                    hinglish: "Eco-score update",
                    english: "Eco-score update",
                    spanish: "Actualización de eco-score"
                ),
                time: viewModel.localized(
                    hinglish: "This week",
                    english: "This week",
                    spanish: "Esta semana"
                ),
                body: viewModel.localized(
                    hinglish: "Current score is \(viewModel.ecoScorePercent)% with \(viewModel.mealsFromRescuedFood) meals saved.",
                    english: "Current score is \(viewModel.ecoScorePercent)% with \(viewModel.mealsFromRescuedFood) meals saved.",
                    spanish: "Tu score actual es \(viewModel.ecoScorePercent)% con \(viewModel.mealsFromRescuedFood) comidas salvadas."
                ),
                stripe: Color(hex: 0x2196F3)
            )
        )

        if rows.isEmpty {
            rows = [
                AlertRow(
                    icon: "✅",
                    title: viewModel.localized(
                        hinglish: "No urgent alerts",
                        english: "No urgent alerts",
                        spanish: "Sin alertas urgentes"
                    ),
                    time: viewModel.localized(
                        hinglish: "All good",
                        english: "All good",
                        spanish: "Todo bien"
                    ),
                    body: viewModel.localized(
                        hinglish: "Your fridge looks healthy. Keep adding items to track freshness.",
                        english: "Your fridge looks healthy. Keep adding items to track freshness.",
                        spanish: "Tu refrigerador está en buen estado. Sigue agregando items para monitorear frescura."
                    ),
                    stripe: Color(hex: 0x66BB6A)
                )
            ]
        }

        return rows
    }

    private func alertCard(_ row: AlertRow) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text(row.icon)
                    .font(.system(size: 22))
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(theme.primaryText)
                    Text(row.time)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.tertiaryText)
                }
                Spacer()
            }

            Text(row.body)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(row.stripe)
                .frame(width: 4)
        }
        .shadow(color: theme.shadowDarkSoft, radius: 4, x: 4, y: 4)
        .shadow(color: theme.shadowLightSoft, radius: 4, x: -4, y: -4)
    }
}

private struct AlertRow: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let time: String
    let body: String
    let stripe: Color
}

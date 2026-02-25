import SwiftUI

struct QuickLogSheetView: View {
    @ObservedObject var viewModel: EcoChefViewModel
    let theme: EcoTheme
    let onBack: () -> Void

    @State private var searchText = ""
    @State private var showManualSheet = false
    @State private var showBarcodeScanner = false
    @State private var barcodeFeedback = ""
    @State private var showBarcodeFeedback = false

    @State private var whooshEmoji = ""
    @State private var whooshVisible = false
    @State private var whooshOffset: CGSize = .zero
    @State private var whooshScale: CGFloat = 1
    @State private var whooshOpacity: Double = 1

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    private var filteredItems: [QuickAddItem] {
        guard !searchText.isEmpty else { return viewModel.quickAddItems }
        return viewModel.quickAddItems.filter {
            $0.localizedName(for: viewModel.selectedLanguage)
                .localizedCaseInsensitiveContains(searchText)
        }
    }

    private var recentCardGradient: LinearGradient {
        LinearGradient(
            colors: theme.isDark
            ? [Color(hex: 0x1F3A2B), Color(hex: 0x1B3226)]
            : [Color(hex: 0xD4F4DD), Color(hex: 0xC8F0D3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var recentTextColor: Color {
        theme.isDark ? Color(hex: 0x8DDE9F) : Color(hex: 0x2E7D32)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    TextField("🔍 Search items...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                        .padding(.horizontal, 20)
                        .frame(height: 56)
                        .ecoInsetStyle(theme: theme, cornerRadius: 16)

                    Button {
                        HapticsService.tap()
                        showBarcodeScanner = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 16, weight: .bold))
                            Text("Scan Barcode")
                                .font(.subheadline.weight(.bold))
                            Spacer()
                        }
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 16)
                        .frame(height: 50)
                        .ecoCardStyle(theme: theme, cornerRadius: 14)
                    }
                    .buttonStyle(.plain)

                    if showBarcodeFeedback {
                        Text(barcodeFeedback)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(theme.secondaryText)
                            .transition(.opacity)
                    }

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(filteredItems) { item in
                            quickGridItem(item)
                        }
                    }

                    if !viewModel.recentLogs.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(
                                viewModel.localized(
                                    hinglish: "Recently Added",
                                    english: "Recently Added",
                                    spanish: "Agregado recientemente"
                                )
                            )
                            .font(.caption.weight(.bold))
                            .foregroundStyle(recentTextColor)

                            ForEach(viewModel.recentLogs, id: \.self) { log in
                                Text(log)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(recentTextColor)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(recentCardGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: theme.shadowDarkSoft, radius: 8, x: 4, y: 4)
                        .shadow(color: theme.shadowLightSoft, radius: 8, x: -4, y: -4)
                    }

                    Button {
                        showManualSheet = true
                    } label: {
                        Text(
                            viewModel.localized(
                                hinglish: "Or add custom item manually",
                                english: "Or add custom item manually",
                                spanish: "O agrega un item manualmente"
                            )
                        )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 10)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 122)
            }

            if whooshVisible {
                Text(whooshEmoji)
                    .font(.system(size: 40))
                    .offset(whooshOffset)
                    .scaleEffect(whooshScale)
                    .opacity(whooshOpacity)
                    .allowsHitTesting(false)
            }
        }
        .sheet(isPresented: $showManualSheet) {
            ManualEntrySheet(viewModel: viewModel)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showBarcodeScanner) {
            BarcodeScannerSheetView(theme: theme) { scannedCode in
                let result = viewModel.addItemFromBarcode(scannedCode)
                barcodeFeedback = result.message
                withAnimation(.easeInOut(duration: 0.2)) {
                    showBarcodeFeedback = true
                }
                if let emoji = result.item?.emoji {
                    playWhoosh(emoji: emoji)
                }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 2_400_000_000)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showBarcodeFeedback = false
                    }
                }
            }
            .presentationDetents([.large])
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

            Text("Add Items")
                .font(.headline.weight(.heavy))
                .foregroundStyle(theme.primaryText)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 46)
    }

    private func quickGridItem(_ item: QuickAddItem) -> some View {
        Button {
            viewModel.addQuickItem(item)
            playWhoosh(emoji: item.emoji)
        } label: {
            VStack(spacing: 6) {
                Text(item.emoji)
                    .font(.system(size: 42))
                Text(item.localizedName(for: viewModel.selectedLanguage))
                    .font(.caption.weight(.bold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.accent)
            }
            .frame(maxWidth: .infinity, minHeight: 108)
            .padding(.horizontal, 6)
            .ecoCardStyle(theme: theme, cornerRadius: 20)
        }
        .buttonStyle(.plain)
    }

    private func playWhoosh(emoji: String) {
        whooshEmoji = emoji
        whooshVisible = true
        whooshOffset = .zero
        whooshScale = 1
        whooshOpacity = 1

        withAnimation(.easeOut(duration: 0.75)) {
            whooshOffset = CGSize(width: 130, height: -320)
            whooshScale = 0.12
            whooshOpacity = 0
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 760_000_000)
            whooshVisible = false
            whooshOffset = .zero
            whooshScale = 1
            whooshOpacity = 1
        }
    }
}

private struct ManualEntrySheet: View {
    @ObservedObject var viewModel: EcoChefViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var quantity = 1
    @State private var days = 7

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name", text: $name)
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...20)
                    Stepper("Freshness days: \(days)", value: $days, in: 1...30)
                }
            }
            .navigationTitle("Custom Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        viewModel.addManualItem(name: name, quantity: quantity, shelfLifeDays: days)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

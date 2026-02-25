import SwiftUI

struct SettingsPrototypeView: View {
    @ObservedObject var viewModel: EcoChefViewModel
    let theme: EcoTheme
    let onBack: () -> Void
    let onOpenAbout: () -> Void

    @State private var showExpiredCleanupConfirm = false
    @State private var showDemoResetConfirm = false
    @State private var actionStatusMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            modalHeader(title: "Settings", onBack: onBack)

            VStack(spacing: 0) {
                row {
                    Text("Notifications")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                } trailing: {
                    prototypeToggle(isOn: viewModel.notificationsEnabled, greenOn: true)
                }
                .onTapGesture {
                    HapticsService.tap()
                    viewModel.notificationsEnabled.toggle()
                }
                .overlay(alignment: .bottom) { divider }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Notifications")
                .accessibilityValue(viewModel.notificationsEnabled ? "On" : "Off")
                .accessibilityHint("Double tap to toggle notifications")

                row {
                    Text("Dark Mode")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                } trailing: {
                    prototypeToggle(isOn: viewModel.prefersDarkMode, greenOn: false)
                }
                .onTapGesture {
                    HapticsService.tap()
                    viewModel.prefersDarkMode.toggle()
                }
                .overlay(alignment: .bottom) { divider }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Dark Mode")
                .accessibilityValue(viewModel.prefersDarkMode ? "On" : "Off")
                .accessibilityHint("Double tap to toggle dark mode")

                row {
                    Text("Remove Expired Items")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(viewModel.expiredItems.isEmpty ? theme.primaryText : Color(hex: 0xE53935))
                } trailing: {
                    Text("\(viewModel.expiredItems.count)")
                        .font(.body.weight(.bold))
                        .foregroundStyle(viewModel.expiredItems.isEmpty ? theme.secondaryText : Color(hex: 0xE53935))
                }
                .onTapGesture {
                    HapticsService.tap()
                    showExpiredCleanupConfirm = true
                }
                .overlay(alignment: .bottom) { divider }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Remove expired items")
                .accessibilityValue("\(viewModel.expiredItems.count) items")
                .accessibilityHint("Double tap to remove all expired ingredients")

                row {
                    Text("Reset Demo Data")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color(hex: 0xE65100))
                } trailing: {
                    Text("↺")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color(hex: 0xE65100))
                }
                .onTapGesture {
                    HapticsService.tap()
                    showDemoResetConfirm = true
                }
                .overlay(alignment: .bottom) { divider }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Reset demo data")
                .accessibilityHint("Double tap to restore the default challenge demo state")

                row {
                    Text("About")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                } trailing: {
                    Text("→")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                }
                .onTapGesture {
                    HapticsService.tap()
                    onOpenAbout()
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("About")
                .accessibilityHint("Double tap to open about screen")
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            if let actionStatusMessage {
                Text(actionStatusMessage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .ecoCardStyle(theme: theme, cornerRadius: 12)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            Spacer()
        }
        .alert(
            "Remove all expired items?",
            isPresented: $showExpiredCleanupConfirm
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                let removedCount = viewModel.removeAllExpiredItems()
                let status = viewModel.localized(
                    hinglish: removedCount == 0
                    ? "No expired items found."
                    : "Removed \(removedCount) expired item(s).",
                    english: removedCount == 0
                    ? "No expired items found."
                    : "Removed \(removedCount) expired item(s).",
                    spanish: removedCount == 0
                    ? "No se encontraron items caducados."
                    : "Se eliminaron \(removedCount) item(s) caducados."
                )
                showActionStatus(status)
            }
        } message: {
            Text("This clears expired ingredients from your fridge list in one tap.")
        }
        .alert(
            "Reset demo data?",
            isPresented: $showDemoResetConfirm
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                viewModel.resetDemoData()
                showActionStatus(
                    viewModel.localized(
                        hinglish: "Demo data reset ho gaya.",
                        english: "Demo data has been reset.",
                        spanish: "Se restablecieron los datos de demostración."
                    )
                )
            }
        } message: {
            Text("This restores default sample items and impact stats.")
        }
        .animation(.easeInOut(duration: 0.2), value: actionStatusMessage)
    }

    private var divider: some View {
        Rectangle()
            .fill(theme.borderColor)
            .frame(height: 1)
    }

    private func modalHeader(title: String, onBack: @escaping () -> Void) -> some View {
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
            .accessibilityLabel("Back")
            .accessibilityHint("Double tap to return")

            Spacer()

            Text(title)
                .font(.headline.weight(.heavy))
                .foregroundStyle(theme.primaryText)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 46)
    }

    private func row<Leading: View, Trailing: View>(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack {
            leading()
            Spacer()
            trailing()
        }
        .padding(.horizontal, 0)
        .frame(height: 44)
        .contentShape(Rectangle())
    }

    private func showActionStatus(_ message: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            actionStatusMessage = message
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard actionStatusMessage == message else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                actionStatusMessage = nil
            }
        }
    }

    @ViewBuilder
    private func prototypeToggle(isOn: Bool, greenOn: Bool) -> some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    greenOn && isOn
                    ? AnyShapeStyle(Color(hex: 0x66BB6A))
                    : AnyShapeStyle(theme.isDark ? Color(hex: 0x2A3045) : Color(hex: 0xD7DCE8))
                )
                .frame(width: 36, height: 22)

            Circle()
                .fill(theme.isDark ? Color(hex: 0xDCE3FF) : Color.white)
                .frame(width: 18, height: 18)
                .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
                .padding(.horizontal, 2)
        }
        .animation(.easeInOut(duration: 0.2), value: isOn)
    }
}

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = EcoChefViewModel()

    var body: some View {
        EcoChefRootView(viewModel: viewModel)
            .preferredColorScheme(viewModel.prefersDarkMode ? .dark : .light)
            .environment(\.locale, Locale(identifier: viewModel.selectedLanguage.localeIdentifier))
            .dynamicTypeSize(.xSmall ... .accessibility3)
            .animation(.easeInOut(duration: 0.25), value: viewModel.prefersDarkMode)
            .animation(.easeInOut(duration: 0.2), value: viewModel.selectedLanguage)
            .onReceive(NotificationCenter.default.publisher(for: .ecoChefAppDidBecomeActive)) { _ in
                viewModel.refreshExpiryMonitoring()
            }
    }
}


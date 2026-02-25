import SwiftUI

struct EcoChefRootView: View {
    @ObservedObject var viewModel: EcoChefViewModel

    private static let onboardingCompletedKey = "ecochef.onboardingCompleted"

    @State private var onboarding: OnboardingStep
    @State private var modalScreen: ModalScreen?
    @State private var alertPayload: AlertPayload?
    @State private var confettiBurst: [ConfettiParticle] = []

    init(viewModel: EcoChefViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Self.onboardingCompletedKey)
        _onboarding = State(initialValue: hasCompletedOnboarding ? .completed : .splash)
    }

    private var theme: EcoTheme {
        EcoTheme(isDark: viewModel.prefersDarkMode)
    }

    var body: some View {
        ZStack {
            theme.screenGradient
                .ignoresSafeArea()

            if onboarding.isActive {
                onboardingView
                    .transition(.opacity)
            } else {
                ZStack(alignment: .bottom) {
                    currentScreenContent
                        .transition(.opacity)

                    EcoBottomNavigation(
                        selection: modalScreen == nil ? viewModel.currentScreen : nil,
                        theme: theme
                    ) { screen in
                        modalScreen = nil
                        withAnimation(.easeInOut(duration: 0.22)) {
                            viewModel.currentScreen = screen
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                }
                .overlay {
                    ZStack {
                        if !confettiBurst.isEmpty {
                            ConfettiBurstView(particles: confettiBurst)
                                .ignoresSafeArea()
                                .transition(.opacity)
                        }

                        if viewModel.showCookedSuccess {
                            cookedSuccessOverlay
                                .transition(.scale(scale: 0.85).combined(with: .opacity))
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: onboarding)
        .animation(.easeInOut(duration: 0.25), value: modalScreen)
        .animation(.easeInOut(duration: 0.25), value: viewModel.currentScreen)
        .alert(item: $alertPayload) { payload in
            Alert(
                title: Text(payload.title),
                message: Text(payload.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .ecoChefOpenDishExplorer)) { _ in
            completeOnboardingIfNeeded()
            modalScreen = nil
            withAnimation(.easeInOut(duration: 0.25)) {
                viewModel.currentScreen = .dishExplorer
            }
        }
        .onChange(of: viewModel.showCookedSuccess) {
            if viewModel.showCookedSuccess {
                launchConfetti()
            }
        }
    }

    @ViewBuilder
    private var onboardingView: some View {
        switch onboarding {
        case .splash:
            SplashPrototypeView(theme: theme) {
                onboarding = .first
            }
        case .first:
            OnboardingPrototypeView(
                theme: theme,
                emoji: "📱",
                title: "Track Your Groceries",
                description: "Quick-log your groceries in 3 seconds. No typing, just tap and go!",
                index: 0,
                buttonTitle: "Next"
            ) {
                onboarding = .second
            }
        case .second:
            OnboardingPrototypeView(
                theme: theme,
                emoji: "⏰",
                title: "Never Waste Again",
                description: "Get smart alerts when food is about to expire. Save money and the planet!",
                index: 1,
                buttonTitle: "Next"
            ) {
                onboarding = .third
            }
        case .third:
            OnboardingPrototypeView(
                theme: theme,
                emoji: "🍳",
                title: "Cook Smart",
                description: "Get personalized recipe suggestions based on what's expiring soon!",
                index: 2,
                buttonTitle: "Let's Go!"
            ) {
                completeOnboardingIfNeeded()
            }
        case .completed:
            EmptyView()
        }
    }

    @ViewBuilder
    private var currentScreenContent: some View {
        if let modalScreen {
            switch modalScreen {
            case .quickLog:
                QuickLogSheetView(viewModel: viewModel, theme: theme) {
                    self.modalScreen = nil
                }
            case .settings:
                SettingsPrototypeView(
                    viewModel: viewModel,
                    theme: theme,
                    onBack: { self.modalScreen = nil },
                    onOpenAbout: { self.modalScreen = .about }
                )
            case .about:
                AboutPrototypeView(viewModel: viewModel, theme: theme) {
                    self.modalScreen = .settings
                }
            }
        } else {
            switch viewModel.currentScreen {
            case .home:
                HomeDashboardView(
                    viewModel: viewModel,
                    theme: theme,
                    onOpenQuickAdd: {
                        self.modalScreen = .quickLog
                    },
                    onOpenSettings: {
                        self.modalScreen = .settings
                    },
                    onHeroTap: {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            viewModel.currentScreen = .dishExplorer
                        }
                    },
                    onFoodTap: { food in
                        let name = food.localizedName(for: viewModel.selectedLanguage)
                        let text: String
                        if food.expiryStage == .expired {
                            text = viewModel.localized(
                                hinglish: "\(name) expire ho chuka hai. Isko fridge list se remove karo ya discard karo.",
                                english: "\(name) has already expired. Remove it from your fridge list or discard it.",
                                spanish: "\(name) ya caducó. Elimínalo de tu lista o deséchalo."
                            )
                        } else {
                            text = viewModel.localized(
                                hinglish: "\(name) expires in \(max(food.daysLeft, 1)) day(s). Try a recipe now to avoid waste.",
                                english: "\(name) expires in \(max(food.daysLeft, 1)) day(s). Try a recipe now to avoid waste.",
                                spanish: "\(name) caduca en \(max(food.daysLeft, 1)) día(s). Prueba una receta ahora."
                            )
                        }
                        alertPayload = AlertPayload(title: name, message: text)
                    },
                    onFoodDelete: { food in
                        viewModel.deleteFood(food)
                    }
                )
            case .dishExplorer:
                DishExplorerView(
                    viewModel: viewModel,
                    theme: theme,
                    onBack: {
                        viewModel.currentScreen = .home
                    }
                ) { recipe in
                    let have = recipe.availableIngredients.joined(separator: ", ")
                    let need = recipe.missingIngredients.joined(separator: ", ")
                    let message = viewModel.localized(
                        hinglish: "Cook time: \(recipe.cookMinutes) min\nYou have: \(have)\nNeed: \(need)",
                        english: "Cook time: \(recipe.cookMinutes) min\nYou have: \(have)\nNeed: \(need)",
                        spanish: "Tiempo: \(recipe.cookMinutes) min\nTienes: \(have)\nFalta: \(need)"
                    )
                    alertPayload = AlertPayload(
                        title: viewModel.recipeTitle(recipe),
                        message: message
                    )
                }
            case .impactSettings:
                ImpactSettingsView(viewModel: viewModel, theme: theme)
            case .alerts:
                AlertsPrototypeView(viewModel: viewModel, theme: theme)
            }
        }
    }

    private var cookedSuccessOverlay: some View {
        CookedSuccessCardView(
            theme: theme,
            title: viewModel.localized(
                hinglish: "You saved food!",
                english: "You saved food!",
                spanish: "¡Salvaste comida!"
            ),
            scoreDelta: viewModel.lastEcoScoreDelta
        )
    }

    private func launchConfetti() {
        let colors: [Color] = [
            Color(hex: 0xFF6B6B),
            Color(hex: 0x4ECDC4),
            Color(hex: 0x45B7D1),
            Color(hex: 0xF9CA24),
            Color(hex: 0x6C5CE7),
            Color(hex: 0xA29BFE)
        ]

        confettiBurst = (0..<50).map { _ in
            ConfettiParticle(
                color: colors.randomElement() ?? Color(hex: 0x6C5CE7),
                xPosition: CGFloat.random(in: 0...1),
                size: CGFloat.random(in: 7...11),
                rotation: Double.random(in: 300...760),
                duration: Double.random(in: 2...4),
                delay: Double.random(in: 0...0.5)
            )
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_300_000_000)
            confettiBurst = []
        }
    }

    private func completeOnboardingIfNeeded() {
        onboarding = .completed
        UserDefaults.standard.set(true, forKey: Self.onboardingCompletedKey)
    }
}

private enum OnboardingStep {
    case splash
    case first
    case second
    case third
    case completed

    var isActive: Bool {
        self != .completed
    }
}

private enum ModalScreen {
    case quickLog
    case settings
    case about
}

private struct SplashPrototypeView: View {
    let theme: EcoTheme
    let onStart: () -> Void

    @State private var float = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("🥬")
                .font(.system(size: 96))
                .frame(width: 160, height: 160)
                .ecoCardStyle(theme: theme, cornerRadius: 40)
                .offset(y: float ? -10 : 10)

            Text("EcoChef")
                .font(.system(size: 52, weight: .black))
                .foregroundStyle(theme.accentGradient)
                .kerning(-1.5)
                .padding(.top, 38)

            Text("Your Smart Kitchen\nCompanion")
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            Button {
                HapticsService.tap()
                onStart()
            } label: {
                Text("Get Started")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(theme.accent)
                    .padding(.vertical, 20)
                    .padding(.horizontal, 60)
                    .ecoCardStyle(theme: theme, cornerRadius: 20)
            }
            .buttonStyle(.plain)
            .padding(.top, 58)

            Spacer()
        }
        .padding(.horizontal, 30)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                float.toggle()
            }
        }
    }
}

private struct OnboardingPrototypeView: View {
    let theme: EcoTheme
    let emoji: String
    let title: String
    let description: String
    let index: Int
    let buttonTitle: String
    let onNext: () -> Void

    var body: some View {
        VStack {
            Spacer(minLength: 28)

            Text(emoji)
                .font(.system(size: 128))
                .frame(width: 280, height: 280)
                .ecoCardStyle(theme: theme, cornerRadius: 140)
                .padding(.bottom, 34)

            Text(title)
                .font(.system(size: 32, weight: .heavy))
                .foregroundStyle(theme.primaryText)

            Text(description)
                .font(.body.weight(.medium))
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 8)
                .padding(.horizontal, 16)

            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { dot in
                    Circle()
                        .fill(dot == index ? AnyShapeStyle(theme.accentGradient) : AnyShapeStyle(theme.backgroundBottom))
                        .frame(width: 10, height: 10)
                        .shadow(color: theme.shadowDarkSoft, radius: 2, x: 1, y: 1)
                        .shadow(color: theme.shadowLightSoft, radius: 2, x: -1, y: -1)
                }
            }
            .padding(.top, 34)

            Spacer()

            Button {
                HapticsService.tap()
                onNext()
            } label: {
                Text(buttonTitle)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(theme.accent)
                    .padding(.vertical, 18)
                    .padding(.horizontal, 50)
                    .ecoCardStyle(theme: theme, cornerRadius: 16)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 60)
        }
        .padding(.horizontal, 30)
    }
}

private struct CookedSuccessCardView: View {
    let theme: EcoTheme
    let title: String
    let scoreDelta: Int

    @State private var iconLift = false
    @State private var showIncrement = false

    var body: some View {
        VStack(spacing: 8) {
            Text("🎉")
                .font(.system(size: 60))
                .offset(y: iconLift ? -10 : 0)

            Text(title)
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(Color(hex: 0x66BB6A))

            HStack(spacing: 2) {
                Text("Eco-Score")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                Text("+\(max(scoreDelta, 0))%")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Color(hex: 0x66BB6A))
                    .offset(y: showIncrement ? 0 : 18)
                    .opacity(showIncrement ? 1 : 0)
            }
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 36)
        .ecoCardStyle(theme: theme, cornerRadius: 24)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                iconLift = true
            }
            withAnimation(.easeOut(duration: 0.45).delay(0.12)) {
                showIncrement = true
            }
        }
    }
}

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let xPosition: CGFloat
    let size: CGFloat
    let rotation: Double
    let duration: Double
    let delay: Double
}

private struct ConfettiBurstView: View {
    let particles: [ConfettiParticle]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    ConfettiPieceView(particle: particle, size: geo.size)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ConfettiPieceView: View {
    let particle: ConfettiParticle
    let size: CGSize

    @State private var fall = false

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(particle.color)
            .frame(width: particle.size, height: particle.size)
            .rotationEffect(.degrees(fall ? particle.rotation : 0))
            .position(
                x: size.width * particle.xPosition,
                y: fall ? size.height + 40 : -30
            )
            .onAppear {
                withAnimation(.linear(duration: particle.duration).delay(particle.delay)) {
                    fall = true
                }
            }
    }
}

private struct AlertPayload: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

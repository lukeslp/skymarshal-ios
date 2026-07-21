import SwiftUI
import SkymarshalCore

@available(iOS 17, *)
struct RootView: View {
    @State private var model = AppModel.liveDefault()
    /// Figma Make ships Scope as a first-class tab — default on.
    @AppStorage(FeatureFlags.visualizationHubKey) private var featureVisualizationHub: Bool = true
    @AppStorage(FeatureFlags.webShellKey) private var featureWebShell: Bool = false
    @AppStorage("sm.onboarding.completed") private var onboardingCompleted = false
    @State private var showPostUpdateFeatureDiscovery = false
    @State private var coldStartReady = false
    @State private var forcedOnboardingDismissed = false

    var body: some View {
        Group {
            // Show the tab UI whenever we have data to show — either
            // from a live session OR from the cached cold-start
            // hydration. Sign-in stays the gate for any mutation,
            // but read-only browsing of cached data works while
            // signed out (the LastScannedBanner explains).
            if !coldStartReady {
                ZStack {
                    Theme.void.ignoresSafeArea()
                    ProgressView()
                        .tint(Theme.cinematicAccentA)
                        .accessibilityLabel("Opening Skymarshal")
                }
            } else if model.isAuthenticated || !model.accounts.isEmpty || !model.items.isEmpty {
                TabView {
                    ContentListView()
                        .tabItem { Label("Content", systemImage: "tray.full") }
                    BluescreenView()
                        .tabItem { Label("Patterns", systemImage: "person.2") }
                    if featureVisualizationHub {
                        VisualizationHubView()
                            .tabItem { Label("Scope", systemImage: "scope") }
                    }
                    AboutView(presentation: .tab)
                        .tabItem { Label("About", systemImage: "info.circle") }
                    if featureWebShell {
                        WebShellView()
                            .tabItem { Label("Web", systemImage: "globe") }
                    }
                }
                .tint(Theme.cinematicAccentA)
            } else if shouldShowOnboarding {
                OnboardingView {
                    onboardingCompleted = true
                    forcedOnboardingDismissed = true
                }
            } else {
                LoginView()
            }
        }
        .environment(model)
        .guidedModeEnvironment()
        .sheet(isPresented: $showPostUpdateFeatureDiscovery) {
            AboutView(presentation: .sheet)
                .onDisappear {
                    guard !ProcessInfo.processInfo.arguments.contains("-uitestForceFeatureDiscovery") else { return }
                    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
                    UserDefaults.standard.set(version, forKey: "sm.featureDiscoveryPresentedForVersion")
                }
        }
        .task {
            await ColdLaunchSignposts.runAsyncInterval("root_cold_start_task") {
                // Cold-start cache read. Idempotent — does nothing if
                // already hydrated this session, or if cache is empty.
                await model.hydrateFromCache()
                // Resume the keychain-persisted session before any UI
                // settles. Keeps the user out of the LoginView when the
                // refresh JWT is still valid (it lasts ~3 months) — the
                // root cause of the "logged out after a while" report.
                await model.tryRestoreSession()
                await model.seedUITestMinimalContentIfNeeded()
                coldStartReady = true
                presentFeatureLabDiscoveryIfNeeded()
                model.startMostRecentContentRefresh()
                BackgroundTaskCoordinator.scheduleProcessingPass()
                BackgroundTaskCoordinator.scheduleAppRefreshPass()
            }
        }
    }

    private var skipOnboardingForUITests: Bool {
        ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("-uitest") }
            || ProcessInfo.processInfo.environment["UITEST_RESET_FEATURE_DEFAULTS"] == "1"
    }

    private var shouldShowOnboarding: Bool {
        if ProcessInfo.processInfo.environment["UITEST_FORCE_ONBOARDING"] == "1" {
            return !forcedOnboardingDismissed
        }
        return !onboardingCompleted && !skipOnboardingForUITests
    }

    private func presentFeatureLabDiscoveryIfNeeded() {
        if ProcessInfo.processInfo.arguments.contains("-uitestForceFeatureDiscovery") {
            showPostUpdateFeatureDiscovery = true
            return
        }
        guard !ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-uitest") }) else { return }
        guard model.isAuthenticated || !model.items.isEmpty || !model.accounts.isEmpty else { return }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let key = "sm.featureDiscoveryPresentedForVersion"
        if UserDefaults.standard.string(forKey: key) != version {
            showPostUpdateFeatureDiscovery = true
        }
    }
}

@available(iOS 17, *)
#Preview("Logged out") {
    RootView()
}

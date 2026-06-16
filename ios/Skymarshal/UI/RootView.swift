import SwiftUI
import SkymarshalCore

@available(iOS 17, *)
struct RootView: View {
    @State private var model = AppModel.liveDefault()
    @AppStorage(FeatureFlags.visualizationHubKey) private var featureVisualizationHub: Bool = false
    @AppStorage(FeatureFlags.webShellKey) private var featureWebShell: Bool = false
    @State private var showPostUpdateFeatureDiscovery = false

    var body: some View {
        Group {
            // Show the tab UI whenever we have data to show — either
            // from a live session OR from the cached cold-start
            // hydration. Sign-in stays the gate for any mutation,
            // but read-only browsing of cached data works while
            // signed out (the LastScannedBanner explains).
            if model.isAuthenticated || !model.accounts.isEmpty || !model.items.isEmpty {
                TabView {
                    ContentListView()
                        .tabItem { Label("Content", systemImage: "tray.full") }
                    BluescreenView()
                        .tabItem { Label("Followers", systemImage: "person.2") }
                    if featureVisualizationHub {
                        VisualizationHubView()
                            .tabItem { Label("Scope", systemImage: "scope") }
                    }
                    if featureWebShell {
                        WebShellView()
                            .tabItem { Label("Web", systemImage: "globe") }
                    }
                }
            } else {
                LoginView()
            }
        }
        .environment(model)
        .sheet(isPresented: $showPostUpdateFeatureDiscovery) {
            AboutView()
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
                presentFeatureLabDiscoveryIfNeeded()
                BackgroundTaskCoordinator.scheduleProcessingPass()
                BackgroundTaskCoordinator.scheduleAppRefreshPass()
            }
        }
    }

    private func presentFeatureLabDiscoveryIfNeeded() {
        if ProcessInfo.processInfo.arguments.contains("-uitestForceFeatureDiscovery") {
            showPostUpdateFeatureDiscovery = true
            return
        }
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

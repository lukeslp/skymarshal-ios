import SwiftUI
import SkymarshalCore

@available(iOS 17, *)
struct RootView: View {
    @State private var model = AppModel.liveDefault()
    @AppStorage(FeatureFlags.visualizationHubKey) private var featureVisualizationHub: Bool = true

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
                }
            } else {
                LoginView()
            }
        }
        .environment(model)
        .task {
            // Cold-start cache read. Idempotent — does nothing if
            // already hydrated this session, or if cache is empty.
            await model.hydrateFromCache()
        }
    }
}

@available(iOS 17, *)
#Preview("Logged out") {
    RootView()
}

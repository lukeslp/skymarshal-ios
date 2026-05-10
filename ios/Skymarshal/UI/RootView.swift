import SwiftUI
import SkymarshalCore

@available(iOS 17, *)
struct RootView: View {
    @State private var model = AppModel.liveDefault()

    var body: some View {
        Group {
            if model.isAuthenticated {
                TabView {
                    ContentListView()
                        .tabItem { Label("Content", systemImage: "tray.full") }
                    BluescreenView()
                        .tabItem { Label("Followers", systemImage: "person.2") }
                }
            } else {
                LoginView()
            }
        }
        .environment(model)
    }
}

@available(iOS 17, *)
#Preview("Logged out") {
    RootView()
}

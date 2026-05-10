import SwiftUI
import SkymarshalCore

@available(iOS 17, *)
struct RootView: View {
    @State private var model = AppModel.liveDefault()

    var body: some View {
        Group {
            if model.isAuthenticated {
                ContentListView()
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

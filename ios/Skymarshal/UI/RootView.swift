import SwiftUI
import SkymarshalCore

struct RootView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "scope")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.tint)
            Text("Skymarshal")
                .font(.largeTitle.weight(.semibold))
            Text("v\(SkymarshalCoreInfo.version) — content management for Bluesky")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
    }
}

#Preview {
    RootView()
}

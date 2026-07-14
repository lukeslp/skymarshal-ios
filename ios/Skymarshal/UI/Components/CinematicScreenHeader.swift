import SwiftUI
import SkymarshalCore

/// Large Make-style screen title with a compact Mono subtitle.
///
/// Inputs: title, subtitle, and optional trailing content.
/// Output: a Dynamic Type-safe header used above Content and Patterns chrome.
@available(iOS 17, *)
struct CinematicScreenHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: () -> Trailing

    init(
        title: String,
        subtitle: String,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                titleBlock
                Spacer(minLength: 8)
                trailing()
            }

            VStack(alignment: .leading, spacing: 10) {
                titleBlock
                trailing()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(Theme.Display.title(.title))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(Theme.Mono.kicker(10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

@available(iOS 17, *)
extension CinematicScreenHeader where Trailing == EmptyView {
    init(title: String, subtitle: String) {
        self.init(title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

import SwiftUI
import WebKit
import SkymarshalCore

/// SwiftUI shell that loads the live hosted site at https://skymarshal.blue inside a
/// hardened `WKWebView`. The native content-management tabs remain the primary surface;
/// this is an additive companion view (see App Review 4.2.6 — the app keeps real native
/// features and does not collapse to a thin web wrapper).
///
/// Hardening delegates are adapted from the shipped whatcolor/colorblindness shells
/// (`SNIPPETS/by-pattern/wkwebview-native-shell-delegates.md`):
/// external links → Safari, `target="_blank"` → Safari, content-process crash → reload.
@available(iOS 17, *)
struct WebShellView: View {
    /// Canonical live origin the shell is allowed to host in-app.
    static let liveURL = URL(string: "https://skymarshal.blue")!
    static let appBoundHost = "skymarshal.blue"

    var body: some View {
        SkymarshalHostedView(destination: .home)
    }
}

@available(iOS 17, *)
struct WebVisualizationView: View {
    var body: some View {
        SkymarshalHostedView(destination: .visualizations)
            .navigationTitle("Interactive Visuals")
            .navigationBarTitleDisplayMode(.inline)
    }
}

@available(iOS 17, *)
private enum SkymarshalWebDestination {
    case home
    case visualizations

    var url: URL {
        switch self {
        case .home:
            WebShellView.liveURL
        case .visualizations:
            URL(string: "https://skymarshal.blue/visualize")!
        }
    }

    var loadingMessage: String {
        switch self {
        case .home:
            "Loading skymarshal.blue…"
        case .visualizations:
            "Loading interactive visuals…"
        }
    }

    var offlineDescription: String {
        switch self {
        case .home:
            "Skymarshal on the web needs a connection. Your saved content is still available in the other tabs."
        case .visualizations:
            "Interactive visuals need a connection. Your on-device Scope visualizations are still available."
        }
    }
}

@available(iOS 17, *)
private struct SkymarshalHostedView: View {
    let destination: SkymarshalWebDestination

    @State private var isLoading = true
    @State private var loadFailedOffline = false
    /// Bumped to force a reload from the offline fallback's "Try again" button.
    @State private var reloadToken = 0

    var body: some View {
        ZStack {
            WebView(
                url: destination.url,
                reloadToken: reloadToken,
                isLoading: $isLoading,
                loadFailedOffline: $loadFailedOffline
            )
            .ignoresSafeArea(edges: .bottom)

            if loadFailedOffline {
                offlineFallback
            } else if isLoading {
                splash
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Link(destination: destination.url) {
                    Label("Open in Safari", systemImage: "safari")
                }
                .accessibilityHint("Opens the same Skymarshal page outside the app")
            }
        }
    }

    // MARK: - Native splash (shown until first didFinish)

    private var splash: some View {
        VStack(spacing: 16) {
            Image(systemName: "binoculars.fill")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.monochrome)
            ProgressView()
            Text(destination.loadingMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Offline fallback (no connection)

    private var offlineFallback: some View {
        ContentUnavailableView {
            Label("You're offline", systemImage: "wifi.slash")
        } description: {
            Text(destination.offlineDescription)
        } actions: {
            Button("Try again") {
                loadFailedOffline = false
                isLoading = true
                reloadToken += 1
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - UIViewRepresentable wrapper

@available(iOS 17, *)
private struct WebView: UIViewRepresentable {
    let url: URL
    let reloadToken: Int
    @Binding var isLoading: Bool
    @Binding var loadFailedOffline: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Info.plist declares WKAppBoundDomains (skymarshal.blue); with that key present
        // this flag must be true or WebKit silently degrades script/message behavior.
        // The two move together — see the whatcolor shell note.
        config.limitsNavigationsToAppBoundDomains = true
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        context.coordinator.webView = webView

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // A bump in reloadToken (from the offline "Try again" button) triggers a fresh load.
        if context.coordinator.lastReloadToken != reloadToken {
            context.coordinator.lastReloadToken = reloadToken
            webView.load(URLRequest(url: url))
        }
    }

    // MARK: Coordinator (WKNavigationDelegate + WKUIDelegate)

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private let parent: WebView
        weak var webView: WKWebView?
        var lastReloadToken: Int

        init(_ parent: WebView) {
            self.parent = parent
            self.lastReloadToken = parent.reloadToken
        }

        // Keep navigations on skymarshal.blue in-app; send external http/https to Safari.
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow); return
            }
            if url.scheme == "about" {
                decisionHandler(.allow); return
            }
            if url.scheme == "http" || url.scheme == "https" {
                if url.host == WebShellView.appBoundHost
                    || url.host?.hasSuffix(".\(WebShellView.appBoundHost)") == true {
                    decisionHandler(.allow)
                } else {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    decisionHandler(.cancel)
                }
                return
            }
            decisionHandler(.allow)
        }

        // target="_blank": WKWebView has no second-window context; open in Safari, return nil.
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url,
               url.scheme == "http" || url.scheme == "https" {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            return nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            setLoading(false)
            setOffline(false)
        }

        func webView(_ webView: WKWebView,
                     didFail navigation: WKNavigation!,
                     withError error: Error) {
            handleFailure(error)
        }

        func webView(_ webView: WKWebView,
                     didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            handleFailure(error)
        }

        // Content process crash recovery (the "dead rectangle" fix): reload the live URL.
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            setLoading(true)
            webView.load(URLRequest(url: parent.url))
        }

        private func handleFailure(_ error: Error) {
            setLoading(false)
            let nsError = error as NSError
            let offlineCodes: Set<Int> = [
                NSURLErrorNotConnectedToInternet,
                NSURLErrorTimedOut,
                NSURLErrorCannotConnectToHost,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorCannotFindHost,
                NSURLErrorDataNotAllowed,
            ]
            if nsError.domain == NSURLErrorDomain, offlineCodes.contains(nsError.code) {
                setOffline(true)
            }
        }

        private func setLoading(_ value: Bool) {
            DispatchQueue.main.async { self.parent.isLoading = value }
        }

        private func setOffline(_ value: Bool) {
            DispatchQueue.main.async { self.parent.loadFailedOffline = value }
        }
    }
}

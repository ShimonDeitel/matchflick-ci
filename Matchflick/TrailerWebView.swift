import SwiftUI
import WebKit

/// Embeds a YouTube search for the title's trailer directly in the app (no video-ID database
/// to curate the exact official trailer, so this opens search results rather than a single
/// auto-playing embed — tap the top result to play it inline).
struct TrailerWebView: UIViewRepresentable {
    let movie: Movie

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: movie.trailerSearchURL))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

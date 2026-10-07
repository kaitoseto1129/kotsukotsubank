//
//  ProductLinkFetcher.swift
//  コツコツバンク
//

import Foundation
import WebKit

struct ProductMetadata {
    var title: String?
    var imageData: Data?
    var price: Double?
}

enum ProductLinkFetcher {
    /// 商品ページのURLから、商品名・画像・価格を推測する。
    /// Amazonはボット対策のため単純な通信では取得できないので、WKWebView(実際にページを描画する仕組み)を使う。
    /// それ以外のサイトは、OGP(Open Graph)タグを手がかりにする軽量な方法を使う。
    static func fetch(urlString: String) async throws -> ProductMetadata {
        var normalized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.lowercased().hasPrefix("http") {
            normalized = "https://" + normalized
        }
        guard let url = URL(string: normalized) else {
            throw URLError(.badURL)
        }

        if let host = url.host?.lowercased(), host.contains("amazon.") || host == "a.co" {
            let resolvedURL = await Self.resolveFinalURL(url) ?? url
            return try await AmazonPageScraper().fetch(url: resolvedURL)
        }

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw URLError(.cannotDecodeContentData)
        }

        let title = metaContent(html: html, key: "og:title") ?? titleTag(html: html)

        var imageData: Data?
        if let imageURLString = metaContent(html: html, key: "og:image"), let imageURL = URL(string: imageURLString) {
            imageData = try? await URLSession.shared.data(from: imageURL).0
        }

        let price = priceValue(html: html)

        return ProductMetadata(title: title, imageData: imageData, price: price)
    }

    /// 「a.co」等の短縮リンクは、WKWebView内でリダイレクトの途中経過を
    /// 本来のページと誤認してしまうことがあるため、先に本来の商品ページURLへ解決しておく。
    private static func resolveFinalURL(_ url: URL) async -> URL? {
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.httpMethod = "HEAD"
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        guard let (_, response) = try? await URLSession.shared.data(for: request) else { return nil }
        return response.url
    }

    private static func metaContent(html: String, key: String) -> String? {
        let escapedKey = NSRegularExpression.escapedPattern(for: key)
        let patterns = [
            "<meta[^>]+(?:property|name)=[\"']\(escapedKey)[\"'][^>]+content=[\"']([^\"']*)[\"']",
            "<meta[^>]+content=[\"']([^\"']*)[\"'][^>]+(?:property|name)=[\"']\(escapedKey)[\"']"
        ]
        for pattern in patterns {
            if let value = firstMatch(pattern: pattern, in: html) {
                return decodeHTMLEntities(value)
            }
        }
        return nil
    }

    private static func titleTag(html: String) -> String? {
        guard let value = firstMatch(pattern: "<title>([^<]+)</title>", in: html) else { return nil }
        return decodeHTMLEntities(value)
    }

    private static func priceValue(html: String) -> Double? {
        if let raw = metaContent(html: html, key: "product:price:amount") ?? metaContent(html: html, key: "og:price:amount"),
           let value = Double(raw.filter { $0.isNumber || $0 == "." }) {
            return value
        }
        // 「¥12,345」「12,345円」のような表記をベストエフォートで拾う
        if let raw = firstMatch(pattern: "[¥￥]\\s?([0-9][0-9,]{2,})", in: html) ?? firstMatch(pattern: "([0-9][0-9,]{2,})\\s?円", in: html) {
            return Double(raw.replacingOccurrences(of: ",", with: ""))
        }
        return nil
    }

    private static func firstMatch(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }

    private static func decodeHTMLEntities(_ string: String) -> String {
        let entities: [String: String] = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&apos;": "'"
        ]
        var result = string
        for (entity, character) in entities {
            result = result.replacingOccurrences(of: entity, with: character)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct AmazonExtractResult: Decodable {
    let title: String?
    let price: String?
    let imageURL: String?
}

/// Amazonの商品ページは単純な通信だとボット判定されて中身が取得できないため、
/// 実際にページを描画できるWKWebViewを使って商品名・価格・画像を読み取る。
@MainActor
private final class AmazonPageScraper: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var loadContinuation: CheckedContinuation<Void, Error>?
    private var didResumeLoad = false

    func fetch(url: URL) async throws -> ProductMetadata {
        // 毎回Cookie等が空の状態(非永続ストア)にすると、Amazon側にボットとして
        // 警戒されやすくなる(ブロックされたページを読んでしまう)ことが分かったため、
        // 通常のストアを使いつつ、リクエスト自体はキャッシュを無視して最新のページを取得する。
        let webView = WKWebView(frame: .zero)
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
        webView.navigationDelegate = self
        self.webView = webView

        // 古い価格のキャッシュを見てしまわないよう、必ずサーバーから最新のページを取り直す
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("https://www.google.com/", forHTTPHeaderField: "Referer")

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.loadContinuation = continuation
            webView.load(request)
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
                self?.resumeLoad(.failure(URLError(.timedOut)))
            }
        }

        let script = """
        (function() {
            function text(sel) {
                var el = document.querySelector(sel);
                return el && el.textContent.trim() ? el.textContent.trim() : null;
            }
            // iPhoneでアクセスすると、Amazonはスマホ向けの別レイアウトを返すため、
            // PC向け・スマホ向け両方のセレクタを候補に入れる
            var title = text('#productTitle')
                || text('#title')
                || text('[data-feature-name="title"]')
                || text('h1 span');
            var price = text('#corePrice_feature_div .a-offscreen')
                || text('.a-price .a-offscreen')
                || text('#priceblock_ourprice')
                || text('#priceblock_dealprice');
            // 上のセレクタで見つからない時のための保険として、
            // ページ内の「¥1,234」のような表記をあいまい検索する
            if (!price) {
                var offscreenEls = document.querySelectorAll('.a-offscreen, .a-price-whole');
                for (var i = 0; i < offscreenEls.length; i++) {
                    var t = offscreenEls[i].textContent.trim();
                    if (/[¥￥]\\s?[0-9][0-9,]*/.test(t)) {
                        price = t;
                        break;
                    }
                }
            }
            if (!price) {
                var bodyMatch = document.body.innerText.match(/[¥￥]\\s?[0-9][0-9,]{1,8}/);
                if (bodyMatch) { price = bodyMatch[0]; }
            }
            var img = document.querySelector('#landingImage')
                || document.querySelector('#imgTagWrapperId img')
                || document.querySelector('#main-image');
            var imageURL = img ? (img.getAttribute('data-old-hires') || img.src) : null;
            return JSON.stringify({title: title, price: price, imageURL: imageURL});
        })();
        """

        // Amazonは初回表示後にも価格などを追加で描画することがあり、特にスポンサー広告経由の
        // リンクは価格の表示が遅れることがあるため、見つかるまで数回に分けて読み取りを試み、
        // 一度見つかった項目は後の失敗で上書きされないようにする。
        var bestTitle: String?
        var bestPrice: String?
        var bestImageURL: String?
        for attempt in 0..<9 {
            try? await Task.sleep(nanoseconds: attempt == 0 ? 1_200_000_000 : 1_000_000_000)

            guard let jsonString = try? await webView.evaluateJavaScript(script) as? String,
                  let jsonData = jsonString.data(using: .utf8),
                  let result = try? JSONDecoder().decode(AmazonExtractResult.self, from: jsonData) else {
                continue
            }
            bestTitle = bestTitle ?? result.title
            bestPrice = bestPrice ?? result.price
            bestImageURL = bestImageURL ?? result.imageURL
            if bestTitle != nil && bestPrice != nil && bestImageURL != nil {
                break
            }
        }

        let parsed = AmazonExtractResult(title: bestTitle, price: bestPrice, imageURL: bestImageURL)

        var imageData: Data?
        if let imageURLString = parsed.imageURL, let imageURL = URL(string: imageURLString) {
            imageData = try? await URLSession.shared.data(from: imageURL).0
        }

        let price: Double? = parsed.price.flatMap { priceString in
            let digits = priceString.filter { $0.isNumber || $0 == "." }
            return digits.isEmpty ? nil : Double(digits)
        }

        return ProductMetadata(title: parsed.title, imageData: imageData, price: price)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        resumeLoad(.success(()))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        resumeLoad(.failure(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        resumeLoad(.failure(error))
    }

    private func resumeLoad(_ result: Result<Void, Error>) {
        guard !didResumeLoad, let loadContinuation else { return }
        didResumeLoad = true
        self.loadContinuation = nil
        loadContinuation.resume(with: result)
    }
}

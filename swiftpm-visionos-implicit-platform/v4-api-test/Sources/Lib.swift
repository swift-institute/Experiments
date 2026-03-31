// MARK: - V4: Full iOS code path simulation on visionOS
// Purpose: Verify all APIs used in PDF.Render.Client+iOS.swift compile on visionOS
// Hypothesis: UIKit printing APIs compile on visionOS; #if guards are the only issue
//
// Toolchain: Apple Swift 6.3 (swiftlang-6.3.0.123.5)
// Platform: visionOS 26.4 simulator SDK
//
// Result: TBD
// Date: 2026-03-31

// === Simulate the #if guards from swift-html-to-pdf ===

// This file tests the ACTUAL code patterns from the iOS implementation

#if canImport(UIKit)
import UIKit
import WebKit
import CoreGraphics
import Foundation

// --- UIPrintPageRenderer (from renderToDataWithFormatter) ---
@MainActor func testPrintRenderer() -> Data {
    let renderer = UIPrintPageRenderer()
    let formatter = UIMarkupTextPrintFormatter(markupText: "<h1>Test</h1>")
    renderer.addPrintFormatter(formatter, startingAtPageAt: 0)

    let paperRect = CGRect(origin: .zero, size: CGSize(width: 595.28, height: 841.89))
    let printableRect = CGRect(x: 36, y: 36, width: 595.28 - 72, height: 841.89 - 72)

    renderer.setValue(NSValue(cgRect: paperRect), forKey: "paperRect")
    renderer.setValue(NSValue(cgRect: printableRect), forKey: "printableRect")

    let pdfData = NSMutableData()
    UIGraphicsBeginPDFContextToData(pdfData, paperRect, nil)
    renderer.prepare(forDrawingPages: NSRange(location: 0, length: renderer.numberOfPages))

    let bounds = UIGraphicsGetPDFContextBounds()
    for i in 0..<renderer.numberOfPages {
        UIGraphicsBeginPDFPage()
        renderer.drawPage(at: i, in: bounds)
    }
    UIGraphicsEndPDFContext()
    return pdfData as Data
}

// --- WKWebView.createPDF (from macOS continuous mode) ---
@MainActor func testCreatePDF(webView: WKWebView) async throws -> Data {
    let config = WKPDFConfiguration()
    config.rect = nil
    return try await webView.pdf(configuration: config)
}

// --- viewPrintFormatter (from iOS WebView renderer) ---
@MainActor func testViewPrintFormatter(webView: WKWebView) {
    let _ = webView.viewPrintFormatter()
}

// --- WKWebView configuration (from WKWebViewResource) ---
@MainActor func testWebViewConfig() -> WKWebView {
    let config = WKWebViewConfiguration()
    config.websiteDataStore = .nonPersistent()
    config.suppressesIncrementalRendering = true
    config.defaultWebpagePreferences.allowsContentJavaScript = true
    config.preferences.javaScriptCanOpenWindowsAutomatically = false
    config.preferences.minimumFontSize = 0
    config.preferences.isFraudulentWebsiteWarningEnabled = false
    return WKWebView(frame: .zero, configuration: config)
}

// --- CGPDFDocument page extraction (from extractPageInfo) ---
func testPageExtraction(data: Data) -> (Int, [CGSize]) {
    guard let provider = CGDataProvider(data: data as CFData),
          let doc = CGPDFDocument(provider) else { return (0, []) }
    let count = doc.numberOfPages
    var dims: [CGSize] = []
    for i in 1...count {
        guard let page = doc.page(at: i) else { continue }
        dims.append(page.getBoxRect(.mediaBox).size)
    }
    return (count, dims)
}

// --- WKNavigationDelegate (from DocumentWKRenderer) ---
@MainActor class TestNavigationDelegate: NSObject, WKNavigationDelegate {
    var continuation: CheckedContinuation<Void, Error>?

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        continuation?.resume()
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

// --- Atomic file write (from FileSystemHelpers) ---
func testAtomicWrite(_ data: Data, to url: URL) throws {
    let dir = url.deletingLastPathComponent()
    let tmp = dir.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf.tmp")
    try data.write(to: tmp)
    if FileManager.default.fileExists(atPath: url.path) {
        _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
    } else {
        try FileManager.default.moveItem(at: tmp, to: url)
    }
}

#else
// UIKit not available — this branch should NOT compile on visionOS
#endif

// === Test the FAILING guard from PDF.Render.Metrics+macOS.swift ===
#if os(macOS) || os(iOS)
public let metricsGuardPasses = true
#else
public let metricsGuardPasses = false  // This is the bug — visionOS lands here
#endif

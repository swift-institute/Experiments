// MARK: - SwiftPM visionOS Implicit Platform Test (tools-version 6.2)
// Purpose: Verify whether SwiftPM 6.2 allows visionOS builds when visionOS is NOT listed in platforms
// Hypothesis: swift-tools-version 6.2 requires explicit visionOS in platforms array
//
// Toolchain: Apple Swift 6.3 (swiftlang-6.3.0.123.5)
// Platform: visionOS 26.4 SDK via --triple arm64-apple-xros26.0
//
// Result: REFUTED - Both tools-versions 5.9 and 6.2 compile for visionOS
//         without visionOS in platforms array. SwiftPM does not enforce
//         platform restrictions at build time.
// Evidence: Build Succeeded (1.50s)
// Date: 2026-03-31
//
// Conclusion: The issue reported in coenttb/swift-html-to-pdf#27 is NOT caused
//             by the platforms array. It must be caused by code that doesn't
//             compile on visionOS (e.g., UIKit printing APIs).

import Foundation

public struct Greeting {
    public let message: String

    public init(message: String) {
        self.message = message
    }
}

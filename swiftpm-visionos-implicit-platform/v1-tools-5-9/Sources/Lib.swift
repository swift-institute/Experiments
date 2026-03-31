// MARK: - SwiftPM visionOS Implicit Platform Test (tools-version 5.9)
// Purpose: Verify whether SwiftPM 5.9 allows visionOS builds when visionOS is NOT listed in platforms
// Hypothesis: swift-tools-version 5.9 implicitly supports visionOS (inherited from iOS)
//
// Toolchain: Apple Swift 6.3 (swiftlang-6.3.0.123.5)
// Platform: visionOS 26.4 SDK via --triple arm64-apple-xros26.0
//
// Result: CONFIRMED builds, but hypothesis misleading - both 5.9 AND 6.2 build.
//         SwiftPM never restricts platform availability via the platforms array.
// Evidence: Build Succeeded (1.77s)
// Date: 2026-03-31

import Foundation

public struct Greeting {
    public let message: String

    public init(message: String) {
        self.message = message
    }
}

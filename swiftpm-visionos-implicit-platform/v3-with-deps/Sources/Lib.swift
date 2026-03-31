// MARK: - V3: visionOS build with macro dependencies
// Purpose: Check if swift-dependencies/DependenciesMacros trigger SwiftPM visionOS crash
// Hypothesis: The "dynamic libraries for unknown os" crash is triggered by macro deps
//
// Toolchain: Apple Swift 6.3 (swiftlang-6.3.0.123.5)
// Platform: visionOS 26.4 simulator SDK
//
// Result: TBD
// Date: 2026-03-31

import Dependencies
import DependenciesMacros

@DependencyClient
public struct MyClient: Sendable {
    public var fetch: @Sendable () async throws -> String
}

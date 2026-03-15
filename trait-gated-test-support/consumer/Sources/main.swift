// MARK: - Trait-Gated Test Support Experiment
// Purpose: Verify SE-0450 package traits enable conditional test support deps
// Hypothesis: Consumer that enables "Snapshot Testing" trait gets access to
//             SnapshotStrategy extensions defined in Rendering Test Support
//
// Toolchain: Swift 6.2
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED - consumer with trait gets .rendered strategy; output matches
// Date: 2026-03-14

import Rendering
import Rendering_Test_Support
import TestSnapshotPrimitives

// Variant 1: Basic rendering works
let text = Text("Hello")
print("Render: \(text.body)")

// Variant 2: Snapshot strategy is available via trait-gated extension
let strategy: SnapshotStrategy<Text, String> = .rendered
let result = strategy.transform(text)
print("Snapshot: \(result)")
print("Match: \(result == text.body)")

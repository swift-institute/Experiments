// MARK: - MemberImportVisibility + @_exported Re-Export
// Purpose: Does @_exported import satisfy MemberImportVisibility?
//          If module A re-exports module B via @_exported import B,
//          can a consumer import only A and use B's types in public
//          signatures without separately importing B?
// Hypothesis: @_exported import DOES satisfy MemberImportVisibility —
//             the consumer does NOT need a separate `import Upstream`
//
// Toolchain: Apple Swift 6.2.4 (swiftlang-6.2.4.1.4)
// Platform: macOS (arm64)
//
// Result: CONFIRMED — all 4 variants compile and run with MemberImportVisibility enabled.
//         @_exported import fully satisfies MemberImportVisibility. Consumer does NOT need
//         a separate `import Upstream` — the re-export through Reexporter is sufficient.
// Date: 2026-03-13

// MARK: - Variant 1: Use re-exported type directly
// Hypothesis: UpstreamColor is usable via Reexporter without importing Upstream
import Reexporter

let color = UpstreamColor(red: 0.5, green: 0.5, blue: 1.0)
print("V1 - Direct type usage: \(color)")

// MARK: - Variant 2: Use re-exported free function
// Hypothesis: makeDefaultColor() is callable without importing Upstream
let defaultColor = makeDefaultColor()
print("V2 - Free function: \(defaultColor)")

// MARK: - Variant 3: Use in a public struct field
// Hypothesis: UpstreamColor can appear in a public type's stored property
public struct MyWidget {
    public var background: UpstreamColor

    public init(background: UpstreamColor) {
        self.background = background
    }
}

let widget = MyWidget(background: color)
print("V3 - Public struct field: \(widget.background)")

// MARK: - Variant 4: Use in a public function signature
// Hypothesis: UpstreamColor can appear in public function return type
public func makeWidget() -> MyWidget {
    MyWidget(background: makeDefaultColor())
}

let w = makeWidget()
print("V4 - Public function return: \(w.background)")

// MARK: - Results Summary
// V1: CONFIRMED — direct type usage works
// V2: CONFIRMED — free function works
// V3: CONFIRMED — public struct field works
// V4: CONFIRMED — public function return type works

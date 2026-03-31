# SwiftPM visionOS Implicit Platform Experiment

**Date**: 2026-03-31
**Toolchain**: Apple Swift 6.3 (swiftlang-6.3.0.123.5), Xcode 26.4
**Context**: coenttb/swift-html-to-pdf#27 — visionOS builds fail after v0.5.0

## Hypothesis

swift-tools-version 5.9 allows implicit visionOS builds (inherited from iOS),
while swift-tools-version 6.2 requires visionOS to be explicitly listed in
the `platforms` array.

## Result: REFUTED

The `platforms` array does not control platform availability in either
swift-tools-version. Both 5.9 and 6.2 compile for visionOS when the SDK
is provided, regardless of whether visionOS is listed in `platforms`.

## Variants

| Variant | Purpose | Result |
|---------|---------|--------|
| v1-tools-5-9 | Build for visionOS with tools 5.9, no visionOS in platforms | Build Succeeded (1.77s) |
| v2-tools-6-2 | Build for visionOS with tools 6.2, no visionOS in platforms | Build Succeeded (1.50s) |
| v3-with-deps | Build with macro dependencies (swift-dependencies) | SwiftPM crash (toolchain bug) |

## Additional Findings

### Compilation condition truth table on visionOS

| Guard | On visionOS |
|-------|-------------|
| `canImport(UIKit)` | TRUE |
| `os(iOS)` | FALSE |
| `os(visionOS)` | TRUE |
| `os(macOS) \|\| os(iOS)` | FALSE |
| `canImport(WebKit)` | TRUE |

### UIKit Printing API Availability on visionOS

All tested via `swiftc -typecheck` with visionOS simulator SDK:

| API | Available on visionOS |
|-----|----------------------|
| `UIPrintPageRenderer` | YES |
| `UIMarkupTextPrintFormatter` | YES |
| `UIGraphicsBeginPDFContextToData` | YES |
| `WKWebView` | YES |
| `WKWebView.pdf(configuration:)` | YES |
| `UIView.viewPrintFormatter()` | YES |

### Root Cause of swift-html-to-pdf#27

The iOS implementation file (`PDF.Render.Client+iOS.swift`) is guarded by
`#if canImport(UIKit)`, which is TRUE on visionOS — so it compiles and
provides `PDF.Render: DependencyKey` referencing `metrics: .liveValue`.

However, the metrics DependencyKey conformance (`PDF.Render.Metrics+macOS.swift`)
is guarded by `#if os(macOS) || os(iOS)`, which is FALSE on visionOS.

This causes a compilation error: `.liveValue` does not exist on
`PDF.Render.Metrics` on visionOS.

### Fix

1. `PDF.Render.Metrics+macOS.swift`: Change `#if os(macOS) || os(iOS)` to `#if os(macOS) || os(iOS) || os(visionOS)`
2. `PDF.Render+TestDependencyKey.swift`: Add `|| os(visionOS)` to the `#elseif os(iOS)` test client branch
3. `Package.swift`: Add `.visionOS(.v26)` for explicit consumer clarity

No new visionOS-specific implementation file is needed — the iOS code path
works on visionOS since all UIKit printing APIs are available.

### SwiftPM Bug

`swift build --triple arm64-apple-xros26.0` crashes with:
```
Basics/Triple+Basics.swift:152: Fatal error: Cannot create dynamic libraries for unknown os.
```
when the package has macro dependencies (swift-syntax). This is a SwiftPM
toolchain bug, not a package issue. Workaround: use `xcodebuild` with
visionOS platform installed, or `swiftc` directly for API availability testing.

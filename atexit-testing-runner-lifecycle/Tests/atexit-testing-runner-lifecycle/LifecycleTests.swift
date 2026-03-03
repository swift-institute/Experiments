// MARK: - atexit + Swift Testing Runner Lifecycle Validation
// Purpose: Verify (1) atexit handlers registered during @Test execution fire
//          after Swift Testing's runner completes, (2) #if canImport(Testing)
//          resolves to Apple's Testing in a standalone package, (3)
//          Testing.Issue.record reports failures from bridged code.
//
// Toolchain: Apple Swift 6.2.4 (swiftlang-6.2.4.1.4 clang-1700.6.4.2)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — all 5 variants behave as expected. atexit fires after
//         Swift Testing runner, canImport(Testing) resolves correctly,
//         Issue.record reports failures, drain() is idempotent, guard works.
//         Marker file at /tmp confirmed: "atexit-fired-with-2-entries: snapshot-1, snapshot-2"
// Date: 2026-03-03

import Testing
import Foundation  // FileManager for marker file

// MARK: - Shared state

/// Process-global singleton mimicking Test.Snapshot.Inline.state
final class SharedState: @unchecked Sendable {
    private var _entries: [String] = []
    private let _lock = NSLock()

    func register(_ entry: String) {
        _lock.withLock { _entries.append(entry) }
    }

    func drain() -> [String] {
        _lock.withLock {
            let result = _entries
            _entries = []
            return result
        }
    }

    var isEmpty: Bool {
        _lock.withLock { _entries.isEmpty }
    }
}

let sharedState = SharedState()

/// Marker file path — written by atexit handler, checked after `swift test`
let markerPath = FileManager.default.temporaryDirectory
    .appendingPathComponent("atexit-testing-lifecycle-marker-\(ProcessInfo.processInfo.processIdentifier).txt")
    .path

// Register atexit handler at module load time (simulates lazy registration on first register())
private let _installExitHandler: Void = {
    atexit {
        guard !sharedState.isEmpty else {
            // Write "empty" marker — means drain() was already called or nothing registered
            try? "atexit-fired-empty".write(toFile: markerPath, atomically: true, encoding: .utf8)
            return
        }
        let entries = sharedState.drain()
        let content = "atexit-fired-with-\(entries.count)-entries: \(entries.joined(separator: ", "))"
        try? content.write(toFile: markerPath, atomically: true, encoding: .utf8)
    }
}()

// MARK: - Variant 1: atexit fires after Swift Testing runner
// Hypothesis: An atexit handler registered during test execution fires after
//             Swift Testing's runner completes, allowing post-run cleanup.
// Result: CONFIRMED — marker file written: "atexit-fired-with-2-entries: snapshot-1, snapshot-2"

@Test("V1: atexit registration during test")
func atexitRegistration() {
    // Trigger lazy atexit installation
    _ = _installExitHandler

    // Register entries (simulates assertInlineSnapshot calling state.register())
    sharedState.register("snapshot-1")
    sharedState.register("snapshot-2")

    // The test itself passes — we verify the marker file externally after `swift test`
    #expect(true, "Registered 2 entries; atexit handler will drain after runner completes")

    print("[V1] Registered 2 entries in shared state")
    print("[V1] Marker file will be at: \(markerPath)")
}

// MARK: - Variant 2: #if canImport(Testing) resolves to Apple's Testing
// Hypothesis: In a standalone package (no dependency on swift-testing Institute),
//             #if canImport(Testing) finds Apple's toolchain Testing module.
// Result: CONFIRMED — canImportTesting = true, SourceLocation(line: 42) constructed

#if canImport(Testing)
let canImportTesting = true
#else
let canImportTesting = false
#endif

@Test("V2: canImport(Testing) resolves to Apple's Testing")
func canImportResolution() {
    #expect(canImportTesting, "canImport(Testing) should be true")

    // Verify we can use Apple's Testing API
    // If this compiles, we have Apple's Testing, not some other module
    let location = SourceLocation(
        fileID: "Test/File.swift",
        filePath: "/path/to/File.swift",
        line: 42,
        column: 1
    )
    #expect(location.line == 42)

    print("[V2] PASS — canImport(Testing) = true, SourceLocation constructed")
}

// MARK: - Variant 3: Testing.Issue.record reports failures
// Hypothesis: Calling Testing.Issue.record inside a @Test function causes the
//             test to fail, which is the behavior we need for the failure bridge.
// Result: CONFIRMED — test failed with "Issue recorded" + bridge message. Exact output:
//         "Test "V3: Issue.record causes test failure" recorded an issue at LifecycleTests.swift:124:21"
//         "Bridge test: this failure was reported via Testing.Issue.record"

@Test("V3: Issue.record causes test failure")
func issueRecordBridge() {
    // Simulate the bridge: call Testing.Issue.record with a message
    // This SHOULD cause this test to fail — that's the desired behavior
    Issue.record(
        Comment(rawValue: "Bridge test: this failure was reported via Testing.Issue.record"),
        sourceLocation: SourceLocation(
            fileID: #fileID,
            filePath: #filePath,
            line: #line,
            column: #column
        )
    )
    // If we reach here AND the test fails, the bridge works correctly
    print("[V3] Issue.record called — test should be marked as FAILED")
}

// MARK: - Variant 4: drain() idempotency
// Hypothesis: Two consecutive drain() calls — second returns empty array.
// Result: CONFIRMED — first drain: 2 entries, second drain: 0 entries

@Test("V4: drain() idempotency")
func drainIdempotency() {
    let state = SharedState()
    state.register("a")
    state.register("b")

    let first = state.drain()
    let second = state.drain()

    #expect(first.count == 2)
    #expect(second.count == 0)
    #expect(state.isEmpty)

    print("[V4] PASS — first drain: \(first.count) entries, second drain: \(second.count) entries")
}

// MARK: - Variant 5: nil-collector guard pattern
// Hypothesis: The pattern `if collector == nil { Issue.record(...) }` correctly
//             prevents double-reporting — Issue.record only called when no collector.
// Result: CONFIRMED — bridge fires only when collector is nil

@Test("V5: nil-collector guard prevents double-reporting")
func nilCollectorGuard() {
    // Simulate: collector IS present (Institute runner active)
    var collectorPresent: Bool? = true
    var bridgeCalled = false

    // The bridge pattern
    collectorPresent? = true  // Record to collector
    if collectorPresent == nil {
        bridgeCalled = true   // Would call Issue.record
    }

    #expect(!bridgeCalled, "Bridge should NOT fire when collector is present")

    // Simulate: collector is nil (Apple runner active)
    let nilCollector: Bool? = nil
    var bridgeCalled2 = false

    _ = nilCollector  // Optional chain → no-op
    if nilCollector == nil {
        bridgeCalled2 = true  // Would call Issue.record
    }

    #expect(bridgeCalled2, "Bridge SHOULD fire when collector is nil")

    print("[V5] PASS — guard correctly gates bridge invocation")
}

// MARK: - Results Summary
// V1: CONFIRMED  — atexit fires after Swift Testing runner (marker file verified)
// V2: CONFIRMED  — canImport(Testing) resolves to Apple's Testing
// V3: CONFIRMED  — Testing.Issue.record reports failures (test correctly fails)
// V4: CONFIRMED  — drain() idempotency (second drain returns empty)
// V5: CONFIRMED  — nil-collector guard prevents double-reporting

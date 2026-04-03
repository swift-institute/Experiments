// SUPERSEDED: See nonsending-dispatch
// nonsending-sendable-iterator experiment — REVISED
//
// Result: CONFIRMED — nonsending methods preserve isolation; nonsending @Sendable stored closures do NOT (the @Sendable makes the closure concurrent)
//
// FINDING: `nonisolated(nonsending) @Sendable` on stored closures does NOT
// preserve invoker isolation. The @Sendable makes the closure concurrent.
//
// This experiment validates the exact boundary between what preserves isolation
// and what doesn't.

import Foundation
import Synchronization

// ============================================================================
// TEST A: nonisolated(nonsending) METHOD — should preserve isolation
// ============================================================================

struct DirectMethod: Sendable {
    nonisolated(nonsending)
    func work() async -> String {
        return checkIsolationSafe()
    }
}

// ============================================================================
// TEST B: nonisolated(nonsending) @Sendable stored closure — does it preserve?
// ============================================================================

struct StoredClosure: Sendable {
    let _work: nonisolated(nonsending) @Sendable () async -> String

    nonisolated(nonsending)
    func work() async -> String {
        await _work()
    }
}

// ============================================================================
// TEST C: Plain @Sendable stored closure (control — should NOT preserve)
// ============================================================================

struct SendableClosure: Sendable {
    let _work: @Sendable () async -> String

    nonisolated(nonsending)
    func work() async -> String {
        await _work()
    }
}

// ============================================================================
// TEST D: nonisolated(nonsending) without @Sendable (not Sendable struct)
// ============================================================================

struct NonsendingClosure {
    let _work: nonisolated(nonsending) () async -> String

    nonisolated(nonsending)
    func work() async -> String {
        await _work()
    }
}

// ============================================================================
// TEST HARNESS
// ============================================================================

nonisolated func checkIsolation() -> String {
    dispatchPrecondition(condition: .onQueue(.main))
    return "MainActor (PRESERVED)"
}

nonisolated func checkIsolationSafe() -> String {
    let isMain = DispatchQueue.getSpecific(key: mainQueueKey) != nil
    return isMain ? "MainActor (PRESERVED)" : "cooperative pool (BROKEN)"
}

nonisolated(unsafe) let mainQueueKey = DispatchSpecificKey<Bool>()

func setupMainQueueDetection() {
    DispatchQueue.main.setSpecific(key: mainQueueKey, value: true)
}

@MainActor
func testAll() async {
    setupMainQueueDetection()
    print("Testing isolation preservation patterns:\n")

    // Test A: Direct nonisolated(nonsending) method
    let a = DirectMethod()
    let resultA = await a.work()
    print("  A. nonisolated(nonsending) method:          \(resultA)")

    // Test B: nonisolated(nonsending) @Sendable stored closure
    let b = StoredClosure(_work: {
        return checkIsolationSafe()
    })
    let resultB = await b.work()
    print("  B. nonsending @Sendable stored closure:     \(resultB)")

    // Test C: Plain @Sendable stored closure
    let c = SendableClosure(_work: {
        return checkIsolationSafe()
    })
    let resultC = await c.work()
    print("  C. @Sendable stored closure (control):      \(resultC)")

    // Test D: nonisolated(nonsending) WITHOUT @Sendable
    let d = NonsendingClosure(_work: {
        return checkIsolationSafe()
    })
    let resultD = await d.work()
    print("  D. nonsending (no @Sendable) closure:       \(resultD)")

    print("\nDone.")
}

@main
struct Main {
    static func main() async {
        await testAll()
    }
}

// V01: Sendable Iterator Isolation
//
// Purpose: Validate the boundary between what preserves isolation and what
//          doesn't when nonisolated(nonsending) is combined with @Sendable
//          on stored closures.
//
// Status: CONFIRMED -- nonsending methods preserve isolation; nonsending
//         @Sendable stored closures do NOT (the @Sendable makes the closure
//         concurrent).
//
// Revalidation: Re-run if @Sendable closure isolation semantics change.
//
// Origin: nonsending-sendable-iterator

import Foundation
import Synchronization

// MARK: - V01 Namespace

enum V01_SendableIterator {

    // MARK: - Variant A: nonisolated(nonsending) method -- preserves isolation

    struct DirectMethod: Sendable {
        nonisolated(nonsending)
        func work() async -> String {
            return checkIsolationSafe()
        }
    }

    // MARK: - Variant B: nonisolated(nonsending) @Sendable stored closure

    struct StoredClosure: Sendable {
        let _work: nonisolated(nonsending) @Sendable () async -> String

        nonisolated(nonsending)
        func work() async -> String {
            await _work()
        }
    }

    // MARK: - Variant C: Plain @Sendable stored closure (control)

    struct SendableClosure: Sendable {
        let _work: @Sendable () async -> String

        nonisolated(nonsending)
        func work() async -> String {
            await _work()
        }
    }

    // MARK: - Variant D: nonisolated(nonsending) without @Sendable (non-Sendable struct)

    struct NonsendingClosure {
        let _work: nonisolated(nonsending) () async -> String

        nonisolated(nonsending)
        func work() async -> String {
            await _work()
        }
    }

    // MARK: - Helpers

    static let mainQueueKey = DispatchSpecificKey<Bool>()

    static func checkIsolationSafe() -> String {
        let isMain = DispatchQueue.getSpecific(key: mainQueueKey) != nil
        return isMain ? "MainActor (PRESERVED)" : "cooperative pool (BROKEN)"
    }

    static func setupMainQueueDetection() {
        DispatchQueue.main.setSpecific(key: mainQueueKey, value: true)
    }

    // MARK: - Runner

    @MainActor
    static func run() async {
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
}

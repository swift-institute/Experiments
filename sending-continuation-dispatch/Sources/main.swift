// MARK: - Sending Continuation Dispatch Experiment
// Purpose: Find the minimal correct pattern for dispatching a `sending @escaping () -> T`
//          closure to a TaskExecutor via withCheckedContinuation + Task<Void, Never>,
//          WITHOUT requiring T: Sendable and WITHOUT nonisolated(unsafe).
//
// Toolchain: Swift 6.3 (Xcode 26 beta)
// Platform: macOS 26.0 (arm64)
//
// Results:
//   V1 (direct capture):            REFUTED — "closure captures reference to mutable parameter"
//   V2 (nonisolated(unsafe) let):   CONFIRMED — compiles, runs correctly
//   V3 (plain let):                 REFUTED — "closure captures 'op' which is accessible to code in the current task"
//   V4 (consuming + let):           REFUTED — same as V3
//   V5 (withUnsafeContinuation):    REFUTED — same error, different continuation API doesn't help
//   V6 (class holder):              CONFIRMED — compiles, runs, trades nonisolated(unsafe) for @unchecked Sendable + heap alloc
//   V7 (helper function):           REFUTED — same sending error (region doesn't transfer through function call)
//   V8 (Optional.take):             REFUTED — "closure captures 'taken' which is accessible"
//
// Conclusion:
//   No safe alternative exists in Swift 6.3. The region checker cannot model
//   continuation-based synchronization — it sees the Task body and the
//   continuation caller as potentially concurrent, even though the caller is
//   suspended. Every restructuring (let binding, consuming, Optional.take,
//   helper function, withUnsafeContinuation) fails with the same class of
//   error: "accessible to code in the current task."
//
//   The only two working patterns both require a programmer assertion:
//     V2: nonisolated(unsafe) let op = operation   (zero alloc, localized)
//     V6: @unchecked Sendable class holder         (1 heap alloc, class overhead)
//
//   V2 is strictly better: zero allocation, localized to one let binding,
//   same semantic assertion as V6 but without class machinery.
//
// Date: 2026-04-08

final class FakeExecutor: TaskExecutor, @unchecked Sendable {
    func enqueue(_ job: consuming ExecutorJob) {
        unsafe job.runSynchronously(on: asUnownedTaskExecutor())
    }
    func asUnownedTaskExecutor() -> UnownedTaskExecutor {
        unsafe UnownedTaskExecutor(ordinary: self)
    }
}

let executor = FakeExecutor()

// ============================================================================
// MARK: - V2: nonisolated(unsafe) let — CONFIRMED (current solution)
// ============================================================================

nonisolated(nonsending)
func variant2<T>(
    _ operation: sending @escaping () -> T
) async -> sending T {
    nonisolated(unsafe) let op = operation
    return await withCheckedContinuation { continuation in
        Task<Void, Never>(executorPreference: executor) {
            unsafe continuation.resume(returning: op())
        }
    }
}

// ============================================================================
// MARK: - V6: Class holder — CONFIRMED (alternative, worse)
// ============================================================================

final class OperationHolder<T>: @unchecked Sendable {
    let operation: () -> T
    init(_ operation: sending @escaping () -> T) {
        self.operation = operation
    }
}

nonisolated(nonsending)
func variant6<T>(
    _ operation: sending @escaping () -> T
) async -> sending T {
    let holder = OperationHolder(operation)
    return await withCheckedContinuation { continuation in
        Task<Void, Never>(executorPreference: executor) {
            continuation.resume(returning: holder.operation())
        }
    }
}

// ============================================================================
// MARK: - Test runner
// ============================================================================

@main
struct Main {
    static func main() async {
        let r2 = await variant2 { 42 }
        print("V2 (nonisolated(unsafe)): \(r2)")

        let r6 = await variant6 { 99 }
        print("V6 (class holder): \(r6)")

        print("Done — V2 is the preferred pattern (zero alloc, localized unsafe)")
    }
}

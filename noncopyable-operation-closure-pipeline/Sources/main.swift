// MARK: - Non-Copyable Operation Closure Pipeline Feasibility
// Purpose: Verify that a ~Copyable, Sendable transport struct can flow through
//          stored closure parameters end-to-end, validating the A+E design for
//          removing @Sendable from IO.run operation closures.
//
// Context: The A+E design boxes a non-Sendable closure into a raw pointer (payload)
//          and pairs it with a stateless executor. Both are carried in a ~Copyable,
//          Sendable struct (Operation) through a pipeline of stored closures into
//          Job.Instance. This experiment verifies each link in that chain compiles.
//
// Prior art: sending-mutex-noncopyable-region (same Experiments/ directory)
//
// Toolchain: Apple Swift 6.3 (swiftlang-6.3.0.123.5)
// Platform: macOS 26.0 (arm64)
//
// Result: PRIMARY PATH CONFIRMED (with nonisolated(unsafe) on pointer fields)
//         - ~Copyable Operation flows through stored closure pipeline end-to-end
//         - consuming func take() with Bool flag works for move tracking
//         - deinit cleanup works on cancellation/drop paths
//         - async stored closures accept consuming ~Copyable params
//         - Full pipeline: non-Sendable closure → box → Operation → Lane → Job → execute
//
//         DISCOVERED LIMITATION: UnsafeMutableRawPointer is NOT Sendable in Swift 6.2+
//         strict concurrency (@unsafe Sendable). Requires nonisolated(unsafe) on pointer
//         fields in ~Copyable Sendable structs. Same applies to Optional<UMRP>.
//         This means Job.Instance cannot drop @unchecked Sendable purely through A+E;
//         it needs nonisolated(unsafe) on the payload field regardless.
//
// Date: 2026-04-03

import Synchronization

// ============================================================================
// MARK: - Shared Infrastructure
// ============================================================================

/// Simulates Ownership.Transfer.Box.make — boxes a value into a raw pointer.
@inline(never)
func boxMake<T>(_ value: T) -> UnsafeMutableRawPointer {
    let ptr = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<T>.size, alignment: MemoryLayout<T>.alignment)
    ptr.initializeMemory(as: T.self, to: value)
    return ptr
}

/// Simulates Ownership.Transfer.Box.take — unboxes and deallocates.
@inline(never)
func boxTake<T>(_ ptr: UnsafeMutableRawPointer) -> T {
    let value = ptr.load(as: T.self)
    ptr.deallocate()
    return value
}

/// Simulates Ownership.Transfer.Box.destroy — type-erased deallocation.
@inline(never)
func boxDestroy(_ ptr: UnsafeMutableRawPointer) {
    ptr.deallocate()
}

// ============================================================================
// MARK: - V1: ~Copyable Sendable struct as stored closure parameter
// Hypothesis: A ~Copyable, Sendable struct can be a parameter type in a stored
//             closure property. The closure consumes the parameter.
// Result:
// ============================================================================

struct V1_Payload: ~Copyable, Sendable {
    let value: Int
}

func v1_stored_closure_parameter() {
    let f: @Sendable (consuming V1_Payload) -> Int = { payload in
        payload.value
    }
    let result = f(V1_Payload(value: 42))
    precondition(result == 42)
    print("V1: ~Copyable Sendable as stored closure param — OK (\(result))")
}

// ============================================================================
// MARK: - V2: Optional<UnsafeMutableRawPointer> Sendable in ~Copyable context
// Hypothesis: Optional<UnsafeMutableRawPointer> is Sendable when stored in a
//             ~Copyable struct conforming to Sendable.
// Result: REFUTED — Optional's Sendable conditional conformance does not apply
//         in ~Copyable struct context. Error: "stored property of Sendable-
//         conforming struct has non-Sendable type 'UnsafeMutableRawPointer?'"
// ============================================================================

// DISABLED — see V2 result above. This is a compiler/stdlib limitation.
// struct V2_OptionalSendable: ~Copyable, Sendable {
//     var payload: UnsafeMutableRawPointer?  // ERROR: not Sendable
// }

// ============================================================================
// MARK: - V3: Bool flag instead of Optional for move tracking
// Hypothesis: Using a non-optional pointer + Bool flag avoids the Optional
//             Sendable issue while achieving the same nil-out semantics.
// Result:
// ============================================================================

struct V3_Operation: ~Copyable, Sendable {
    nonisolated(unsafe) private let payload: UnsafeMutableRawPointer
    let executor: @Sendable (UnsafeMutableRawPointer) -> UnsafeMutableRawPointer
    private var consumed: Bool

    init(payload: UnsafeMutableRawPointer, executor: @Sendable @escaping (UnsafeMutableRawPointer) -> UnsafeMutableRawPointer) {
        self.payload = payload
        self.executor = executor
        self.consumed = false
    }

    consuming func take() -> (UnsafeMutableRawPointer, @Sendable (UnsafeMutableRawPointer) -> UnsafeMutableRawPointer) {
        precondition(!consumed, "Operation.take() called on already-consumed operation")
        consumed = true
        return (payload, executor)
    }

    deinit {
        if !consumed {
            boxDestroy(payload)
            print("  [deinit] V3_Operation destroyed payload (cleanup path)")
        }
    }
}

func v3_bool_flag_operation() {
    // Normal path: take() transfers ownership, deinit is no-op
    do {
        let op = V3_Operation(
            payload: boxMake(99),
            executor: { ptr in boxMake(boxTake(ptr) as Int * 2) }
        )
        let (payload, executor) = op.take()
        let result: Int = boxTake(executor(payload))
        precondition(result == 198)
        print("V3a: take() + execute — OK (\(result))")
    }

    // Cleanup path: Operation dropped without take(), deinit destroys payload
    do {
        let _ = V3_Operation(
            payload: boxMake(77),
            executor: { ptr in ptr }
        )
        print("V3b: deinit cleanup path — OK")
    }
}

// ============================================================================
// MARK: - V4: nonisolated(unsafe) on Optional field
// Hypothesis: nonisolated(unsafe) on a single Optional<UnsafeMutableRawPointer>
//             field allows the struct to be Sendable while using Optional nil-out.
// Result:
// ============================================================================

struct V4_Operation: ~Copyable, Sendable {
    nonisolated(unsafe) private var payload: UnsafeMutableRawPointer?
    let executor: @Sendable (UnsafeMutableRawPointer) -> UnsafeMutableRawPointer

    init(payload: UnsafeMutableRawPointer, executor: @Sendable @escaping (UnsafeMutableRawPointer) -> UnsafeMutableRawPointer) {
        self.payload = payload
        self.executor = executor
    }

    consuming func take() -> (UnsafeMutableRawPointer, @Sendable (UnsafeMutableRawPointer) -> UnsafeMutableRawPointer) {
        let p = payload!
        payload = nil
        return (p, executor)
    }

    deinit {
        if let ptr = payload {
            boxDestroy(ptr)
            print("  [deinit] V4_Operation destroyed payload (cleanup path)")
        }
    }
}

func v4_nonisolated_unsafe_optional() {
    // Normal path
    do {
        let op = V4_Operation(
            payload: boxMake(50),
            executor: { ptr in boxMake(boxTake(ptr) as Int + 50) }
        )
        let (payload, executor) = op.take()
        let result: Int = boxTake(executor(payload))
        precondition(result == 100)
        print("V4a: nonisolated(unsafe) Optional + take() — OK (\(result))")
    }

    // Cleanup path
    do {
        let _ = V4_Operation(
            payload: boxMake(88),
            executor: { ptr in ptr }
        )
        print("V4b: nonisolated(unsafe) Optional cleanup — OK")
    }
}

// ============================================================================
// MARK: - V5: Stored @Sendable closure with consuming ~Copyable param
// Hypothesis: A stored closure of type @Sendable (consuming Operation) -> R
//             compiles and correctly consumes the ~Copyable parameter.
// Result:
// ============================================================================

func v5_stored_sendable_closure_noncopyable_param() {
    let storedRun: @Sendable (consuming V3_Operation) -> UnsafeMutableRawPointer = { operation in
        let (payload, executor) = operation.take()
        return executor(payload)
    }

    let op = V3_Operation(
        payload: boxMake(50),
        executor: { ptr in boxMake(boxTake(ptr) as Int + 10) }
    )
    let resultPtr = storedRun(op)
    let result: Int = boxTake(resultPtr)
    precondition(result == 60)
    print("V5: stored @Sendable closure with consuming ~Copyable param — OK (\(result))")
}

// ============================================================================
// MARK: - V6: Forwarding ~Copyable through nested stored closures
// Hypothesis: A ~Copyable value can be forwarded through multiple layers of
//             stored closures (simulating Lane._run → Threads.run → Job).
// Result:
// ============================================================================

struct V6_Lane: Sendable {
    let _run: @Sendable (consuming V3_Operation) -> UnsafeMutableRawPointer
}

func v6_nested_forwarding() {
    @Sendable func threadsRun(_ operation: consuming V3_Operation) -> UnsafeMutableRawPointer {
        let (payload, executor) = operation.take()
        return executor(payload)
    }

    let lane = V6_Lane(
        _run: { operation in
            threadsRun(operation)
        }
    )

    let op = V3_Operation(
        payload: boxMake(100),
        executor: { ptr in boxMake(boxTake(ptr) as Int * 3) }
    )
    let resultPtr = lane._run(op)
    let result: Int = boxTake(resultPtr)
    precondition(result == 300)
    print("V6: forwarding through nested stored closures — OK (\(result))")
}

// ============================================================================
// MARK: - V7: Job.Instance with consuming run() + deinit cleanup
// Hypothesis: Job.Instance can store payload + executor via take(), nil out
//             payload in consuming run() via Bool flag, deinit handles cleanup.
// Result:
// ============================================================================

struct V7_Job: ~Copyable, Sendable {
    nonisolated(unsafe) private let payload: UnsafeMutableRawPointer
    private let executor: @Sendable (UnsafeMutableRawPointer) -> UnsafeMutableRawPointer
    private var consumed: Bool
    let id: Int

    init(id: Int, operation: consuming V3_Operation) {
        self.id = id
        let (p, e) = operation.take()
        self.payload = p
        self.executor = e
        self.consumed = false
    }

    deinit {
        if !consumed {
            boxDestroy(payload)
            print("  [deinit] V7_Job destroyed payload (cleanup path)")
        }
    }

    consuming func run() -> UnsafeMutableRawPointer {
        precondition(!consumed, "Job.run() called on consumed job")
        consumed = true
        return executor(payload)
    }
}

func v7_job_instance() {
    // Normal path: create job, run it
    do {
        let op = V3_Operation(
            payload: boxMake(25),
            executor: { ptr in boxMake(boxTake(ptr) as Int + 75) }
        )
        let job = V7_Job(id: 1, operation: op)
        let resultPtr = job.run()
        let result: Int = boxTake(resultPtr)
        precondition(result == 100)
        print("V7a: Job create + run — OK (\(result))")
    }

    // Cleanup path: job dropped without run (simulates cancellation)
    do {
        let op = V3_Operation(
            payload: boxMake(999),
            executor: { ptr in ptr }
        )
        let _ = V7_Job(id: 2, operation: op)
        print("V7b: Job deinit cleanup — OK")
    }
}

// ============================================================================
// MARK: - V8: Full pipeline — non-Sendable closure → Operation → Lane → Job
// Hypothesis: A non-@Sendable closure can be boxed into a raw pointer, carried
//             through a stored closure pipeline as ~Copyable Operation, consumed
//             by Job, and executed.
// Result:
// ============================================================================

final class V8_NonSendableResource {
    var data: Int
    init(_ data: Int) { self.data = data }
}

func v8_full_pipeline() {
    let resource = V8_NonSendableResource(42)
    let userClosure: () -> Int = {
        resource.data * 2
    }

    func laneBox<T>(_ operation: @escaping () -> T) -> V3_Operation {
        V3_Operation(
            payload: boxMake(operation),
            executor: { ptr in
                let op: () -> T = boxTake(ptr)
                return boxMake(op())
            }
        )
    }

    let laneRun: @Sendable (consuming V3_Operation) -> UnsafeMutableRawPointer = { operation in
        let job = V7_Job(id: 42, operation: operation)
        return job.run()
    }

    let op = laneBox(userClosure)
    let resultPtr = laneRun(op)
    let result: Int = boxTake(resultPtr)
    precondition(result == 84)
    print("V8: full pipeline with non-Sendable closure — OK (\(result))")
}

// ============================================================================
// MARK: - V9: Early cancellation — Operation deinit auto-cleanup
// Hypothesis: When Operation is created but the function throws before Job
//             creation, Operation's deinit cleans up automatically.
// Result:
// ============================================================================

enum V9_Error: Error { case cancelled }

func v9_early_cancellation() {
    @Sendable func threadsRun(_ operation: consuming V3_Operation, cancelled: Bool) throws(V9_Error) -> UnsafeMutableRawPointer {
        if cancelled {
            throw .cancelled
        }
        let job = V7_Job(id: 99, operation: operation)
        return job.run()
    }

    do {
        let op = V3_Operation(
            payload: boxMake(123),
            executor: { ptr in ptr }
        )
        _ = try threadsRun(op, cancelled: true)
        fatalError("Should have thrown")
    } catch {
        print("V9a: early cancellation, Operation deinit cleanup — OK")
    }

    do {
        let op = V3_Operation(
            payload: boxMake(10),
            executor: { ptr in boxMake(boxTake(ptr) as Int + 5) }
        )
        let resultPtr = try threadsRun(op, cancelled: false)
        let result: Int = boxTake(resultPtr)
        precondition(result == 15)
        print("V9b: normal path after cancellation check — OK (\(result))")
    } catch {
        fatalError("Should not throw")
    }
}

// ============================================================================
// MARK: - V10: Async stored closure with ~Copyable parameter
// Hypothesis: An async stored closure can accept a consuming ~Copyable param.
//             Simulates the actual Lane._run which is async.
// Result:
// ============================================================================

func v10_async_stored_closure() async {
    let asyncRun: @Sendable (consuming V3_Operation) async -> UnsafeMutableRawPointer = { operation in
        let (payload, executor) = operation.take()
        return executor(payload)
    }

    let op = V3_Operation(
        payload: boxMake(7),
        executor: { ptr in boxMake(boxTake(ptr) as Int * 7) }
    )
    let resultPtr = await asyncRun(op)
    let result: Int = boxTake(resultPtr)
    precondition(result == 49)
    print("V10: async stored closure with consuming ~Copyable — OK (\(result))")
}

// ============================================================================
// MARK: - V11: Sendable struct storing async closure with ~Copyable param
// Hypothesis: A Sendable struct can store an async @Sendable closure that takes
//             a consuming ~Copyable parameter. This is the actual Lane shape.
// Result:
// ============================================================================

struct V11_Lane: Sendable {
    let _run: @Sendable (consuming V3_Operation) async -> UnsafeMutableRawPointer

    init(run: @escaping @Sendable (consuming V3_Operation) async -> UnsafeMutableRawPointer) {
        self._run = run
    }
}

func v11_struct_storing_async_closure() async {
    let lane = V11_Lane(
        run: { operation in
            let (payload, executor) = operation.take()
            return executor(payload)
        }
    )

    let op = V3_Operation(
        payload: boxMake(11),
        executor: { ptr in boxMake(boxTake(ptr) as Int + 89) }
    )
    let resultPtr = await lane._run(op)
    let result: Int = boxTake(resultPtr)
    precondition(result == 100)
    print("V11: Sendable struct storing async closure with ~Copyable param — OK (\(result))")
}

// ============================================================================
// MARK: - Execution
// ============================================================================

v1_stored_closure_parameter()
v3_bool_flag_operation()
v4_nonisolated_unsafe_optional()
v5_stored_sendable_closure_noncopyable_param()
v6_nested_forwarding()
v7_job_instance()
v8_full_pipeline()
v9_early_cancellation()

await v10_async_stored_closure()
await v11_struct_storing_async_closure()

// ============================================================================
// MARK: - Results Summary
//
// V1:  CONFIRMED — ~Copyable Sendable struct as stored closure parameter
// V2:  REFUTED   — Optional<UnsafeMutableRawPointer> not Sendable in ~Copyable context
// V3a: CONFIRMED — Bool flag + take() + execute (normal path)
// V3b: CONFIRMED — deinit cleanup on drop (cancellation path)
// V4a: CONFIRMED — nonisolated(unsafe) Optional + take() (normal path)
// V4b: CONFIRMED — nonisolated(unsafe) Optional cleanup (cancellation path)
// V5:  CONFIRMED — stored @Sendable closure with consuming ~Copyable param
// V6:  CONFIRMED — forwarding through nested stored closures (Lane → Threads)
// V7a: CONFIRMED — Job create from Operation + run (normal path)
// V7b: CONFIRMED — Job deinit cleanup on drop (cancellation path)
// V8:  CONFIRMED — full pipeline: non-Sendable closure → box → Operation → Lane → Job → execute
// V9a: CONFIRMED — early cancellation, Operation deinit auto-cleanup
// V9b: CONFIRMED — normal path after cancellation check
// V10: CONFIRMED — async stored closure with consuming ~Copyable parameter
// V11: CONFIRMED — Sendable struct storing async closure with ~Copyable param
//
// KEY FINDING: UnsafeMutableRawPointer is @unsafe Sendable in Swift 6.2+.
// It requires nonisolated(unsafe) on the field to satisfy Sendable struct conformance.
// This is a language-level constraint, not a design limitation of A+E.
// The A+E pipeline mechanics (boxing, transport, forwarding, consuming, cleanup) all work.
// ============================================================================

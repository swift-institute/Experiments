// MARK: - sending vs Sendable in Structured Concurrency
//
// Purpose: Validate whether `sending` can replace `Sendable` conformance
//          for ~Copyable types used with addTask, async let, and other
//          structured concurrency primitives.
//
// Original hypothesis: addTask requires @Sendable closures. Non-Sendable
//   ~Copyable types cannot be captured even with `sending`.
//
// Actual finding: The Sendable question is MOOT for ~Copyable types.
//   The real constraint is more fundamental: ~Copyable values cannot be
//   consumed when captured by ANY escaping closure — regardless of
//   Sendable conformance. addTask, async let, and Task { } all use
//   escaping closures. The Transfer wrapper pattern (V9) is the only
//   way to get ~Copyable values into structured concurrency.
//
// Toolchain: Apple Swift 6.3 (swiftlang-6.3.0.123.5)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — with reframing (see results summary at bottom)
// Date: 2026-04-06
//
// Results Summary:
//   V1a: CONFIRMED — ~Copyable cannot be consumed in escaping closure
//        (even with [consume] capture list)
//   V1b: CONFIRMED — consuming function call works (not closure capture)
//   V2:  CONFIRMED — `sending` works at function boundaries
//   V3:  CONFIRMED — ~Copyable cannot be consumed in @Sendable closure
//   V4:  CONFIRMED — Copyable + Sendable in addTask works (control)
//   V5:  CONFIRMED — Copyable non-Sendable in addTask fails (data race)
//   V6:  CONFIRMED — ~Copyable in async let fails (escaping closure)
//   V7:  CONFIRMED — ~Copyable in Task { } fails (escaping closure)
//   V8:  CONFIRMED — consuming function parameters work for full-duplex
//   V9:  CONFIRMED — Transfer wrapper enables ~Copyable in addTask
//
// Key insight: V1a/V3/V6/V7 all hit the SAME error regardless of
// Sendable: "noncopyable value cannot be consumed when captured by
// an escaping closure". The Sendable vs sending debate is a layer
// above the actual blocker. The real constraint is Swift's inability
// to move ~Copyable values through escaping closures.

// ═══════════════════════════════════════════════════════════
// Test types
// ═══════════════════════════════════════════════════════════

/// ~Copyable AND Sendable.
struct SendableResource: ~Copyable, Sendable {
    let id: Int
    consuming func use() { print("  SendableResource \(id) used") }
}

/// ~Copyable but NOT Sendable.
struct NonSendableResource: ~Copyable {
    let id: Int
    consuming func use() { print("  NonSendableResource \(id) used") }
}

/// Helper: accepts a sending parameter.
func acceptSending(_ resource: consuming sending NonSendableResource) async {
    resource.use()
}

/// Helper: returns a sending value.
func makeSending() -> sending NonSendableResource {
    NonSendableResource(id: 99)
}

// ═══════════════════════════════════════════════════════════
// MARK: - V1: Sendable ~Copyable in addTask — consume in capture list
// Hypothesis: Explicit consuming capture makes it work.
// Result: [PENDING]
// ═══════════════════════════════════════════════════════════

// func v1a_sendable_addTask_consumingCapture() async {
//     print("V1a: Sendable ~Copyable in addTask with consuming capture")
//     let resource = SendableResource(id: 1)
//     await withTaskGroup(of: Void.self) { group in
//         group.addTask { [resource = consume resource] in
//             resource.use()
//         }
//     }
// }

// ═══════════════════════════════════════════════════════════
// MARK: - V1b: Sendable ~Copyable via function call (not closure capture)
// Hypothesis: Passing through a consuming function avoids the
//             closure capture limitation.
// Result: [PENDING]
// ═══════════════════════════════════════════════════════════

func useSendable(_ r: consuming SendableResource) async {
    r.use()
}

func v1b_sendable_functionCall() async {
    print("V1b: Sendable ~Copyable via consuming function call")
    let resource = SendableResource(id: 1)
    await useSendable(resource)
}

// ═══════════════════════════════════════════════════════════
// MARK: - V2: Non-Sendable ~Copyable via sending parameter
// Hypothesis: `sending` at function boundary allows non-Sendable
//             to cross isolation.
// Result: [PENDING]
// ═══════════════════════════════════════════════════════════

func v2_sending_parameter() async {
    print("V2: Non-Sendable ~Copyable via sending parameter")
    let resource = NonSendableResource(id: 2)
    await acceptSending(resource)
}

// ═══════════════════════════════════════════════════════════
// MARK: - V3: Can ~Copyable values be captured in ANY escaping closure?
// Hypothesis: This is a ~Copyable limitation, not a Sendable one.
//             Even a plain @escaping closure can't consume ~Copyable.
// Result: [PENDING]
// ═══════════════════════════════════════════════════════════

// func v3_noncopyable_escapingClosure() {
//     print("V3: ~Copyable in plain escaping closure")
//     let resource = SendableResource(id: 3)
//     let closure: @Sendable () -> Void = {
//         resource.use()
//     }
//     closure()
// }

// ═══════════════════════════════════════════════════════════
// MARK: - V4: Copyable Sendable in addTask (control — must work)
// Hypothesis: Copyable + Sendable in addTask compiles fine (baseline).
// Result: [PENDING]
// ═══════════════════════════════════════════════════════════

struct CopyableSendable: Sendable {
    let id: Int
    func use() { print("  CopyableSendable \(id) used") }
}

func v4_copyable_sendable_addTask() async {
    print("V4: Copyable Sendable in addTask (control)")
    let resource = CopyableSendable(id: 4)
    await withTaskGroup(of: Void.self) { group in
        group.addTask {
            resource.use()
        }
    }
}

// ═══════════════════════════════════════════════════════════
// MARK: - V5: Copyable non-Sendable in addTask
// Hypothesis: Non-Sendable fails even when Copyable.
// Result: [PENDING]
// ═══════════════════════════════════════════════════════════

class NonSendableState {
    var value: Int = 0
    func use() { print("  NonSendableState used, value: \(value)") }
}

// func v5_copyable_nonSendable_addTask() async {
//     print("V5: Copyable non-Sendable in addTask")
//     let state = NonSendableState()
//     await withTaskGroup(of: Void.self) { group in
//         group.addTask {
//             state.use()
//         }
//     }
// }

// ═══════════════════════════════════════════════════════════
// MARK: - V6: ~Copyable Sendable with async let
// Hypothesis: async let has the same escaping-closure limitation.
// Result: [PENDING]
// ═══════════════════════════════════════════════════════════

// func v6_noncopyable_asyncLet() async {
//     print("V6: ~Copyable Sendable in async let")
//     let resource = SendableResource(id: 6)
//     async let result: Void = resource.use()
//     await result
// }

// ═══════════════════════════════════════════════════════════
// MARK: - V7: ~Copyable Sendable with Task { } (unstructured)
// Hypothesis: Unstructured Task also can't consume ~Copyable.
// Result: [PENDING]
// ═══════════════════════════════════════════════════════════

// func v7_noncopyable_unstructuredTask() async {
//     print("V7: ~Copyable Sendable in unstructured Task")
//     let resource = SendableResource(id: 7)
//     Task {
//         resource.use()
//     }
// }

// ═══════════════════════════════════════════════════════════
// MARK: - V8: Full-duplex pattern — how does swift-io actually do it?
// Hypothesis: The real pattern passes ~Copyable values through
//             consuming function parameters, NOT through closure capture.
// Result: [PENDING]
// ═══════════════════════════════════════════════════════════

func readLoop(_ reader: consuming SendableResource) async {
    reader.use()
}

func writeLoop(_ writer: consuming SendableResource) async {
    writer.use()
}

func v8_function_parameter_pattern() async {
    print("V8: Full-duplex via consuming function parameters")
    let reader = SendableResource(id: 80)
    let writer = SendableResource(id: 81)

    // Pattern: pass through function, not closure capture
    await readLoop(reader)
    await writeLoop(writer)
}

// ═══════════════════════════════════════════════════════════
// MARK: - V9: addTask with wrapper transfer (Reference.Transfer pattern)
// Hypothesis: Wrapping ~Copyable in an @unchecked Sendable class
//             allows addTask capture.
// Result: [PENDING]
// ═══════════════════════════════════════════════════════════

final class Transfer<T: ~Copyable>: @unchecked Sendable {
    private var _value: T?
    init(_ value: consuming T) { _value = consume value }
    func take() -> T { _value.take()! }
}

func v9_transfer_wrapper() async {
    print("V9: ~Copyable via Transfer wrapper in addTask")
    let reader = SendableResource(id: 90)
    let writer = SendableResource(id: 91)
    let readerTransfer = Transfer(reader)
    let writerTransfer = Transfer(writer)

    await withTaskGroup(of: Void.self) { group in
        group.addTask {
            var r = readerTransfer.take()
            r.use()
        }
        group.addTask {
            var w = writerTransfer.take()
            w.use()
        }
    }
}

// ═══════════════════════════════════════════════════════════
// MARK: - Entry Point
// ═══════════════════════════════════════════════════════════

await v1b_sendable_functionCall()
await v2_sending_parameter()
await v4_copyable_sendable_addTask()
await v8_function_parameter_pattern()
await v9_transfer_wrapper()

print("\n--- Commented-out variants (uncomment one at a time to test) ---")
print("V1a: Sendable ~Copyable in addTask with [consume] capture list")
print("V3:  ~Copyable in @Sendable closure")
print("V5:  Copyable non-Sendable in addTask")
print("V6:  ~Copyable Sendable with async let")
print("V7:  ~Copyable Sendable with unstructured Task")

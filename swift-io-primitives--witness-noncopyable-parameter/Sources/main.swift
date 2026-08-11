// ============================================================================
// Single-file V1–V5 exception
//
// This file deliberately contains multiple types and is *not* split into
// separate `.swift` files per [API-IMPL-005]. The V1–V5 incremental-
// experiment shape is the experiment's purpose: each variant is a
// hypothesis whose compilability (and runtime output) is verified in
// sequence. Splitting V1, V2, V3, V4, V5 into five files would destroy
// the side-by-side comparison that makes the experiment legible.
//
// All other code-surface conventions still apply — Nest.Name throughout
// (`Witness.V1`, `Witness.V2`, …; `Witness.Failure`; `Demo.v1`, `Demo.v2`,
// …), no compound identifiers, typed throws, minimal type bodies.
// ============================================================================

// MARK: - Witness ~Copyable Parameter Experiment
//
// Purpose: Verify that @Sendable closures stored as let properties in a
//          Sendable struct can accept `consuming` parameters of ~Copyable
//          types.
// Hypothesis: Stored @Sendable closures can take consuming ~Copyable
//             parameters, enabling IO.Event.Driver's @Witness pattern to
//             use `consuming Owned`.
//
// Methodology: Incremental construction per [EXP-004a]
//
// Toolchain: Apple Swift 6.3 (swiftlang-6.3.0.123.5)
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Platform: macOS 26.2 (arm64)
//
// Results:
//   V1 (basic):              CONFIRMED — Output: 42
//   V2 (borrowing+consuming): CONFIRMED — Output: 13
//   V3 (throwing):           CONFIRMED — Output: success 25, failure caught
//   V4 (generic phantom tag): CONFIRMED — Output: 110
//   V5 (multiple calls):     CONFIRMED — Output: 1, 2, 3
//
// Note: Closure literals that throw in the body require explicit `throws(E)`
//       annotation in the closure signature. The compiler does not infer
//       typed throws from context for closure literals assigned to
//       typed-throw function types.
//
// Date: 2026-03-30 (renamed for code-surface compliance 2026-04-20)

// ============================================================================
// MARK: - Shared types
// ============================================================================

struct Resource: ~Copyable, Sendable {
    let value: Int
}

struct Handle: ~Copyable, Sendable {
    let fd: Int32
}

struct Interest: Sendable {
    let mask: UInt32
}

struct ID: Sendable {
    let rawValue: Int
}

struct Owned<Tag>: ~Copyable, Sendable {
    let rawValue: Int32
}

enum Selector {}

// ============================================================================
// MARK: - Witness namespace + per-variant struct
// ============================================================================

enum Witness {}

extension Witness {
    enum Failure: Error {
        case unspecified
    }
}

extension Witness {
    // V1: Basic — stored @Sendable closure with consuming ~Copyable param.
    // Hypothesis: stored @Sendable closure can take a consuming ~Copyable
    //             parameter. Result: CONFIRMED — Output: 42
    struct V1: Sendable {
        let operation: @Sendable (consuming Resource) -> Int
    }
}

extension Witness {
    // V2: Borrowing handle + consuming resource.
    // Hypothesis: stored closure can mix borrowing ~Copyable and consuming
    //             ~Copyable params. Result: CONFIRMED — Output: 13
    struct V2: Sendable {
        let register: @Sendable (borrowing Handle, consuming Resource) -> Int
    }
}

extension Witness {
    // V3: Throwing — typed throws in stored closure.
    // Hypothesis: stored @Sendable closure can use throws(Witness.Failure)
    //             with consuming ~Copyable. Result: CONFIRMED.
    // Caveat: closure literals require explicit throws(Witness.Failure)
    //         annotation.
    struct V3: Sendable {
        let register: @Sendable (borrowing Handle, consuming Resource) throws(Witness.Failure) -> Int
    }
}

extension Witness {
    // V4: Generic phantom tag — Owned<Tag> pattern.
    // Hypothesis: a generic ~Copyable phantom-tagged type works as consuming
    //             param in a stored closure, matching the Driver pattern.
    // Result: CONFIRMED — Output: 110
    struct V4: Sendable {
        let register: @Sendable (borrowing Handle, consuming Owned<Selector>, Interest) throws(Witness.Failure) -> ID
    }
}

// ============================================================================
// MARK: - Demo namespace + per-variant entry point
// ============================================================================

enum Demo {}

extension Demo {
    static func v1() {
        let w = Witness.V1(operation: { r in r.value })
        let result = w.operation(Resource(value: 42))
        precondition(result == 42, "V1: expected 42, got \(result)")
        print("V1: \(result)")
    }
}

extension Demo {
    static func v2() {
        let handle = Handle(fd: 3)
        let w = Witness.V2(register: { h, r in
            Int(h.fd) + r.value
        })
        let result = w.register(handle, Resource(value: 10))
        precondition(result == 13, "V2: expected 13, got \(result)")
        print("V2: \(result)")
        _ = consume handle
    }
}

extension Demo {
    static func v3() throws(Witness.Failure) {
        let handle = Handle(fd: 5)

        // Success path
        let w = Witness.V3(register: { h, r in
            Int(h.fd) + r.value
        })
        let result = try w.register(handle, Resource(value: 20))
        precondition(result == 25, "V3 success: expected 25, got \(result)")
        print("V3 success: \(result)")

        // Failure path
        let wFail = Witness.V3(register: { _, _ throws(Witness.Failure) in
            throw .unspecified
        })
        do throws(Witness.Failure) {
            let _ = try wFail.register(handle, Resource(value: 99))
            precondition(false, "V3: should have thrown")
        } catch {
            precondition(error == .unspecified, "V3: expected .unspecified")
            print("V3 failure: caught \(error)")
        }
        _ = consume handle
    }
}

extension Demo {
    static func v4() throws(Witness.Failure) {
        let handle = Handle(fd: 7)
        let w = Witness.V4(register: { h, owned, interest in
            ID(rawValue: Int(h.fd) + Int(owned.rawValue) + Int(interest.mask))
        })
        let result = try w.register(handle, Owned<Selector>(rawValue: 100), Interest(mask: 3))
        precondition(result.rawValue == 110, "V4: expected 110, got \(result.rawValue)")
        print("V4: \(result.rawValue)")
        _ = consume handle
    }
}

extension Demo {
    static func v5() {
        // V5 reuses Witness.V1 — same closure, called multiple times with
        // different ~Copyable values.
        let w = Witness.V1(operation: { r in r.value })

        let r1 = w.operation(Resource(value: 1))
        let r2 = w.operation(Resource(value: 2))
        let r3 = w.operation(Resource(value: 3))

        precondition(r1 == 1 && r2 == 2 && r3 == 3, "V5: unexpected results")
        print("V5: \(r1), \(r2), \(r3)")
    }
}

// ============================================================================
// MARK: - Run all
// ============================================================================

Demo.v1()
Demo.v2()
try Demo.v3()
try Demo.v4()
Demo.v5()

print("\nAll variants passed.")

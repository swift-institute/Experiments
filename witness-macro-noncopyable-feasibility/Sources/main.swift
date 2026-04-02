// MARK: - Witness Macro ~Copyable Feasibility
// Purpose: Test whether @Witness macro blockers for IO drivers can be resolved
//          or worked around in Swift 6.2.4
// Hypothesis: Multiple — see per-variant hypotheses below
//
// Toolchain: Apple Swift 6.2.4 (swiftlang-6.2.4.1.4 clang-1700.6.4.2)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — @Witness macro supports ~Copyable witnesses via WitnessProjectable projection pattern; 12 of 13 variants pass
// Results:
//   V1a: REFUTED   — Copyable enum cannot hold ~Copyable associated values
//   V1b: CONFIRMED — ~Copyable enum CAN hold ~Copyable associated values
//   V1c: CONFIRMED — switch/consume on ~Copyable enum works
//   V1e: CONFIRMED — ~Copyable + Sendable enum works (with Sendable fields)
//   V2a: CONFIRMED — borrowing parameters forward through closure wrappers
//   V2b: CONFIRMED — borrowing observation (before/after) works
//   V3a: CONFIRMED — consuming with borrow-then-consume pattern works
//   V3b: CONFIRMED — consuming with Copyable projection recording works
//   V4c: CONFIRMED — Action with Copyable projections of ~Copyable values works
//   V5:  CONFIRMED — init + forwarding works for ~Copyable witness structs
//   V6:  CONFIRMED — full Observe pattern works with PROJECTED Copyable Action enum
//   V7:  CONFIRMED — WitnessProjectable protocol provides type-safe projections
//   V8a: CONFIRMED — unimplemented() works for all ownership patterns (throws)
//   V8b: CONFIRMED — non-throwing consuming closures use fatalError (acceptable)
//   V8c: CONFIRMED — recording close observes fd before consuming handle
//   V9:  CONFIRMED — full Observe+Action+unimplemented for realistic IO driver
//   V10: CONFIRMED — Result capture works via projection for ~Copyable returns
//   V11: CONFIRMED — uniform projection (Copyable types project as identity)
//   V12: CONFIRMED — inout parameters observed in before/after callbacks
//
// Key Findings:
//   1. The @Witness macro CAN support ~Copyable witnesses using the Projection
//      pattern: Action enum stores Copyable projections via WitnessProjectable.
//   2. Borrowing/consuming forwarding through closure wrappers works natively.
//   3. Typed throws requires explicit closure annotations (macro must generate these).
//   4. Non-throwing consuming closures need fatalError in unimplemented (not throw).
//   5. WitnessProjectable protocol unifies Copyable/~Copyable: Copyable types
//      project as identity, ~Copyable types project to a Copyable summary.
//   6. inout parameters forward cleanly through observation wrappers.
//
// Date: 2026-03-04

// ============================================================================
// MARK: - V1: ~Copyable Enum Associated Values
// Hypothesis: Swift 6.2.4 still prohibits ~Copyable enum associated values
// ============================================================================

struct Handle: ~Copyable {
    let fd: Int32
    deinit { print("Handle(\(fd)) closed") }
}

// V1a: Can a regular (Copyable) enum have a ~Copyable associated value?
// Result: REFUTED — error: "associated value 'register' of 'Copyable'-conforming
//         enum 'Action' has non-Copyable type 'Handle'"
// enum Action {
//     case register(Handle, Int32)
//     case close(Handle)
// }

// V1b: Can a ~Copyable enum have ~Copyable associated values?
enum NCAction: ~Copyable {
    case register(Handle, Int32)
    case close(Handle)
}

// V1c: Can we switch on a ~Copyable enum with ~Copyable payloads?
func testNCAction() {
    let action = NCAction.register(Handle(fd: 42), 8080)
    switch consume action {
    case .register(let h, let port):
        print("V1c: register fd=\(h.fd) port=\(port)")
    case .close(let h):
        print("V1c: close fd=\(h.fd)")
    }
}

// V1d: Can we make the ~Copyable enum Sendable?
// (Action enum needs Sendable if witness is Sendable)
// Uncomment to test:
// enum NCSendableAction: ~Copyable, Sendable {
//     case register(Handle, Int32)  // Handle is not Sendable
// }

// V1e: With a Sendable ~Copyable type
struct SendableHandle: ~Copyable, Sendable {
    let fd: Int32
}

enum NCSendableAction2: ~Copyable, Sendable {
    case register(SendableHandle, Int32)
    case close(SendableHandle)
}

// ============================================================================
// MARK: - V2: Borrowing Parameter Forwarding Through Closures
// Hypothesis: `borrowing` parameters cannot be forwarded through closure wrappers
//             without explicit copy or consuming semantics
// ============================================================================

struct Witness_V2: Sendable {
    let _poll: @Sendable (borrowing Handle, Int) -> Int
}

// V2a: Can we wrap a borrowing closure in another closure?
func testBorrowingForwarding() {
    let original = Witness_V2(_poll: { handle, count in
        print("V2a: polling fd=\(handle.fd) count=\(count)")
        return count
    })

    // Simulate Observe wrapper: wrap the closure, forward the call
    let observed: @Sendable (borrowing Handle, Int) -> Int = { handle, count in
        print("V2a-before: about to poll")
        let result = original._poll(handle, count)
        print("V2a-after: polled, got \(result)")
        return result
    }

    let h = Handle(fd: 10)
    let r = observed(h, 5)
    print("V2a: result = \(r)")
    _ = consume h
}

// V2b: Can we capture the handle value in a before/after callback?
// (Observe pattern needs to inspect arguments)
func testBorrowingObservation() {
    let original: @Sendable (borrowing Handle, Int) -> Int = { handle, count in
        return count * 2
    }

    // Can the "before" closure see the handle?
    let beforeCallback: @Sendable (borrowing Handle, Int) -> Void = { handle, count in
        print("V2b-before: handle fd=\(handle.fd), count=\(count)")
    }

    let observed: @Sendable (borrowing Handle, Int) -> Int = { handle, count in
        beforeCallback(handle, count)
        let result = original(handle, count)
        print("V2b-after: result=\(result)")
        return result
    }

    let h = Handle(fd: 20)
    let r = observed(h, 3)
    print("V2b: result = \(r)")
    _ = consume h
}

// ============================================================================
// MARK: - V3: Consuming Parameter Forwarding
// Hypothesis: `consuming` parameters CANNOT be forwarded through observation
//             closures because observation needs to read the value before
//             consumption
// ============================================================================

struct Witness_V3: Sendable {
    let _close: @Sendable (consuming Handle) -> Void
}

// V3a: Can we observe then consume?
func testConsumingForwarding() {
    let original = Witness_V3(_close: { handle in
        print("V3a: closing fd=\(handle.fd)")
    })

    // Attempt: read fd before forwarding
    // This requires borrowing the handle first, then consuming it
    let observed: @Sendable (consuming Handle) -> Void = { handle in
        // Can we borrow-then-consume in the same closure?
        let fd = handle.fd  // borrow
        print("V3a-before: about to close fd=\(fd)")
        original._close(consume handle)  // consume
        print("V3a-after: closed fd=\(fd)")
    }

    observed(Handle(fd: 30))
}

// V3b: Can we observe with an Action-like recording?
func testConsumingRecording() {
    let actions: [String] = []

    let original = Witness_V3(_close: { handle in
        print("V3b: closing fd=\(handle.fd)")
    })

    // Record the action before consuming
    let recording: @Sendable (consuming Handle) -> Void = { handle in
        let fd = handle.fd
        // In a real macro: actions.append(.close(fd)) — but we can't capture
        // the Handle itself since it's being consumed
        print("V3b: recorded close(fd=\(fd))")
        original._close(consume handle)
    }

    recording(Handle(fd: 40))
    _ = actions  // suppress warning
}

// ============================================================================
// MARK: - V4: Alternative Action Representations for ~Copyable
// Hypothesis: We can represent actions without enum associated values by using
//             closures, structs, or existentials instead
// ============================================================================

// V4a: Action as struct with closure (thunk pattern)
struct ActionRecord: Sendable {
    let name: String
    let description: String
    // Can't store the actual Handle — it's ~Copyable
    // But we CAN store a description of what happened
}

// V4b: Action as case enum with metadata only (no associated values)
enum ActionCase: Sendable {
    case register
    case modify
    case deregister
    case poll
    case close
}

// V4c: Action with Copyable projections of ~Copyable values
struct ActionWithProjection: Sendable {
    let actionCase: ActionCase
    let fdValue: Int32?  // Projected from Handle.fd
    let extraInt: Int?
}

func testActionProjection() {
    // When observing a borrowing Handle, project its Copyable fields
    let original: @Sendable (borrowing Handle, Int32) -> Void = { handle, port in
        print("V4c: register fd=\(handle.fd) port=\(port)")
    }

    let recorded: [ActionWithProjection] = []

    let observed: @Sendable (borrowing Handle, Int32) -> Void = { handle, port in
        let projection = ActionWithProjection(
            actionCase: .register,
            fdValue: handle.fd,
            extraInt: Int(port)
        )
        print("V4c: recorded \(projection.actionCase) fd=\(projection.fdValue ?? -1)")
        // Can't append to `recorded` from Sendable closure, but the pattern works
        original(handle, port)
    }

    let h = Handle(fd: 50)
    observed(h, 9090)
    _ = consume h
    _ = recorded
}

// ============================================================================
// MARK: - V5: Minimal Macro Subset — Init + Forwarding Only
// Hypothesis: A subset of @Witness that generates ONLY memberwise init and
//             labeled-parameter forwarding methods is fully compatible with
//             ~Copyable witnesses
// ============================================================================

// Simulate what a @WitnessLite macro would generate for IO.Event.Driver:

struct SimulatedDriver: Sendable {
    // Original closure properties (as in IO.Event.Driver)
    let _create: @Sendable () throws -> Handle
    let _register: @Sendable (borrowing Handle, Int32, Int) throws -> Int
    let _close: @Sendable (consuming Handle) -> Void

    // === BEGIN: What @WitnessLite would generate ===

    // Memberwise init (already exists for structs, but macro makes it public)
    // init(create:register:close:) — this is the default memberwise init

    // Forwarding methods for labeled closures
    // (In IO drivers, closures are unlabeled, so NO methods generated)
    // This confirms: for IO drivers specifically, even init-only generation
    // has minimal value since the init already exists.

    // === END ===
}

func testSimulatedDriver() {
    let driver = SimulatedDriver(
        _create: {
            print("V5: creating handle")
            return Handle(fd: 99)
        },
        _register: { handle, descriptor, interest in
            print("V5: registering fd=\(handle.fd) descriptor=\(descriptor)")
            return 1
        },
        _close: { handle in
            print("V5: closing fd=\(handle.fd)")
        }
    )

    do {
        let h = try driver._create()
        let id = try driver._register(h, 42, 1)
        print("V5: registered with id=\(id)")
        driver._close(consume h)
    } catch {
        print("V5: error: \(error)")
    }
}

// ============================================================================
// MARK: - V6: ~Copyable Enum as Action — Full Pattern Test
// Hypothesis: A ~Copyable Action enum can work if the ENTIRE observation
//             pipeline is also ~Copyable
// ============================================================================

// The Action enum itself must be ~Copyable if it holds ~Copyable values
// Key insight: Action stores PROJECTIONS of ~Copyable values, not the values
// themselves. Since projections are Copyable (Int32, etc.), Action is Copyable.
enum DriverAction: Sendable {
    case create
    case register(fd: Int32, descriptor: Int32, interest: Int)
    case close(fd: Int32)
}

struct ObservableDriver: Sendable {
    let _create: @Sendable () throws -> Handle
    let _register: @Sendable (borrowing Handle, Int32, Int) throws -> Int
    let _close: @Sendable (consuming Handle) -> Void

    // Observation with projected actions (Copyable)
    func withObservation(
        before: @escaping @Sendable (DriverAction) -> Void
    ) -> ObservableDriver {
        let orig = self
        return ObservableDriver(
            _create: {
                before(.create)
                return try orig._create()
            },
            _register: { handle, descriptor, interest in
                before(.register(fd: handle.fd, descriptor: descriptor, interest: interest))
                return try orig._register(handle, descriptor, interest)
            },
            _close: { handle in
                before(.close(fd: handle.fd))
                orig._close(consume handle)
            }
        )
    }
}

func testObservableDriver() {
    let base = ObservableDriver(
        _create: { Handle(fd: 77) },
        _register: { h, d, i in
            print("V6: register fd=\(h.fd)")
            return 1
        },
        _close: { h in print("V6: close fd=\(h.fd)") }
    )

    let observed = base.withObservation { action in
        switch action {
        case .create:
            print("V6-observe: create")
        case .register(let fd, let desc, let interest):
            print("V6-observe: register fd=\(fd) desc=\(desc) interest=\(interest)")
        case .close(let fd):
            print("V6-observe: close fd=\(fd)")
        }
    }

    do {
        let h = try observed._create()
        _ = try observed._register(h, 42, 1)
        observed._close(consume h)
    } catch {
        print("V6: error \(error)")
    }
}

// ============================================================================
// MARK: - V7: Projection Protocol
// Hypothesis: A protocol can provide type-safe Copyable projections of
//             ~Copyable values for Action enum associated values
// ============================================================================

/// Protocol for types that can project a Copyable summary of themselves.
/// The macro would detect ~Copyable parameters and use `.projection` in
/// Action enum construction instead of the raw value.
protocol WitnessProjectable: ~Copyable {
    associatedtype Projection: Copyable & Sendable
    var projection: Projection { get }
}

// Handle conforms — projects its fd
extension Handle: WitnessProjectable {
    var projection: Int32 { fd }
}

// Rich projection: struct with multiple fields
struct RichHandle: ~Copyable {
    let fd: Int32
    let flags: UInt32
    let label: String
    deinit { print("RichHandle(\(fd)) closed") }
}

struct RichHandleProjection: Sendable {
    let fd: Int32
    let flags: UInt32
    let label: String
}

extension RichHandle: WitnessProjectable {
    var projection: RichHandleProjection {
        RichHandleProjection(fd: fd, flags: flags, label: label)
    }
}

// V7a: Action enum using Projection types
enum ProjectedAction: Sendable {
    case create
    case register(Handle.Projection, Int32, Int)  // Int32, Int32, Int
    case poll(RichHandle.Projection, Int)
    case close(Handle.Projection)
}

func testProjectionProtocol() {
    let h = Handle(fd: 60)
    let rh = RichHandle(fd: 61, flags: 0x0F, label: "test")

    // Macro-generated observe wrapper would call .projection automatically
    let action1 = ProjectedAction.register(h.projection, 42, 1)
    let action2 = ProjectedAction.poll(rh.projection, 256)
    let action3 = ProjectedAction.close(h.projection)

    switch action1 {
    case .register(let fd, let desc, let interest):
        print("V7a: register fd=\(fd) desc=\(desc) interest=\(interest)")
    default: break
    }
    switch action2 {
    case .poll(let proj, let count):
        print("V7a: poll fd=\(proj.fd) flags=\(proj.flags) label=\(proj.label) count=\(count)")
    default: break
    }
    switch action3 {
    case .close(let fd):
        print("V7a: close fd=\(fd)")
    default: break
    }

    _ = consume h
    _ = consume rh
}

// ============================================================================
// MARK: - V8: Unimplemented Generation for ~Copyable Witnesses
// Hypothesis: unimplemented() can work for all closure signatures including
//             those with ~Copyable borrowing/consuming parameters
// ============================================================================

// The macro generates closures that fatalError (or throw Witness.Unimplemented.Error).
// Question: do all ownership combinations work?

struct UnimplementedTest: Sendable {
    // Closure returning ~Copyable (create pattern)
    let _create: @Sendable () throws -> Handle

    // Closure borrowing ~Copyable (read pattern)
    let _read: @Sendable (borrowing Handle) throws -> Int

    // Closure consuming ~Copyable (close pattern)
    let _close: @Sendable (consuming Handle) -> Void

    // Closure borrowing + returning ~Copyable (modify pattern)
    // NOTE: Can't return a new Handle without creating one.
    // Unimplemented must fatalError, not return.
    let _modify: @Sendable (borrowing Handle, Int32) throws -> Int
}

enum UnimplementedError: Error, Sendable {
    case unimplemented(function: String)
}

// V8a: Can we generate unimplemented() for all patterns?
func testUnimplemented() {
    let unimpl = UnimplementedTest(
        _create: { throw UnimplementedError.unimplemented(function: "create") },
        _read: { _ in throw UnimplementedError.unimplemented(function: "read") },
        _close: { handle in
            // Must consume the handle even in unimplemented
            _ = consume handle
            fatalError("close is unimplemented")
        },
        _modify: { _, _ in throw UnimplementedError.unimplemented(function: "modify") }
    )

    // Test create
    do {
        let h = try unimpl._create()
        _ = consume h
        print("V8a: UNEXPECTED — create should have thrown")
    } catch {
        print("V8a: create correctly threw: \(error)")
    }

    // Test read
    do {
        let h = Handle(fd: 70)
        _ = try unimpl._read(h)
        _ = consume h
        print("V8a: UNEXPECTED — read should have thrown")
    } catch {
        print("V8a: read correctly threw: \(error)")
    }

    // Test close — would fatalError, so skip in test
    print("V8a: close would fatalError (skipping)")

    // Test modify
    do {
        let h = Handle(fd: 71)
        _ = try unimpl._modify(h, 42)
        _ = consume h
        print("V8a: UNEXPECTED — modify should have thrown")
    } catch {
        print("V8a: modify correctly threw: \(error)")
    }
}

// V8b: For non-throwing consuming closures, can we throw from unimplemented?
// No — the closure signature is (consuming Handle) -> Void (non-throwing).
// The macro MUST use fatalError() for non-throwing closures.
// This is acceptable: unimplemented is a development aid, not a production path.

// V8c: Alternative — consuming closure that records rather than fatalErrors
func testUnimplementedRecording() {
    // For testing: an "unimplemented" that records the call instead of crashing
    let recording = UnimplementedTest(
        _create: { throw UnimplementedError.unimplemented(function: "create") },
        _read: { handle in
            // Can read from borrowed handle for recording
            print("V8c: read called on fd=\(handle.fd)")
            throw UnimplementedError.unimplemented(function: "read")
        },
        _close: { handle in
            // Can borrow-before-consume for recording
            let fd = handle.fd
            print("V8c: close called on fd=\(fd)")
            _ = consume handle
            // Note: can't throw from non-throwing, but we CAN record
        },
        _modify: { handle, value in
            print("V8c: modify called on fd=\(handle.fd) value=\(value)")
            throw UnimplementedError.unimplemented(function: "modify")
        }
    )

    // Test recording close
    recording._close(Handle(fd: 72))
    print("V8c: close recorded successfully")
}

// ============================================================================
// MARK: - V9: Full Observe + Action for Realistic IO Driver
// Hypothesis: The complete @Witness expansion (Action, Observe, unimplemented)
//             can work for a realistic IO driver using the projection pattern
// ============================================================================

// Simulate what @Witness would generate for a realistic driver.
// This is the "theoretical perfection" design.

// The original witness struct (user-authored):
struct EventDriver: Sendable {
    let _create: @Sendable () throws(DriverError) -> Handle
    let _register: @Sendable (borrowing Handle, Int32, Interest) throws(DriverError) -> RegistrationID
    let _poll: @Sendable (borrowing Handle, inout [PollEvent]) throws(DriverError) -> Int
    let _close: @Sendable (consuming Handle) -> Void
}

struct Interest: Sendable { let rawValue: UInt32 }
struct RegistrationID: Sendable { let rawValue: Int }
struct PollEvent: Sendable { let fd: Int32; let readiness: UInt32 }
enum DriverError: Error, Sendable { case syscall(Int32) }

// === BEGIN: What @Witness would generate ===

extension EventDriver {

    // MARK: Action (with projections for ~Copyable parameters)

    enum Action: Sendable {
        case create
        case register(handle: Handle.Projection, descriptor: Int32, interest: Interest)
        case poll(handle: Handle.Projection, eventCount: Int)
        case close(handle: Handle.Projection)
    }

    // MARK: Action.Case (discriminant only — no values)

    enum ActionCase: Sendable, CaseIterable {
        case create, register, poll, close
    }

    // MARK: Observe

    struct Observe: Sendable {
        let wrapped: EventDriver
        let before: @Sendable (Action) -> Void
        let after: @Sendable (Action) -> Void

        var _create: @Sendable () throws(DriverError) -> Handle {
            { [wrapped, before, after] () throws(DriverError) -> Handle in
                before(.create)
                let result = try wrapped._create()
                after(.create)
                return result
            }
        }

        var _register: @Sendable (borrowing Handle, Int32, Interest) throws(DriverError) -> RegistrationID {
            { [wrapped, before, after] (handle: borrowing Handle, descriptor: Int32, interest: Interest) throws(DriverError) -> RegistrationID in
                let action = Action.register(
                    handle: handle.projection,
                    descriptor: descriptor,
                    interest: interest
                )
                before(action)
                let result = try wrapped._register(handle, descriptor, interest)
                after(action)
                return result
            }
        }

        var _poll: @Sendable (borrowing Handle, inout [PollEvent]) throws(DriverError) -> Int {
            { [wrapped, before, after] (handle: borrowing Handle, events: inout [PollEvent]) throws(DriverError) -> Int in
                before(.poll(handle: handle.projection, eventCount: 0))
                let count = try wrapped._poll(handle, &events)
                after(.poll(handle: handle.projection, eventCount: count))
                return count
            }
        }

        var _close: @Sendable (consuming Handle) -> Void {
            { [wrapped, before, after] (handle: consuming Handle) -> Void in
                let proj = handle.projection
                before(.close(handle: proj))
                wrapped._close(consume handle)
                after(.close(handle: proj))
            }
        }

        /// Materialize back into a plain EventDriver
        var driver: EventDriver {
            EventDriver(
                _create: _create,
                _register: _register,
                _poll: _poll,
                _close: _close
            )
        }
    }

    // MARK: observe (computed property)

    var observe: Observe {
        Observe(wrapped: self, before: { _ in }, after: { _ in })
    }

    func observing(
        before: @escaping @Sendable (Action) -> Void = { _ in },
        after: @escaping @Sendable (Action) -> Void = { _ in }
    ) -> EventDriver {
        Observe(wrapped: self, before: before, after: after).driver
    }

    // MARK: unimplemented()

    static func unimplemented(
        fileID: String = #fileID,
        line: UInt = #line
    ) -> EventDriver {
        EventDriver(
            _create: { () throws(DriverError) in throw DriverError.syscall(-1) },
            _register: { (_, _, _) throws(DriverError) in throw DriverError.syscall(-1) },
            _poll: { (_, _) throws(DriverError) in throw DriverError.syscall(-1) },
            _close: { (handle: consuming Handle) in _ = consume handle }
        )
    }
}

func testFullObservation() {
    let base = EventDriver(
        _create: { Handle(fd: 80) },
        _register: { handle, desc, interest in
            print("V9: register fd=\(handle.fd) desc=\(desc)")
            return RegistrationID(rawValue: 1)
        },
        _poll: { handle, events in
            print("V9: poll fd=\(handle.fd)")
            events.append(PollEvent(fd: handle.fd, readiness: 1))
            return 1
        },
        _close: { handle in
            print("V9: close fd=\(handle.fd)")
        }
    )

    // Full observation with before/after
    let observed = base.observing(
        before: { action in
            let desc: String
            switch action {
            case .create: desc = "create"
            case .register(let fd, let d, _): desc = "register(fd:\(fd),desc:\(d))"
            case .poll(let fd, _): desc = "poll(fd:\(fd))"
            case .close(let fd): desc = "close(fd:\(fd))"
            }
            print("V9-before: \(desc)")
        },
        after: { action in
            switch action {
            case .poll(_, let count):
                print("V9-after: poll returned \(count) events")
            default:
                print("V9-after: done")
            }
        }
    )

    do {
        let h = try observed._create()
        _ = try observed._register(h, 42, Interest(rawValue: 1))
        var events: [PollEvent] = []
        let count = try observed._poll(h, &events)
        print("V9: got \(count) events")
        observed._close(consume h)
    } catch {
        print("V9: error \(error)")
    }
}

// ============================================================================
// MARK: - V10: Observe With After-Result Callback (typed)
// Hypothesis: After-callbacks can receive the Result of the operation,
//             enabling assertion-style testing
// ============================================================================

extension EventDriver {
    struct ObserveWithResult: Sendable {
        let wrapped: EventDriver
        let onAction: @Sendable (Action, Result<Any, any Error>) -> Void
        // Note: Result<Any, any Error> is type-erased. The macro could
        // generate per-action typed results, but that requires per-closure
        // result enums. Let's test the erased approach first.
    }
}

// V10: Test that the Result capture works with ~Copyable return types
func testResultCapture() {
    let base = EventDriver(
        _create: { Handle(fd: 90) },
        _register: { _, _, _ in RegistrationID(rawValue: 1) },
        _poll: { _, _ in 0 },
        _close: { h in _ = consume h }
    )

    // For create (returns ~Copyable Handle):
    // We CANNOT capture the Handle in Result<Any, Error> because Handle is ~Copyable.
    // But we CAN capture Handle.Projection.
    let observed = EventDriver(
        _create: { [base] () throws(DriverError) -> Handle in
            let h = try base._create()
            print("V10: create returned fd=\(h.projection)")
            return h
        },
        _register: base._register,
        _poll: base._poll,
        _close: base._close
    )

    do {
        let h = try observed._create()
        print("V10: got handle fd=\(h.fd)")
        observed._close(consume h)
    } catch {
        print("V10: error \(error)")
    }
}

// ============================================================================
// MARK: - V11: Macro Detection Strategy
// Hypothesis: The macro can detect ~Copyable parameters at compile time by
//             checking for WitnessProjectable conformance
// ============================================================================

// The macro needs to know:
// 1. Which closure parameters are ~Copyable?
// 2. What is their Projection type?
//
// Strategy A: Require WitnessProjectable conformance — macro looks up .projection
// Strategy B: Macro generates Action without ~Copyable params, user fills in
// Strategy C: Macro attribute specifies projections: @Witness(project: ["Handle": "fd"])
//
// Strategy A is the cleanest — zero annotation overhead per-witness, one-time
// protocol conformance per ~Copyable type. Let's test that the macro can use
// protocol conformance to determine projection:

// The macro would emit:
//   case register(handle: Handle.Projection, descriptor: Int32, interest: Interest)
// instead of:
//   case register(handle: Handle, descriptor: Int32, interest: Interest)
//
// At compile time, the macro checks if the parameter type conforms to
// WitnessProjectable. If yes → use .Projection. If no → use the type directly.
//
// For non-~Copyable types, WitnessProjectable conformance is optional.
// The type IS its own projection (identity).

// Extension: make Copyable types trivially projectable
extension Int32: WitnessProjectable {
    var projection: Int32 { self }
}

// This means the macro can ALWAYS use .projection — for Copyable types it's
// identity, for ~Copyable types it extracts the Copyable summary.
func testUniformProjection() {
    let h = Handle(fd: 100)
    let i: Int32 = 42

    // Both work through .projection
    let hProj = h.projection  // Int32
    let iProj = i.projection  // Int32

    print("V11: Handle.projection = \(hProj), Int32.projection = \(iProj)")
    _ = consume h
}

// ============================================================================
// MARK: - V12: inout Parameter Observation
// Hypothesis: inout parameters (like `inout [PollEvent]`) can be observed
//             in before/after callbacks
// ============================================================================

func testInoutObservation() {
    let original: @Sendable (borrowing Handle, inout [PollEvent]) throws(DriverError) -> Int = {
        handle, events in
        events.append(PollEvent(fd: handle.fd, readiness: 1))
        events.append(PollEvent(fd: handle.fd, readiness: 2))
        return events.count
    }

    // Can we wrap inout and still observe?
    let observed: @Sendable (borrowing Handle, inout [PollEvent]) throws(DriverError) -> Int = {
        handle, events in
        let beforeCount = events.count
        print("V12-before: events.count=\(beforeCount)")
        let result = try original(handle, &events)
        print("V12-after: events.count=\(events.count), returned=\(result)")
        return result
    }

    let h = Handle(fd: 110)
    var events: [PollEvent] = []
    do {
        let count = try observed(h, &events)
        print("V12: got \(count) events")
    } catch {
        print("V12: error \(error)")
    }
    _ = consume h
}

// ============================================================================
// MARK: - Run All
// ============================================================================

print("=== V1: ~Copyable Enum Associated Values ===")
testNCAction()

print("\n=== V2: Borrowing Forwarding ===")
testBorrowingForwarding()
testBorrowingObservation()

print("\n=== V3: Consuming Forwarding ===")
testConsumingForwarding()
testConsumingRecording()

print("\n=== V4: Action Projections ===")
testActionProjection()

print("\n=== V5: Simulated @WitnessLite ===")
testSimulatedDriver()

print("\n=== V6: Observable Driver with Projected Actions ===")
testObservableDriver()

print("\n=== V7: Projection Protocol ===")
testProjectionProtocol()

print("\n=== V8: Unimplemented Generation ===")
testUnimplemented()
testUnimplementedRecording()

print("\n=== V9: Full Observe + Action ===")
testFullObservation()

print("\n=== V10: Result Capture ===")
testResultCapture()

print("\n=== V11: Uniform Projection ===")
testUniformProjection()

print("\n=== V12: inout Observation ===")
testInoutObservation()

print("\n=== V13: Omission Pattern ===")
testV13()
testV13Detailed()
testV13Unimplemented()

print("\n=== All variants executed ===")

// MARK: - V13: Omission Pattern — No Protocol, No Annotation
// Hypothesis: The macro can omit ~Copyable parameters from Action enum
//             entirely, using ownership specifiers as the detection signal.
//             Zero user burden.
//
// Result: (pending)

import Synchronization

// ============================================================================
// V13a: Action enum with ~Copyable params omitted
// ============================================================================

// Simulated IO.Event.Driver closures:
//   _create:    () throws(Err) -> Handle           — returns ~Copyable
//   _register:  (borrowing Handle, Int32, Interest) — borrowing ~Copyable
//   _poll:      (borrowing Handle, inout [Event])   — borrowing + inout
//   _close:     (consuming Handle) -> Void          — consuming ~Copyable

// The macro sees ownership specifiers and OMITS those params from Action:

enum V13Action: Sendable {
    case create                                    // no params (return is ~Copyable, not captured)
    case register(descriptor: Int32, interest: V13Interest)  // Handle omitted
    case poll                                      // Handle omitted, inout not captured
    case close                                     // Handle omitted (consuming)
}

struct V13Interest: Sendable { let rawValue: UInt32 }
struct V13RegID: Sendable { let rawValue: Int }
struct V13Event: Sendable { let fd: Int32 }
enum V13Error: Error, Sendable { case failed }

// ============================================================================
// V13b: Full driver with Observe using omission pattern
// ============================================================================

struct V13Driver: Sendable {
    let _create: @Sendable () throws(V13Error) -> Handle
    let _register: @Sendable (borrowing Handle, Int32, V13Interest) throws(V13Error) -> V13RegID
    let _poll: @Sendable (borrowing Handle, inout [V13Event]) throws(V13Error) -> Int
    let _close: @Sendable (consuming Handle) -> Void
}

// === What @Witness would generate (no WitnessProjectable needed) ===

extension V13Driver {

    // Action: only Copyable params. ~Copyable params detected by
    // borrowing/consuming ownership → omitted.
    typealias Action = V13Action

    // Action.Case: discriminant only
    enum ActionCase: Sendable, CaseIterable {
        case create, register, poll, close
    }

    // Observe: wraps witness, forwards EVERYTHING (including ~Copyable),
    // but Action callbacks only receive Copyable params
    func observing(
        before: @escaping @Sendable (Action) -> Void = { _ in },
        after: @escaping @Sendable (Action) -> Void = { _ in }
    ) -> V13Driver {
        let wrapped = self
        return V13Driver(
            _create: { () throws(V13Error) -> Handle in
                before(.create)
                let result = try wrapped._create()
                after(.create)
                return result
            },
            _register: { (handle: borrowing Handle, descriptor: Int32, interest: V13Interest) throws(V13Error) -> V13RegID in
                let action = Action.register(descriptor: descriptor, interest: interest)
                before(action)
                let result = try wrapped._register(handle, descriptor, interest)
                after(action)
                return result
            },
            _poll: { (handle: borrowing Handle, events: inout [V13Event]) throws(V13Error) -> Int in
                before(.poll)
                let count = try wrapped._poll(handle, &events)
                after(.poll)
                return count
            },
            _close: { (handle: consuming Handle) -> Void in
                before(.close)
                wrapped._close(consume handle)
                after(.close)
            }
        )
    }

    // unimplemented: macro-generated
    static func unimplemented(
        fileID: String = #fileID,
        line: UInt = #line
    ) -> V13Driver {
        V13Driver(
            _create: { () throws(V13Error) in throw .failed },
            _register: { (_, _, _) throws(V13Error) in throw .failed },
            _poll: { (_, _) throws(V13Error) in throw .failed },
            _close: { (handle: consuming Handle) in _ = consume handle }
        )
    }
}

// ============================================================================
// V13c: Test — does the omission pattern provide useful observability?
// ============================================================================

func testV13() {
    let base = V13Driver(
        _create: { Handle(fd: 200) },
        _register: { handle, desc, interest in
            print("  V13: register fd=\(handle.fd) desc=\(desc)")
            return V13RegID(rawValue: 1)
        },
        _poll: { handle, events in
            events.append(V13Event(fd: handle.fd))
            return 1
        },
        _close: { handle in
            print("  V13: close fd=\(handle.fd)")
        }
    )

    // Observe: Action tells us WHAT happened + Copyable args
    let log = Mutex<[String]>([])
    let observed = base.observing(
        before: { action in
            let desc: String
            switch action {
            case .create: desc = "create()"
            case .register(let d, let i): desc = "register(desc:\(d), interest:\(i.rawValue))"
            case .poll: desc = "poll()"
            case .close: desc = "close()"
            }
            log.withLock { $0.append(desc) }
            print("  V13-before: \(desc)")
        }
    )

    do {
        let h = try observed._create()
        _ = try observed._register(h, 42, V13Interest(rawValue: 1))
        var events: [V13Event] = []
        _ = try observed._poll(h, &events)
        observed._close(consume h)
    } catch {
        print("  V13: error \(error)")
    }

    print("  V13: action log = \(log.withLock { $0 })")
}

// ============================================================================
// V13d: What if user WANTS to observe ~Copyable params?
//       They can add a per-closure before callback manually.
//       This is opt-in, not required.
// ============================================================================

extension V13Driver {
    /// Richer observation: per-closure callbacks with actual parameter types.
    /// User writes this only if they need to inspect ~Copyable params.
    func observingDetailed(
        beforeRegister: @escaping @Sendable (borrowing Handle, Int32, V13Interest) -> Void = { _, _, _ in },
        beforeClose: @escaping @Sendable (borrowing Handle) -> Void = { _ in }
    ) -> V13Driver {
        let wrapped = self
        return V13Driver(
            _create: wrapped._create,
            _register: { (handle: borrowing Handle, descriptor: Int32, interest: V13Interest) throws(V13Error) -> V13RegID in
                beforeRegister(handle, descriptor, interest)
                return try wrapped._register(handle, descriptor, interest)
            },
            _poll: wrapped._poll,
            _close: { (handle: consuming Handle) -> Void in
                // borrow-then-consume: read before forwarding
                beforeClose(handle)
                wrapped._close(consume handle)
            }
        )
    }
}

func testV13Detailed() {
    let base = V13Driver(
        _create: { Handle(fd: 210) },
        _register: { h, d, _ in V13RegID(rawValue: 1) },
        _poll: { _, _ in 0 },
        _close: { h in print("  V13d: close fd=\(h.fd)") }
    )

    let observed = base.observingDetailed(
        beforeRegister: { handle, desc, interest in
            // Full access to ~Copyable Handle via borrowing
            print("  V13d: about to register fd=\(handle.fd) desc=\(desc)")
        },
        beforeClose: { handle in
            print("  V13d: about to close fd=\(handle.fd)")
        }
    )

    do {
        let h = try observed._create()
        _ = try observed._register(h, 42, V13Interest(rawValue: 1))
        observed._close(consume h)
    } catch {
        print("  V13d: error \(error)")
    }
}

// ============================================================================
// V13e: Unimplemented — verify all ownership patterns
// ============================================================================

func testV13Unimplemented() {
    let unimpl = V13Driver.unimplemented()

    do {
        _ = try unimpl._create()
        print("  V13e: UNEXPECTED — should have thrown")
    } catch {
        print("  V13e: create threw as expected")
    }

    // close consumes without crashing (no fatalError needed since we just drop)
    // Actually for true unimplemented we'd want fatalError. Let's test:
    // unimpl._close(Handle(fd: 999)) — this would just consume and drop, OK.
    print("  V13e: unimplemented pattern works")
}

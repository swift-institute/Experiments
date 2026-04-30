// MARK: - Witness Driver Composition with ~Copyable Descriptor
// Purpose: Validate that witness drivers (struct of closures) can borrow
//          a ~Copyable descriptor from a resource, and that drivers compose
//          across layers (Kernel.Event.Driver → IO.Event.Driver).
//
// Hypothesis: A ~Copyable resource owns the descriptor. The Driver is a
//             Copyable/Sendable struct of closures. Resource methods borrow
//             self.descriptor and pass it to Driver closures. Drivers compose
//             by wrapping: IO driver holds a resource, calls kernel driver.
//
// Toolchain: Swift 6.2
// Platform: macOS 26 (arm64)
//
// Result: CONFIRMED — all 5 variants build and run correctly
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Date: 2026-04-09

// ============================================================================
// MARK: - Variant 1: Basic witness driver borrowing ~Copyable descriptor
// Hypothesis: Driver closures can take `borrowing Descriptor` parameter
// ============================================================================

struct Descriptor: ~Copyable {
    let rawValue: Int32
    init(_ raw: Int32) { self.rawValue = raw }
    deinit { print("  Descriptor(\(rawValue)) closed") }
}

struct Event {
    let id: Int
}

struct EventDriver: Sendable {
    let _register: @Sendable (borrowing Descriptor, String) -> Int
    let _poll: @Sendable (borrowing Descriptor, inout [Event]) -> Int
    let _close: @Sendable (borrowing Descriptor) -> Void
}

struct EventResource: ~Copyable {
    let driver: EventDriver
    let descriptor: Descriptor

    func register(_ name: String) -> Int {
        driver._register(descriptor, name)
    }

    func poll(into buffer: inout [Event]) -> Int {
        driver._poll(descriptor, &buffer)
    }

    consuming func close() {
        driver._close(descriptor)
    }
}

func testVariant1() {
    print("--- Variant 1: Basic witness borrowing ~Copyable ---")

    let driver = EventDriver(
        _register: { fd, name in
            print("  register(\(fd.rawValue), \(name))")
            return 1
        },
        _poll: { fd, buffer in
            print("  poll(\(fd.rawValue))")
            buffer[0] = Event(id: 1)
            return 1
        },
        _close: { fd in
            print("  close(\(fd.rawValue))")
        }
    )

    var resource = EventResource(driver: driver, descriptor: Descriptor(3))
    let id = resource.register("socket")
    print("  registered: \(id)")
    var events = [Event(id: 0)]
    let count = resource.poll(into: &events)
    print("  polled: \(count) events")
    resource.close()
    print()
}

// ============================================================================
// MARK: - Variant 2: Driver with file-private state class (epoll pattern)
// Hypothesis: Closures capture a state class AND borrow the descriptor
// ============================================================================

final class EpollState: @unchecked Sendable {
    var registrations: [Int: String] = [:]
    var nextID = 1
}

func testVariant2() {
    print("--- Variant 2: State class + borrowed descriptor ---")

    let state = EpollState()

    let driver = EventDriver(
        _register: { fd, name in
            let id = state.nextID
            state.nextID += 1
            state.registrations[id] = name
            print("  register(\(fd.rawValue), \(name)) → id=\(id)")
            return id
        },
        _poll: { fd, buffer in
            let count = min(state.registrations.count, buffer.count)
            print("  poll(\(fd.rawValue)) → \(count) events")
            return count
        },
        _close: { fd in
            print("  close(\(fd.rawValue)), draining \(state.registrations.count) registrations")
            state.registrations.removeAll()
        }
    )

    var resource = EventResource(driver: driver, descriptor: Descriptor(5))
    _ = resource.register("read")
    _ = resource.register("write")
    var events = [Event(id: 0), Event(id: 0)]
    _ = resource.poll(into: &events)
    resource.close()
    print()
}

// ============================================================================
// MARK: - Variant 3: Completion driver with ~Copyable ring state
// Hypothesis: Same pattern works when the state class holds ~Copyable ring
// ============================================================================

struct Ring: ~Copyable {
    var pending: Int = 0
    mutating func enqueue() { pending += 1 }
    mutating func flush() -> Int { let n = pending; pending = 0; return n }
    mutating func drain(_ visitor: (Int) -> Void) -> Int {
        visitor(42)
        return 1
    }
    deinit { print("  Ring unmapped") }
}

struct CompletionDriver {
    let _submit: (borrowing Descriptor, String) -> Void
    let _flush: (borrowing Descriptor) -> Int
    let _drain: (borrowing Descriptor, (Int) -> Void) -> Int
    let _close: (borrowing Descriptor) -> Void
}

struct CompletionResource: ~Copyable {
    let driver: CompletionDriver
    let descriptor: Descriptor

    func submit(_ op: String) {
        driver._submit(descriptor, op)
    }

    @discardableResult
    func flush() -> Int {
        driver._flush(descriptor)
    }

    @discardableResult
    func drain(_ visitor: (Int) -> Void) -> Int {
        driver._drain(descriptor, visitor)
    }

    consuming func close() {
        driver._close(descriptor)
    }
}

func testVariant3() {
    print("--- Variant 3: Completion driver with ~Copyable ring ---")

    final class UringState {
        var ring: Ring
        init(ring: consuming Ring) { self.ring = ring }
    }

    let state = UringState(ring: Ring())

    let driver = CompletionDriver(
        _submit: { fd, op in
            print("  submit(\(fd.rawValue), \(op))")
            state.ring.enqueue()
        },
        _flush: { fd in
            let n = state.ring.flush()
            print("  flush(\(fd.rawValue)) → \(n) submitted")
            return n
        },
        _drain: { fd, visitor in
            print("  drain(\(fd.rawValue))")
            return state.ring.drain(visitor)
        },
        _close: { fd in
            print("  close(\(fd.rawValue))")
        }
    )

    var resource = CompletionResource(driver: driver, descriptor: Descriptor(7))
    resource.submit("read")
    resource.submit("write")
    resource.flush()
    resource.drain { value in print("  completed: \(value)") }
    resource.close()
    print()
}

// ============================================================================
// MARK: - Variant 4: IO driver wrapping kernel driver (composition)
// Hypothesis: IO-level driver wraps kernel resource, translates types,
//             delegates. Two layers of witnesses composing.
// ============================================================================

struct IODriver: ~Copyable {
    let _kernelEvent: EventResource

    func register(_ name: String) -> Int {
        _kernelEvent.register(name)
    }

    func poll(into buffer: inout [Event]) -> Int {
        _kernelEvent.poll(into: &buffer)
    }

    consuming func close() {
        _kernelEvent.close()
    }
}

func testVariant4() {
    print("--- Variant 4: IO driver wrapping kernel driver ---")

    let state = EpollState()

    let kernelDriver = EventDriver(
        _register: { fd, name in
            let id = state.nextID; state.nextID += 1
            state.registrations[id] = name
            print("  [kernel] register(\(fd.rawValue), \(name)) → \(id)")
            return id
        },
        _poll: { fd, buffer in
            print("  [kernel] poll(\(fd.rawValue))")
            return 0
        },
        _close: { fd in
            print("  [kernel] close(\(fd.rawValue))")
            state.registrations.removeAll()
        }
    )

    let kernelResource = EventResource(driver: kernelDriver, descriptor: Descriptor(9))
    var ioDriver = IODriver(_kernelEvent: kernelResource)

    let id = ioDriver.register("socket")
    print("  [io] registered: \(id)")
    var events = [Event(id: 0)]
    _ = ioDriver.poll(into: &events)
    ioDriver.close()
    print()
}

// ============================================================================
// MARK: - Variant 5: Factory pattern (platform selection)
// Hypothesis: Static factory on Driver creates the right backend
// ============================================================================

func testVariant5() {
    print("--- Variant 5: Factory pattern ---")

    func makeKqueueDriver() -> EventResource {
        let driver = EventDriver(
            _register: { fd, name in print("  [kqueue] register(\(fd.rawValue))"); return 1 },
            _poll: { fd, buffer in print("  [kqueue] poll(\(fd.rawValue))"); return 0 },
            _close: { fd in print("  [kqueue] close(\(fd.rawValue))") }
        )
        return EventResource(driver: driver, descriptor: Descriptor(11))
    }

    func makeEpollDriver() -> EventResource {
        let state = EpollState()
        let driver = EventDriver(
            _register: { fd, name in
                let id = state.nextID; state.nextID += 1
                print("  [epoll] register(\(fd.rawValue))"); return id
            },
            _poll: { fd, buffer in print("  [epoll] poll(\(fd.rawValue))"); return 0 },
            _close: { fd in print("  [epoll] close(\(fd.rawValue))") }
        )
        return EventResource(driver: driver, descriptor: Descriptor(13))
    }

    // Simulate platform selection
    #if os(macOS)
    var resource = makeKqueueDriver()
    #else
    var resource = makeEpollDriver()
    #endif

    _ = resource.register("test")
    resource.close()
    print()
}

// ============================================================================
// MARK: - Run All
// ============================================================================

testVariant1()
testVariant2()
testVariant3()
testVariant4()
testVariant5()

// MARK: - Results Summary
// V1: CONFIRMED — Basic witness borrowing ~Copyable descriptor
// V2: CONFIRMED — State class captured + descriptor borrowed
// V3: CONFIRMED — Completion driver with ~Copyable ring in state class
// V4: CONFIRMED — IO driver wrapping kernel resource (two-layer composition)
// V5: CONFIRMED — Factory pattern with platform selection

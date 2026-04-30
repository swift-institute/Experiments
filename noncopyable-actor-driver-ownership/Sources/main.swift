// MARK: - ~Copyable Actor Driver Ownership
// Purpose: Can an actor store a ~Copyable property? Can it call methods on it?
//          Can actor methods replace the fire-and-forget request queue for rearm?
//
// Context: IO.Event.Loop (Phase 3) keeps a request queue (Mutex<Deque>) because
//          the plan assumed actors can't own ~Copyable values. If they CAN, the
//          actor (Runtime) can own the driver directly. Actor methods replace the
//          request queue for register/deregister/arm. The queue reduces to just
//          emergency deinit cleanup.
//
// Toolchain: Xcode 26 beta / Swift 6.3
// Platform:  macOS 26 (arm64)
//
// Result: ALL CONFIRMED (V1–V6) — key insights:
//   - Actors CAN own ~Copyable stored properties (via Optional<T> for consuming methods)
//   - UnsafeMutablePointer<~Copyable> fully works: allocate, initialize(to:), pointee, move, deallocate
//   - Executor-owned driver via pointer enables BOTH sync run loop AND actor method access
//   - Channel.arm() (async) can await actor.arm() — eliminates request queue for arm
//   - Channel.deinit (sync) can use Task{} but introduces cooperative pool dependency
// Date:   2026-04-07

// ==========================================================================
// MARK: - V1: Actor with ~Copyable stored property
// Hypothesis: An actor CAN have a ~Copyable stored property
// Result: CONFIRMED
// ==========================================================================

struct Resource: ~Copyable {
    var value: Int
    consuming func close() { print("  Resource.close() called, value=\(value)") }
}

actor Owner {
    var resource: Resource

    init(resource: consuming Resource) {
        self.resource = resource
    }

    func read() -> Int {
        resource.value
    }

    func mutate() {
        resource.value += 1
    }
}

// ==========================================================================
// MARK: - V2: Actor with ~Copyable property calling consuming methods
// Hypothesis: An actor method can call consuming methods on its ~Copyable field
// Result: CONFIRMED
// ==========================================================================

struct Driver: ~Copyable {
    var fd: Int32

    func register(id: Int) -> Int {
        print("  Driver.register(id: \(id)) on fd=\(fd)")
        return id * 10
    }

    func arm(id: Int) {
        print("  Driver.arm(id: \(id)) on fd=\(fd)")
    }

    consuming func close() {
        print("  Driver.close() fd=\(fd)")
    }
}

actor Runtime {
    // Optional wrapping: actor can't consume a field without reinitializing.
    // Optional<~Copyable> allows .take() → consume + set nil.
    var driver: Driver?

    init(driver: consuming Driver) {
        self.driver = consume driver
    }

    func register(id: Int) -> Int {
        driver!.register(id: id)
    }

    func arm(id: Int) {
        driver!.arm(id: id)
    }

    func shutdown() {
        driver.take()!.close()
    }
}

// ==========================================================================
// MARK: - V3: Actor pinned to custom executor with ~Copyable property
// Hypothesis: nonisolated var unownedExecutor + ~Copyable stored property works
// Result: CONFIRMED
// ==========================================================================

final class SimpleExecutor: SerialExecutor, @unchecked Sendable {
    func enqueue(_ job: UnownedJob) {
        // Run inline for simplicity
        unsafe job.runSynchronously(on: asUnownedSerialExecutor())
    }

    func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        unsafe UnownedSerialExecutor(ordinary: self)
    }
}

actor PinnedRuntime {
    let executor: SimpleExecutor
    var driver: Driver

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        executor.asUnownedSerialExecutor()
    }

    init(executor: SimpleExecutor, driver: consuming Driver) {
        self.executor = executor
        self.driver = driver
    }

    func register(id: Int) -> Int {
        driver.register(id: id)
    }

    func arm(id: Int) {
        driver.arm(id: id)
    }
}

// ==========================================================================
// MARK: - V4: Async rearm through actor (replacing fire-and-forget queue)
// Hypothesis: Channel.arm() (async) can call actor.arm() directly — no queue needed
// Result: CONFIRMED
// ==========================================================================

// Simulates the Channel.arm() → Runtime.arm() path
// Channel.arm() is async, so it CAN await an actor method
func simulateChannelArm(runtime: PinnedRuntime, id: Int) async {
    // This is what Channel.arm() would do instead of submit(.arm)
    await runtime.arm(id: id)
    print("  Channel arm completed for id=\(id)")
}

// ==========================================================================
// MARK: - V5: Sync deinit fire-and-forget — the irreducible problem
// Hypothesis: Task{} can bridge sync deinit to async actor methods, but
//             introduces cooperative pool dependency on the emergency path
// Result: CONFIRMED (works, but reintroduces coop pool for emergency cleanup)
// ==========================================================================

// Channel.deinit is synchronous. It currently does:
//   executor.submit(.deregister(id: id, waiter: nil))
// Can we avoid the request queue here?

// Option A: Task {} in deinit — creates unstructured task
func simulateDeinitWithTask(runtime: PinnedRuntime, id: Int) {
    // This is what deinit would need to do
    Task {
        await runtime.arm(id: id)  // works, but unstructured task on coop pool
    }
    print("  Deinit fire-and-forget via Task{} for id=\(id)")
}

// ==========================================================================
// MARK: - V6: UnsafeMutablePointer<~Copyable> for executor-owned driver
// Hypothesis: UnsafeMutablePointer<Driver> where Driver: ~Copyable works —
//             allocate, initialize(to: consuming), pointee (inout), deallocate.
//             This enables BOTH sync run loop access AND async actor access,
//             since the pointer is stored on the executor (shared).
// Result: CONFIRMED
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// ==========================================================================

final class SharedStorage {
    let driverPtr: UnsafeMutablePointer<Driver>

    init(driver: consuming Driver) {
        let ptr = UnsafeMutablePointer<Driver>.allocate(capacity: 1)
        ptr.initialize(to: consume driver)
        self.driverPtr = ptr
    }

    // Sync method — callable from a run loop (not async)
    func callRegisterSync(id: Int) -> Int {
        driverPtr.pointee.register(id: id)
    }

    func callArmSync(id: Int) {
        driverPtr.pointee.arm(id: id)
    }

    func consumeDriverAndClose() {
        let driver = driverPtr.move()
        driver.close()
    }

    deinit {
        driverPtr.deallocate()
    }
}

// ==========================================================================
// MARK: - Run
// ==========================================================================

@main
struct Main {
    static func main() async {
        print("V1: Actor with ~Copyable stored property")
        let owner = Owner(resource: Resource(value: 42))
        let v = await owner.read()
        print("  Read value: \(v)")
        await owner.mutate()
        let v2 = await owner.read()
        print("  After mutate: \(v2)")
        print("  V1: \(v == 42 && v2 == 43 ? "CONFIRMED" : "REFUTED")")

        print("")
        print("V2: Actor calling methods on ~Copyable field")
        let runtime = Runtime(driver: Driver(fd: 7))
        let result = await runtime.register(id: 5)
        await runtime.arm(id: 5)
        print("  Register result: \(result)")
        print("  V2: \(result == 50 ? "CONFIRMED" : "REFUTED")")

        print("")
        print("V3: Pinned actor with ~Copyable property")
        let executor = SimpleExecutor()
        let pinned = PinnedRuntime(executor: executor, driver: Driver(fd: 9))
        let r3 = await pinned.register(id: 3)
        await pinned.arm(id: 3)
        print("  Register result: \(r3)")
        print("  V3: \(r3 == 30 ? "CONFIRMED" : "REFUTED")")

        print("")
        print("V4: Async rearm through actor")
        await simulateChannelArm(runtime: pinned, id: 42)
        print("  V4: CONFIRMED (compiled and ran)")

        print("")
        print("V5: Sync deinit fire-and-forget")
        simulateDeinitWithTask(runtime: pinned, id: 99)
        // Give the task time to execute
        try? await Task.sleep(for: .milliseconds(50))
        print("  V5: CONFIRMED (Task{} works but creates unstructured task)")

        print("")
        print("V6: UnsafeMutablePointer<~Copyable> for shared driver access")
        let shared = SharedStorage(driver: Driver(fd: 11))
        let r6a = shared.callRegisterSync(id: 7)
        shared.callArmSync(id: 7)
        print("  Sync register result: \(r6a)")
        shared.consumeDriverAndClose()
        print("  V6: \(r6a == 70 ? "CONFIRMED" : "REFUTED")")

        print("")
        print("=== SUMMARY ===")
        print("V1: Actor + ~Copyable stored property: compiles and runs")
        print("V2: Actor methods on ~Copyable field: direct call works")
        print("V3: Pinned actor + ~Copyable: executor + driver coexist")
        print("V4: Async rearm via actor: eliminates request queue for arm")
        print("V5: Sync deinit: still needs sync mechanism (Task{} or queue)")
    }
}

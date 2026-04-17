import Synchronization

public final class Loop: SerialExecutor, @unchecked Sendable {
    public init() {}

    public func enqueue(_ job: UnownedJob) {
        unsafe job.runSynchronously(on: asUnownedSerialExecutor())
    }

    public func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        unsafe UnownedSerialExecutor(ordinary: self)
    }
}

public struct Err: Error {
    public let id: Int
    public init(_ id: Int) { self.id = id }
}

public actor Runtime {
    public let executor: Loop
    private var state: State = .running

    nonisolated public var unownedExecutor: UnownedSerialExecutor {
        executor.asUnownedSerialExecutor()
    }

    public init(executor: Loop) { self.executor = executor }

    enum State { case running, shuttingDown }

    public func register() throws(Err) {
        guard state == .running else { throw Err(1) }
        throw Err(2)
    }

    public func shutdown() async {
        state = .shuttingDown
    }
}

public struct Selector: Sendable {
    public let runtime: Runtime
    public init(runtime: Runtime) { self.runtime = runtime }

    public func register() async throws(Err) {
        try await runtime.register()
    }
}

public struct Scope: ~Copyable {
    public let selector: Selector
    private let _token: Mutex<Bool>

    public init() {
        let executor = Loop()
        let runtime = Runtime(executor: executor)
        self.selector = Selector(runtime: runtime)
        self._token = Mutex(false)
    }

    public consuming func close() async {
        await selector.runtime.shutdown()
    }

}

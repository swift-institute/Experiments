//
// IO.Runner.swift — scheduling evidence + lifecycle witness.
//
// Hand-written struct of closures (was @Witness-generated).
//

extension IO {
    public struct Runner {
        public let executor: () -> UnownedSerialExecutor
        public let shutdown: () async -> Void

        public init(
            executor: @escaping () -> UnownedSerialExecutor,
            shutdown: @escaping () async -> Void
        ) {
            self.executor = executor
            self.shutdown = shutdown
        }
    }
}

extension IO.Runner {
    public static func unimplemented() -> IO.Runner {
        IO.Runner(
            executor: { fatalError("IO.Runner.executor unimplemented") },
            shutdown: { fatalError("IO.Runner.shutdown unimplemented") }
        )
    }
}

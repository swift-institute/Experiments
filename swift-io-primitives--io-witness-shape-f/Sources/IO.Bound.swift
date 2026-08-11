//
// IO.Bound.swift — plain struct composing the IO capability witness with its Runner.
// Not a witness itself: no protocol, no existential.
//

extension IO {
    public struct Bound {
        public let io: IO
        public let runner: IO.Runner
        public init(io: IO, runner: IO.Runner) {
            self.io = io
            self.runner = runner
        }
    }
}

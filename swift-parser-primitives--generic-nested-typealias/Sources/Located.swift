// Generic struct — using Swift.Error explicitly everywhere
extension Parser.Error {
    public struct Located<E: Swift.Error & Sendable>: Swift.Error, Sendable {
        public let error: E
        public let offset: Int
    }
}

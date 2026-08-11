//
// IO.Free combinators — map, flatMap, mapError. All structural rebuilds
// of the program tree; cost is O(depth) per call. This is the well-
// known free-monad performance characteristic. Production swift-io uses
// the dictionary encoding (current `IO` witness) for hot-path code.
//

extension IO.Free {

    public func map<NewValue: Sendable>(
        _ transform: @Sendable @escaping (Value) -> NewValue
    ) -> IO.Free<NewValue, Failure> {
        flatMap { value in .pure(transform(value)) }
    }

    public func flatMap<NewValue: Sendable>(
        _ transform: @Sendable @escaping (Value) -> IO.Free<NewValue, Failure>
    ) -> IO.Free<NewValue, Failure> {
        switch self {
        case .pure(let value):
            return transform(value)
        case .fail(let error):
            return .fail(error)
        case .readOp(let descriptor, let buffer, let continuation):
            return .readOp(from: descriptor, into: buffer) { bytes in
                continuation(bytes).flatMap(transform)
            }
        case .writeOp(let descriptor, let buffer, let continuation):
            return .writeOp(to: descriptor, from: buffer) { bytes in
                continuation(bytes).flatMap(transform)
            }
        case .closeOp(let descriptor, let continuation):
            return .closeOp(descriptor: descriptor) {
                continuation().flatMap(transform)
            }
        case .readyOp(let descriptor, let interest, let continuation):
            return .readyOp(from: descriptor, interest: interest) {
                continuation().flatMap(transform)
            }
        }
    }

    public func mapError<NewFailure: Swift.Error & Sendable>(
        _ transform: @Sendable @escaping (Failure) -> NewFailure
    ) -> IO.Free<Value, NewFailure> {
        switch self {
        case .pure(let value):
            return .pure(value)
        case .fail(let error):
            return .fail(transform(error))
        case .readOp(let descriptor, let buffer, let continuation):
            return .readOp(from: descriptor, into: buffer) { bytes in
                continuation(bytes).mapError(transform)
            }
        case .writeOp(let descriptor, let buffer, let continuation):
            return .writeOp(to: descriptor, from: buffer) { bytes in
                continuation(bytes).mapError(transform)
            }
        case .closeOp(let descriptor, let continuation):
            return .closeOp(descriptor: descriptor) {
                continuation().mapError(transform)
            }
        case .readyOp(let descriptor, let interest, let continuation):
            return .readyOp(from: descriptor, interest: interest) {
                continuation().mapError(transform)
            }
        }
    }
}

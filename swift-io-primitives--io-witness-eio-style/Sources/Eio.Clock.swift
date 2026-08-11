// Eio.Clock — sub-capability for monotonic time. Hand-written struct of
// closures (was @Witness-generated).
//
// The zero-arg closure `now` is invoked directly as `clock.now()` (closure-
// call on the property).

extension Eio {
    public struct Clock: Sendable {
        public let now: @Sendable () -> UInt64

        public init(now: @Sendable @escaping () -> UInt64) {
            self.now = now
        }
    }
}

extension Eio.Clock {
    public static func unimplemented() -> Eio.Clock {
        Eio.Clock(now: { fatalError("Eio.Clock.now unimplemented") })
    }
}

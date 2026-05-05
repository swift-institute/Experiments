// L1 owns nothing concrete in this experiment beyond namespace anchors —
// the data type lives at L2 (where the spec authority lives), and the
// L3-unifier flip points cross-platform `Kernel.*` at the L3-policy type.

public enum Kernel {}
extension Kernel { public enum File {} }

public enum FooError: Error, Sendable, Equatable {
    case interrupted   // simulates EINTR
    case failed
}

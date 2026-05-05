// L1 owns nothing concrete in this experiment beyond namespace anchors —
// the data + L2 operation lives at L2 (where the spec authority lives),
// and L3 wraps it via Tagged with the L3 namespace as the phantom tag.

public enum Kernel {}
extension Kernel { public enum File {} }

public enum FooError: Error, Sendable, Equatable {
    case interrupted
    case failed
}

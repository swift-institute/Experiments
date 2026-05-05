// L1 owns nothing concrete in this experiment — the L2 spec namespace and
// the L3 policy namespace are distinct top-level identifiers, each owning
// their own type definitions. L1 is the namespace-anchor for shared concepts
// (Kernel) only.
public enum Kernel {}
public enum File {}

public enum FooError: Error, Sendable {
    case failed
}

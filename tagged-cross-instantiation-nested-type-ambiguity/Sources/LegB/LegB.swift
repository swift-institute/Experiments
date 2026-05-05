// MARK: - Leg B: Second constrained-extension nested typealias
// Mirrors the proposed approach 12+13 shape at swift-posix: a constrained
// extension on Tagged with where Tag == TagB, RawValue == RawB declaring
// nested typealias Error with the SAME name as LegA's, but disjoint
// where-clause.

public import TaggedCore

extension Tagged where Tag == TagB, RawValue == RawB {
    public typealias Error = NestedBError
}

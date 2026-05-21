// Variant: does the Property-accessor pattern work for a value-returning
// verb (`map`) where both the Property bridge AND stdlib's inherited
// `Sequence.map` return `[T]`?
//
// Hypothesis: Swift's overload resolution disambiguates by `throws(E)`
// vs `rethrows`, not just by void-vs-value return shape. If forEach
// works, map should too — but the return-value shape is a genuinely
// different empirical question.

public import Property_Primitives

extension Swift.Range where Bound: Strideable, Bound.Stride: SignedInteger {
    public enum Map {}

    public var map: Property<Map, Self> {
        Property(self)
    }
}

extension Property {
    public func callAsFunction<Bound: Strideable, T, E: Swift.Error>(
        _ transform: (Bound) throws(E) -> T
    ) throws(E) -> [T]
    where Bound.Stride: SignedInteger,
          Tag == Swift.Range<Bound>.Map,
          Base == Swift.Range<Bound>
    {
        var result: [T] = []
        result.reserveCapacity(base.count)
        var i = base.lowerBound
        while i < base.upperBound {
            result.append(try transform(i))
            i = i.advanced(by: 1)
        }
        return result
    }
}

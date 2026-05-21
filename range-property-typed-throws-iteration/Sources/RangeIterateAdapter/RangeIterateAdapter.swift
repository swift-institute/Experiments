// The adapter under test, declared in a separate library target so the
// executable target imports it across a module boundary per [EXP-017].

public import Property_Primitives

extension Swift.Range where Bound: Strideable, Bound.Stride: SignedInteger {
    public enum Iterate {}

    public var iterate: Property<Iterate, Self> {
        Property(self)
    }
}

extension Property {
    public func callAsFunction<Bound: Strideable, E: Swift.Error>(
        _ body: (Bound) throws(E) -> Void
    ) throws(E)
    where Bound.Stride: SignedInteger,
          Tag == Swift.Range<Bound>.Iterate,
          Base == Swift.Range<Bound>
    {
        var i = base.lowerBound
        while i < base.upperBound {
            try body(i)
            i = i.advanced(by: 1)
        }
    }
}

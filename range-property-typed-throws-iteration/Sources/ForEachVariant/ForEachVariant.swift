// Variant: can the Property accessor be NAMED `forEach` directly,
// so call sites stay `(0..<n).forEach { ... throws(E) ... }`?
//
// Hypothesis: `var forEach: Property<...>` on Range, alongside stdlib's
// inherited `func forEach(_:) rethrows`, will either:
//   (a) Coexist — typed-throws closures pick the Property; non-throwing or
//       any-Error closures pick stdlib. Best case.
//   (b) Conflict — Swift rejects the redeclaration. Then `.iterate` (or
//       another verb) is needed.
//   (c) Compile but always pick one path — disambiguates trivially.

public import Property_Primitives

extension Swift.Range where Bound: Strideable, Bound.Stride: SignedInteger {
    public enum ForEach {}

    public var forEach: Property<ForEach, Self> {
        Property(self)
    }
}

extension Property {
    public func callAsFunction<Bound: Strideable, E: Swift.Error>(
        _ body: (Bound) throws(E) -> Void
    ) throws(E)
    where Bound.Stride: SignedInteger,
          Tag == Swift.Range<Bound>.ForEach,
          Base == Swift.Range<Bound>
    {
        var i = base.lowerBound
        while i < base.upperBound {
            try body(i)
            i = i.advanced(by: 1)
        }
    }
}

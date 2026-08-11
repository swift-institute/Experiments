// Consumer B wants literal conformance for a DIFFERENT Tagged specialization.

public import TaggedLib

public enum CoordTag {}
public typealias X = Tagged<CoordTag, Double>

// Same pattern, but for a different Tag/RawValue.
// Does Swift allow this alongside ConsumerA's declaration?
extension Tagged: ExpressibleByIntegerLiteral
where Tag == CoordTag, RawValue == Double {
    public init(integerLiteral value: Double.IntegerLiteralType) {
        self.init(__unchecked: (), Double(integerLiteral: value))
    }
}

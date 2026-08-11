// Carrier where Underlying == Self.swift — verbatim mirror of the
// production trivial-self default extension. Whether this default
// suffices for ~Escapable Self is the central empirical question of
// this experiment.

extension Carrier where Underlying == Self {
    public var underlying: Self {
        _read { yield self }
    }

    public init(_ underlying: consuming Self) {
        self = underlying
    }
}

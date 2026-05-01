// MARK: - V6: typed everywhere — feasibility baseline
// Purpose: NO raw access at any layer. The "ideal world" — verify whether
// there are legitimate raw-only use cases that genuinely break under this
// constraint.
//
// Hypothesis: V6 is REFUTED — production code has multiple raw-required
// use cases that no typed API can serve without expanding the typed
// surface to model every such use case (which expands L2 unboundedly).

public struct Descriptor: ~Copyable {
    public let _rawValue: Int32

    public init(_rawValue: Int32) {
        self._rawValue = _rawValue
    }
}

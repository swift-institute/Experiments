// Simulates Kernel.String typealias
//
// KEY: StringLike is imported with `public import` (NOT @_exported).
// The typealias makes the type accessible as `Kernel.String`,
// but bare `String` should NOT be shadowed in downstream modules.

public import StringLike

extension Kernel {
    public typealias String = StringLike.String
}

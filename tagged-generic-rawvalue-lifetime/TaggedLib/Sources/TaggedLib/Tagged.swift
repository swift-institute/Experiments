// Minimal, production-faithful Tagged<Tag, Underlying>.
//
// Mirrors swift-tagged-primitives/Sources/Tagged Primitives/Tagged.swift:54-95:
//   - `underlying` is a STORED property (the load-bearing shape — a computed
//     `_read` accessor cannot recover consume-extract ownership semantics).
//   - `@_lifetime(copy underlying)` on the init.
//   - conditional Copyable / Escapable derived from Underlying.
//
// (Production additionally conforms Tagged: Carrier.`Protocol`, whose
//  `var underlying { borrowing get }` requirement is satisfied by this stored
//  property; accessing `.underlying` through that requirement yields a borrow,
//  which is why production rebuilds spans/views via the base-address detour
//  rather than `underlying.span`. This spike exercises that same detour.)

public struct Tagged<Tag: ~Copyable & ~Escapable, Underlying: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
    public var underlying: Underlying

    @_lifetime(copy underlying)
    public init(_unchecked underlying: consuming Underlying) {
        self.underlying = underlying
    }
}

extension Tagged: Copyable where Tag: ~Copyable & ~Escapable, Underlying: Copyable & ~Escapable {}
extension Tagged: Escapable where Tag: ~Copyable & ~Escapable, Underlying: Escapable & ~Copyable {}

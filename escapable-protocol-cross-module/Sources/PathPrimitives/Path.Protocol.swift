// Path.`Protocol` — nested protocol in a concrete (non-generic) type.
// Declares the decomposition API via static requirements per [IMPL-023].
// Protocol extension defaults provide the instance API per [API-NAME-002].

extension Path {
    public protocol `Protocol`: ~Copyable, ~Escapable {
        associatedtype Char

        /// Parent directory bytes (NOT null-terminated). Nil for roots and bare filenames.
        @_lifetime(copy view)
        static func parent(of view: borrowing Self) -> Span<Char>?

        /// Last component bytes (IS null-terminated — shares original terminator).
        @_lifetime(copy view)
        static func component(of view: borrowing Self) -> Span<Char>

        /// Creates a new owned path: view + separator + other + NUL.
        static func appending(_ view: borrowing Self, _ other: borrowing Self) -> Path
    }
}

// MARK: - Instance API (protocol extension defaults)

extension Path.`Protocol` where Self: ~Copyable, Self: ~Escapable {
    public var parent: Span<Char>? {
        @_lifetime(copy self)
        borrowing get { Self.parent(of: self) }
    }

    public var component: Span<Char> {
        @_lifetime(copy self)
        borrowing get { Self.component(of: self) }
    }

    public borrowing func appending(_ other: borrowing Self) -> Path {
        Self.appending(self, other)
    }
}

// Path.`Protocol` — nested protocol in a concrete (non-generic) type.
// Declares the decomposition API that platform packages conform Path.View to.

extension Path {
    public protocol `Protocol`: ~Copyable, ~Escapable {
        associatedtype Char

        /// Parent directory bytes (NOT null-terminated). Nil for roots and bare filenames.
        var parentBytes: Span<Char>? { @_lifetime(copy self) borrowing get }

        /// Last component bytes (IS null-terminated — shares original terminator).
        var lastComponentBytes: Span<Char> { @_lifetime(copy self) borrowing get }

        /// Creates a new owned path: self + separator + other + NUL.
        borrowing func appending(_ other: borrowing Self) -> Path
    }
}

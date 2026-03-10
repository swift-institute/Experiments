// Middle Buffer Layer — separate PACKAGE from both Element and Container.
// Mirrors production: Buffer.Ring.Inline<capacity> in swift-buffer-primitives.
//
// Key production properties replicated:
// - Generic over Element: ~Copyable (not concrete Tracked)
// - @usableFromInline package var (visibility annotations)
// - @inlinable init
// - Value generic parameter
// - Explicit deinit with cleanup

import Element

// MARK: - Generic Middle (type generic only)

/// Generic over Element: ~Copyable, no value generic.
public struct Middle<Element: ~Copyable>: ~Copyable {
    @usableFromInline
    package var header: Int

    @usableFromInline
    package var element: Element

    @inlinable
    public init(header: Int, element: consuming Element) {
        self.header = header
        self.element = element
    }

    deinit {
        print("  Middle<Element> deinit")
    }
}

// MARK: - Generic Middle (type generic + value generic)

/// Generic over Element: ~Copyable AND value generic capacity.
/// Mirrors Buffer.Ring.Inline<capacity> exactly.
public struct MiddleGeneric<Element: ~Copyable, let capacity: Int>: ~Copyable {
    @usableFromInline
    package var header: Int

    @usableFromInline
    package var element: Element

    @inlinable
    public init(header: Int, element: consuming Element) {
        self.header = header
        self.element = element
    }

    deinit {
        print("  MiddleGeneric<Element, \(capacity)> deinit")
    }
}

// MARK: - InlineArray Variant

/// Uses InlineArray for storage — mirrors Storage<Element>.Inline<capacity> which
/// uses @_rawLayout(like: InlineArray<capacity, ...>) internally.
/// The element is stored separately; InlineArray holds dummy padding.
public struct MiddleInlineArray<Element: ~Copyable, let capacity: Int>: ~Copyable {
    @usableFromInline
    package var header: Int

    @usableFromInline
    package var storage: InlineArray<capacity, Int>

    @usableFromInline
    package var element: Element

    @inlinable
    public init(header: Int, element: consuming Element) {
        self.header = header
        self.storage = InlineArray<capacity, Int>(repeating: 0)
        self.element = element
    }

    deinit {
        print("  MiddleInlineArray<Element, \(capacity)> deinit")
    }
}

// MARK: - Deeply Nested Variant (mirrors Buffer<Element>.Ring.Inline<capacity>)

/// Namespace enum — mirrors `enum Buffer<Element: ~Copyable>`.
public enum BufferNS<Element: ~Copyable> {

    /// Nested struct — mirrors `struct Ring: ~Copyable` inside Buffer.
    public struct Ring: ~Copyable {

        /// Doubly-nested struct with value generic — mirrors `struct Inline<let capacity: Int>`.
        /// The Element generic comes from the enclosing BufferNS<Element>.
        public struct Inline<let capacity: Int>: ~Copyable {
            @usableFromInline
            package var header: Int

            @usableFromInline
            package var element: Element

            @inlinable
            public init(header: Int, element: consuming Element) {
                self.header = header
                self.element = element
            }

            deinit {
                print("  BufferNS<Element>.Ring.Inline<\(capacity)> deinit")
            }
        }
    }
}

// MARK: - Enum Variant

/// Enum wrapper (mirrors Buffer.Ring.Small's _Representation pattern).
public enum MiddleEnum<Element: ~Copyable, let capacity: Int>: ~Copyable {
    case stored(MiddleGeneric<Element, capacity>)
}

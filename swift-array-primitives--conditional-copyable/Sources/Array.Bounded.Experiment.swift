// Toolchain: Swift 6.3.1 (2026-04-30) — anchor added during Phase 7a sweep [EXP-007a]
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//
// ===----------------------------------------------------------------------===//
//
// Experiment: Conditional Copyable for Array.Bounded
//
// This demonstrates how Array.Bounded can be made conditionally Copyable
// by using ManagedBuffer-based storage instead of raw pointer storage.
//
// ===----------------------------------------------------------------------===//

/// Namespace for experimental array types.
public enum ExperimentalArray<Element: ~Copyable>: ~Copyable {

    // MARK: - Bounded (Fixed-Capacity, Conditionally Copyable)

    /// A fixed-capacity array that is conditionally Copyable.
    ///
    /// Unlike the current `Array.Bounded` which uses raw pointer storage and has a deinit,
    /// this version uses ManagedBuffer-based storage, enabling conditional Copyable conformance.
    ///
    /// ## Conditional Copyable
    ///
    /// When `Element` is `Copyable`, `Bounded` is also `Copyable`:
    ///
    /// ```swift
    /// let a = try ExperimentalArray<Int>.Bounded(count: 3) { $0 }
    /// let b = a  // Copy works!
    /// ```
    ///
    /// When `Element` is `~Copyable`, `Bounded` is move-only:
    ///
    /// ```swift
    /// struct FileHandle: ~Copyable { ... }
    /// let handles = try ExperimentalArray<FileHandle>.Bounded(count: 3) { ... }
    /// // let copy = handles  // Error: cannot copy
    /// ```
    ///
    /// ## Sequence Conformance
    ///
    /// When `Element` is `Copyable`, `Bounded` conforms to `Sequence`:
    ///
    /// ```swift
    /// for element in array {
    ///     print(element)
    /// }
    /// ```
    ///
    /// For `~Copyable` elements, use `forEach(_:)` instead.
    @safe
    public struct Bounded: ~Copyable {

        // MARK: - Nested Storage (inherits Element's ~Copyable context)

        /// Internal storage class using ManagedBuffer.
        ///
        /// Declared as a nested class so that `Element` inherits the `~Copyable`
        /// suppression from the outer type. This enables conditional Copyable.
        @usableFromInline
        final class Storage: ManagedBuffer<Int, Element> {

            /// Creates storage with the specified capacity, initialized with elements.
            @usableFromInline
            static func create(
                capacity: Int,
                initializingWith initializer: (Int) -> Element
            ) -> Storage {
                let storage = Storage.create(minimumCapacity: capacity) { _ in 0 }
                let typed = unsafe unsafeDowncast(storage, to: Storage.self)

                _ = unsafe typed.withUnsafeMutablePointerToElements { elements in
                    for i in 0..<capacity {
                        unsafe (elements + i).initialize(to: initializer(i))
                    }
                }
                typed.header = capacity

                return typed
            }

            /// Creates empty storage (for zero-count arrays).
            @usableFromInline
            static func createEmpty() -> Storage {
                let storage = Storage.create(minimumCapacity: 0) { _ in 0 }
                return unsafe unsafeDowncast(storage, to: Storage.self)
            }

            deinit {
                let count = header
                guard count > 0 else { return }
                _ = unsafe withUnsafeMutablePointerToElements { elements in
                    for i in 0..<count {
                        unsafe (elements + i).deinitialize(count: 1)
                    }
                }
            }

            /// Returns pointer to element storage.
            @usableFromInline
            var _elementsPointer: UnsafeMutablePointer<Element> {
                unsafe withUnsafeMutablePointerToElements { unsafe $0 }
            }
        }

        // MARK: - Properties

        @usableFromInline
        var _storage: Storage

        /// Cached pointer for Span access.
        @usableFromInline
        var _cachedPtr: UnsafeMutablePointer<Element>

        /// The fixed capacity of the array.
        public let _capacity: Int

        // MARK: - Initialization

        /// Creates a fixed array with the specified count, initializing each element.
        ///
        /// - Parameters:
        ///   - count: The number of elements.
        ///   - initializer: A closure that provides the element for each index.
        /// - Throws: `Error.invalidCount` if count is negative.
        @inlinable
        public init(
            count: Int,
            initializingWith initializer: (Int) -> Element
        ) throws {
            guard count >= 0 else {
                throw ExperimentalBoundedError.invalidCount(count)
            }

            if count == 0 {
                self._storage = Storage.createEmpty()
                unsafe (self._cachedPtr = _storage._elementsPointer)
                self._capacity = 0
                return
            }

            self._storage = Storage.create(capacity: count, initializingWith: initializer)
            unsafe (self._cachedPtr = _storage._elementsPointer)
            self._capacity = count
        }

        // Note: NO deinit - Storage handles cleanup via its own deinit
    }
}

// MARK: - Conditional Copyable

/// `ExperimentalArray.Bounded` is `Copyable` when its elements are `Copyable`.
///
/// This is the KEY difference from the current `Array.Bounded`:
/// - Current: has deinit → unconditionally ~Copyable
/// - Experimental: no deinit → conditionally Copyable
extension ExperimentalArray.Bounded: Copyable where Element: Copyable {}

// MARK: - Sequence (Copyable elements only)

/// `ExperimentalArray.Bounded` conforms to `Sequence` when `Element` is `Copyable`.
///
/// This enables `for-in` loops, `map`, `filter`, and other sequence operations.
extension ExperimentalArray.Bounded: Sequence where Element: Copyable {

    public struct Iterator: IteratorProtocol {
        @usableFromInline
        let _storage: ExperimentalArray<Element>.Bounded.Storage

        @usableFromInline
        var _index: Int = 0

        @usableFromInline
        init(storage: ExperimentalArray<Element>.Bounded.Storage) {
            self._storage = storage
        }

        @inlinable
        public mutating func next() -> Element? {
            guard _index < _storage.header else { return nil }
            defer { _index += 1 }
            return _storage._readElement(at: _index)
        }
    }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(storage: _storage)
    }
}

// MARK: - Storage Helpers (Copyable)

extension ExperimentalArray.Bounded.Storage where Element: Copyable {

    /// Creates a copy of this storage.
    @usableFromInline
    func copy() -> ExperimentalArray<Element>.Bounded.Storage {
        let count = header
        guard count > 0 else {
            return ExperimentalArray<Element>.Bounded.Storage.createEmpty()
        }

        return ExperimentalArray<Element>.Bounded.Storage.create(
            capacity: count
        ) { i in
            _readElement(at: i)
        }
    }

    /// Reads element at the given index.
    @usableFromInline
    func _readElement(at index: Int) -> Element {
        unsafe withUnsafeMutablePointerToElements { elements in
            unsafe (elements + index).pointee
        }
    }
}

// MARK: - Properties

extension ExperimentalArray.Bounded where Element: ~Copyable {
    /// The number of elements in the array.
    @inlinable
    public var count: Int { _storage.header }

    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { _storage.header == 0 }

    /// The capacity of the array (equals count for Bounded).
    @inlinable
    public var capacity: Int { _capacity }
}

// MARK: - Element Access (for ~Copyable elements)

extension ExperimentalArray.Bounded where Element: ~Copyable {

    /// Accesses the element at the given index via closure.
    @inlinable
    public func withElement<R>(at index: Int, _ body: (borrowing Element) -> R) -> R {
        precondition(index >= 0 && index < _storage.header, "Index out of bounds")
        return unsafe body((_cachedPtr + index).pointee)
    }

    /// Iterates over all elements.
    @inlinable
    public func forEach(_ body: (borrowing Element) -> Void) {
        let count = _storage.header
        for i in 0..<count {
            unsafe body((_cachedPtr + i).pointee)
        }
    }
}

// MARK: - Subscript (for Copyable elements)

extension ExperimentalArray.Bounded where Element: Copyable {

    /// Accesses the element at the given index.
    @inlinable
    public subscript(index: Int) -> Element {
        get {
            precondition(index >= 0 && index < _storage.header, "Index out of bounds")
            return _storage._readElement(at: index)
        }
        set {
            precondition(index >= 0 && index < _storage.header, "Index out of bounds")
            makeUnique()
            unsafe (_cachedPtr + index).pointee = newValue
        }
    }

    /// Ensures unique storage before mutation (CoW).
    @usableFromInline
    mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.copy()
            unsafe (_cachedPtr = _storage._elementsPointer)
        }
    }
}

// MARK: - Span Access

extension ExperimentalArray.Bounded where Element: ~Copyable {

    /// Read-only span of the array elements.
    @inlinable
    public var span: Span<Element> {
        @_lifetime(borrow self)
        borrowing get {
            unsafe Span(_unsafeStart: _cachedPtr, count: _storage.header)
        }
    }

    /// Mutable span of the array elements.
    @inlinable
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        mutating get {
            unsafe MutableSpan(_unsafeStart: _cachedPtr, count: _storage.header)
        }
    }
}

// MARK: - CoW-aware MutableSpan (Copyable)

extension ExperimentalArray.Bounded where Element: Copyable {

    /// Mutable span with CoW semantics.
    @inlinable
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        mutating get {
            makeUnique()
            return unsafe MutableSpan(_unsafeStart: _cachedPtr, count: _storage.header)
        }
    }
}

// MARK: - Sendable

extension ExperimentalArray.Bounded: @unchecked Sendable where Element: Sendable {}

// MARK: - Error (Module-level to avoid ~Copyable context)

/// Errors that can occur during experimental bounded array operations.
///
/// Declared at module level to avoid inheriting the ~Copyable constraint
/// from the generic context.
public enum ExperimentalBoundedError: Swift.Error, Sendable, Equatable {
    /// The requested count is invalid (negative).
    case invalidCount(Int)

    /// Index is out of bounds.
    case indexOutOfBounds(index: Int, count: Int)
}

extension ExperimentalArray.Bounded {
    /// Typealias for the error type.
    public typealias Error = ExperimentalBoundedError
}

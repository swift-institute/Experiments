// Status: SUPERSEDED -- UnsafeBufferPointer<~Copyable> conformance shipped in Memory.Contiguous.Protocol. (Phase 1b stale-triage 2026-04-30)
// Revalidated: Swift 6.3.1 (2026-04-30) — SUPERSEDED (per existing Status line; not re-run)
// unsafebufferpointer-noncopyable
//
// Hypothesis: UnsafeBufferPointer<T> can be used with ~Copyable T
// in Swift 6.2.3 with SuppressedAssociatedTypes.
//
// This determines whether Memory.Contiguous.Protocol can add
// `associatedtype Element: ~Copyable` while retaining the
// `withUnsafeBufferPointer` requirement.
//
// Variants:
//   V1: UnsafeBufferPointer<NC> parameter in function
//   V2: Protocol with associatedtype Element: ~Copyable + UBP requirement
//   V3: Span<NC> (known to work, control)

// MARK: - Non-Copyable Type

struct NC: ~Copyable {
    var value: Int
}

// MARK: - V1: UnsafeBufferPointer<NC> in function signature

func acceptsUBP(_ buffer: UnsafeBufferPointer<NC>) -> Int {
    buffer.count
}

// V1: CONFIRMED

// MARK: - V2: Protocol with ~Copyable Element and UBP requirement

protocol ContiguousStorage: ~Copyable {
    associatedtype Element: ~Copyable

    var span: Span<Element> { get }

    func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R
}

// V2: CONFIRMED

// MARK: - V3: Span<NC> (control)

func acceptsSpan(_ span: Span<NC>) -> Int {
    span.count
}

// V3: CONFIRMED

// MARK: - V4: Protocol conformance with concrete ~Copyable element

struct NCBuffer: ContiguousStorage, ~Copyable {
    typealias Element = NC

    let pointer: UnsafeMutableBufferPointer<NC>
    let count: Int

    var span: Span<NC> {
        @_lifetime(borrow self)
        borrowing get {
            let span = Span<NC>(_unsafeStart: pointer.baseAddress!, count: count)
            return unsafe _overrideLifetime(span, borrowing: self)
        }
    }

    func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<NC>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe body(UnsafeBufferPointer(pointer))
    }
}

// V4: CONFIRMED

// MARK: - V5: Protocol with Copyable-constrained UBP method

// Alternative design: keep Element: ~Copyable on the protocol,
// but constrain withUnsafeBufferPointer to where Element: Copyable.

protocol ContiguousStorageV5: ~Copyable {
    associatedtype Element: ~Copyable

    var span: Span<Element> { get }
}

extension ContiguousStorageV5 where Element: Copyable {
    func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        fatalError("stub")
    }
}

// V5: CONFIRMED (not needed — V2/V4 both work)

// MARK: - Execution

print("=== UnsafeBufferPointer ~Copyable Experiment ===")
print("V1 (UBP<NC> parameter): compiled OK")
print("V2 (protocol with ~Copyable + UBP): compiled OK")
print("V3 (Span<NC> control): compiled OK")
print("V4 (concrete conformance): compiled OK")
print("V5 (split protocol fallback): compiled OK")
print("All variants that compiled are CONFIRMED.")

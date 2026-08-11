// Status: SUPERSEDED -- consuming-return pattern shipped in Input.Stream.Protocol. (Phase 1b stale-triage 2026-04-30)
// Revalidated: Swift 6.3.1 (2026-04-30) — SUPERSEDED (per existing Status line; not re-run)
// consuming-protocol-return
//
// Hypothesis: Protocol methods can return ~Copyable values via consuming
// semantics, and Optional<~Copyable> works in Swift 6.2.3.
//
// This determines whether Input.Stream.Protocol can add
// `associatedtype Element: ~Copyable` while retaining:
//   - `advance() -> Element` (consuming return via move)
//   - `first: Element? { get }` (Optional wrapping — requires copy or yield)
//
// Variants:
//   V1: Protocol definition with ~Copyable Element
//   V2: advance() consuming via UnsafeMutablePointer.moveElement
//   V3: first via _read accessor (yielding borrow)
//   V4: first via Optional wrapping (may require Copyable)
//   V5: next() -> Element? extension method

// MARK: - Non-Copyable Type

struct NC: ~Copyable {
    var value: Int
}

// MARK: - V1: Protocol definition with ~Copyable Element

protocol StreamV1: ~Copyable {
    associatedtype Element: ~Copyable

    var isEmpty: Bool { get }
    mutating func advance() -> Element
}

// V1: CONFIRMED

// MARK: - V2: Protocol with advance + first (no Optional)

protocol StreamV2: ~Copyable {
    associatedtype Element: ~Copyable

    var isEmpty: Bool { get }
    var count: Int { get }
    mutating func advance() -> Element
}

// V2: CONFIRMED

// MARK: - V3: Concrete conformance with moveElement for advance

@unsafe
struct NCStream: StreamV2, ~Copyable {
    typealias Element = NC

    let base: UnsafeMutablePointer<NC>
    let total: Int
    var index: Int = 0

    var isEmpty: Bool { unsafe index >= total }
    var count: Int { unsafe total - index }

    mutating func advance() -> NC {
        let element = unsafe base.advanced(by: index).move()
        unsafe index += 1
        return element
    }
}

// V3: CONFIRMED

// MARK: - V4: Optional<~Copyable> first property (Copyable-constrained)

// Optional<~Copyable> should work (Optional is ~Copyable-aware since SE-0427).
// But returning it from a property requires the value to be copyable OR consumed.
// For a `first` peek, we need borrowing — which means _read accessor.

protocol StreamWithFirst: ~Copyable {
    associatedtype Element: ~Copyable

    var isEmpty: Bool { get }
}

// Copyable-constrained extension: first works when Element is Copyable
extension StreamWithFirst where Element: Copyable, Self: ~Copyable {
    var firstIfCopyable: Element? {
        fatalError("stub")
    }
}

// V4: CONFIRMED (Copyable-constrained first works; ~Copyable first requires _read/yield)

// MARK: - V5: next() -> Element? extension method (consuming)

extension StreamV1 {
    mutating func next() -> Element? {
        guard !isEmpty else { return nil }
        return advance()  // advance() consumes, then wraps in Optional
    }
}

// V5: CONFIRMED

// MARK: - V6: Full streaming protocol pattern

protocol FullStream: ~Copyable {
    associatedtype Element: ~Copyable
    associatedtype Checkpoint: Sendable & Comparable

    var isEmpty: Bool { get }
    var count: Int { get }

    mutating func advance() -> Element
    func checkpoint() -> Checkpoint
    mutating func restore(to: Checkpoint)
}

// V6: CONFIRMED

// MARK: - Execution

print("=== Consuming Protocol Return Experiment ===")
print("V1 (protocol with ~Copyable Element): compiled OK")
print("V2 (protocol with advance + count): compiled OK")
print("V3 (concrete moveElement conformance): compiled OK")
print("V4 (Copyable-constrained first): compiled OK")
print("V5 (next() -> Element? extension): compiled OK")
print("V6 (full streaming protocol): compiled OK")
print("All variants that compiled are CONFIRMED.")

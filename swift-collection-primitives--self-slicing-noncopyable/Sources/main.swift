// self-slicing-noncopyable
//
// Purpose: Find the correct way to define a self-slicing subscript protocol
//          that supports ~Copyable conformers AND provides default extensions
//          for partial-range subscripts.
//
// Problem: In a protocol extension where Self: ~Copyable, calling
//          `self[range]` in a subscript getter produces:
//          error: 'self.subscript' is borrowed and cannot be consumed
//
// Root cause: The compiler cannot prove that the result of a protocol
//          `get` subscript is independently owned from `self` when dispatching
//          through a ~Copyable protocol. This is a protocol dispatch limitation —
//          concrete types work fine. The limitation applies regardless of access
//          path (direct self, UnsafeMutablePointer.pointee, borrowing method).
//
// Solution: Two-tier defaults — same pattern as borrowing closures in
//          sequence-primitives.
//          Tier 1 (~Copyable): _read yields borrow (compiler-safe through protocol)
//          Tier 2 (Copyable): get returns owned (implicit Copyable constraint)
//          ~Copyable conformers needing owned access implement on concrete type.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21) / Xcode 26 beta
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — Two-tier defaults compile, run, and provide correct
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//         access at both tiers. See Results Summary at end.
// Date: 2026-02-13

// =============================================================================
// MARK: - Protocol definition
// =============================================================================

protocol Sliceable: ~Copyable {
    associatedtype Index: Comparable
    var startIndex: Index { get }
    var endIndex: Index { get }
    subscript(bounds: Range<Index>) -> Self { get }
}

// =============================================================================
// MARK: - Two-tier defaults
// =============================================================================

// Tier 1: ~Copyable (borrowing access via _read)
// Applies to ALL conformers. Yields a borrow of the slice result.
// For ~Copyable callers: can read properties, pass to borrowing parameters.
// For Copyable callers: shadowed by Tier 2 (get is more specific).
extension Sliceable where Self: ~Copyable {
    subscript(bounds: PartialRangeFrom<Index>) -> Self {
        _read {
            yield self[bounds.lowerBound..<endIndex]
        }
    }
    subscript(bounds: PartialRangeUpTo<Index>) -> Self {
        _read {
            yield self[startIndex..<bounds.upperBound]
        }
    }
}

// Tier 2: Copyable (owned access via get)
// Applies only to Copyable conformers (implicit constraint).
// More specific than Tier 1, so shadows _read for Copyable types.
// Returns an independently-owned slice value.
extension Sliceable {
    subscript(bounds: PartialRangeFrom<Index>) -> Self {
        self[bounds.lowerBound..<endIndex]
    }
    subscript(bounds: PartialRangeUpTo<Index>) -> Self {
        self[startIndex..<bounds.upperBound]
    }
}

// =============================================================================
// MARK: - Conformers
// =============================================================================

struct CopyableSlice: Sliceable {
    var start: Int
    var end: Int
    var startIndex: Int { start }
    var endIndex: Int { end }
    subscript(bounds: Range<Int>) -> CopyableSlice {
        CopyableSlice(start: bounds.lowerBound, end: bounds.upperBound)
    }
}

struct NCSlice: Sliceable, ~Copyable {
    var start: Int
    var end: Int
    var startIndex: Int { start }
    var endIndex: Int { end }
    subscript(bounds: Range<Int>) -> NCSlice {
        NCSlice(start: bounds.lowerBound, end: bounds.upperBound)
    }
}

// ~Copyable conformer with own partial-range subscripts (owned access)
struct NCSliceFull: Sliceable, ~Copyable {
    var start: Int
    var end: Int
    var startIndex: Int { start }
    var endIndex: Int { end }
    subscript(bounds: Range<Int>) -> NCSliceFull {
        NCSliceFull(start: bounds.lowerBound, end: bounds.upperBound)
    }
    // Override Tier 1 _read with concrete get (works on concrete types)
    subscript(bounds: PartialRangeFrom<Int>) -> NCSliceFull {
        self[bounds.lowerBound..<endIndex]
    }
    subscript(bounds: PartialRangeUpTo<Int>) -> NCSliceFull {
        self[startIndex..<bounds.upperBound]
    }
}

// =============================================================================
// MARK: - Execution
// =============================================================================

print("=== Tier 2 (Copyable): owned access ===")
var cs = CopyableSlice(start: 0, end: 10)
cs = cs[3...]  // owned via get (Tier 2)
print("assign cs[3...]:  \(cs.start)..<\(cs.end)")  // 3..<10
let prefix = cs[..<7]  // owned via get (Tier 2)
print("let cs[..<7]:     \(prefix.start)..<\(prefix.end)")  // 3..<7

print("\n=== Tier 1 (~Copyable): borrowing access ===")
var ncs = NCSlice(start: 0, end: 10)
// Borrow access — read properties through the _read yield
print("borrow [4...]:    \(ncs[4...].start)..<\(ncs[4...].end)")  // 4..<10
print("borrow [..<7]:    \(ncs[..<7].start)..<\(ncs[..<7].end)")  // 0..<7

print("\n=== NC with own subscripts: owned access ===")
var ncf = NCSliceFull(start: 0, end: 10)
let suffix = ncf[5...]  // owned via concrete get override
print("let ncf[5...]:    \(suffix.start)..<\(suffix.end)")  // 5..<10

print("\nAll executed successfully.")

// =============================================================================
// MARK: - Results Summary
// =============================================================================
//
// TWO-TIER DEFAULTS: CONFIRMED
//
// | Access Pattern       | Copyable (Tier 2)    | ~Copyable (Tier 1)     |
// |---------------------|---------------------|----------------------|
// | `x = cs[3...]`      | ✓ owned via get     | ✗ (can't own _read)  |
// | `cs[3...].property` | ✓ borrow+copy       | ✓ borrow via _read   |
// | Let binding         | ✓ owned via get     | ✗ (can't own _read)  |
// | Concrete override   | N/A                 | ✓ owned via concrete |
//
// COMPILER LIMITATION:
// Protocol dispatch for ~Copyable Self returning Self fails for `get`.
// This applies to ALL access paths (self, pointer.pointee, borrowing).
// _read works because it yields a borrow (no ownership transfer through dispatch).
// Concrete types don't have this limitation — protocol dispatch is the issue.
//
// RECOMMENDED APPROACH:
// 1. Protocol: `subscript(bounds: Range<Index>) -> Self { get }`
// 2. Tier 1 default (~Copyable): _read yields borrow
// 3. Tier 2 default (Copyable): get returns owned
// 4. NC conformers needing owned subscripts: implement on concrete type
// 5. .slice Property.View accessor: for additional operations (prefix, suffix, etc.)
//
// This mirrors the two-tier pattern in sequence-primitives for borrowing closures.
//
// REFUTED APPROACHES:
// - UnsafeMutablePointer.pointee[range]: same error (protocol dispatch, not access path)
// - borrowing func returning Self: same error
// - let binding in get body: same error
// - _read on protocol requirement: `_read` not allowed in protocol declarations

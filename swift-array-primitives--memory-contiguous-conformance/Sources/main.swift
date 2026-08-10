// SUPERSEDED (2026-06-23): Memory.Contiguous was dissolved — the read-capability
//   protocol is now Span.Protocol (the renamed/relocated Memory.Contiguous.Protocol),
//   the typed contiguous tier is Storage.Contiguous. The constraint-poisoning finding
//   below is preserved as the historical record; see
//   swift-institute/Research/memory-contiguous-dissolution.md.
//
// Experiment: Memory.Contiguous.Protocol Conformance Constraint Poisoning
//
// Hypothesis: Set.Ordered can conform to Memory.Contiguous.Protocol without
// constraint poisoning, but Array.Bounded cannot. Find the structural difference.
//
// Status: RESOLVED ✓ (Pattern incompatibility confirmed, keeping double implementation)
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Methodology: [EXP-004a] Incremental Construction
//
// ROOT CAUSE IDENTIFIED:
// - Set.Ordered: `public struct Ordered` (NO explicit ~Copyable, inherits from parent)
// - Array.Bounded: `public struct Bounded: ~Copyable` (EXPLICIT ~Copyable marker)
//
// When a struct has EXPLICIT `~Copyable`, conditional Copyable conformance FAILS:
//   `extension Foo: Copyable where Element: Copyable {}`  // ERROR
//
// When a struct INHERITS ~Copyable from parent (no explicit marker), it WORKS:
//   `extension Foo: Copyable where Element: Copyable {}`  // OK
//
// FIX: Remove explicit `~Copyable` from Array.Bounded and Array.Unbounded.
// The parent `enum Array<Element: ~Copyable>: ~Copyable` does NOT propagate
// ~Copyable to nested types - they inherit Copyable unless explicitly marked.
//
// HOWEVER: Types with deinit MUST have explicit ~Copyable (compiler requirement).
// This means Array.Inline and Array.Small CANNOT conform to Memory.Contiguous.Protocol.
//
// Test Results:
// - Test 2 (WithoutExplicitNC): WORKS - no explicit ~Copyable ✓
// - Test 3 (WithExplicitNC): FAILS - explicit ~Copyable marker ✗
// - Test 4 (WithExplicitNCRemoved): WORKS - explicit marker removed ✓
// - Test 5 (WithDeinitNoMarker): N/A - deinit requires explicit ~Copyable
//
// CONCLUSION:
// Array types use the "double implementation" pattern:
// - Base implementation in `extension Foo where Element: ~Copyable {}`
// - CoW shadow implementation in `extension Foo where Element: Copyable {}`
//
// This pattern is INCOMPATIBLE with Memory.Contiguous.Protocol conformance because:
// 1. Protocol has `associatedtype Element` → requires Element: Copyable (SE-0427)
// 2. Adding conformance poisons `where Element: ~Copyable` extensions
//
// DECISION: Keep double implementation pattern, do NOT conform to Memory.Contiguous.Protocol
//
// Alternative: Set.Ordered uses single-implementation pattern (no shadow) and CAN conform.
// But Array prefers the double pattern for explicit CoW semantics.

// MARK: - Minimal Protocol (like Memory.Contiguous.Protocol)

protocol ContiguousProtocol: ~Copyable {
    associatedtype Element  // Implicitly requires Element: Copyable (SE-0427)
    var span: Span<Element> { get }
}

// MARK: - Test 1: Minimal parent enum with ~Copyable Element

enum Container<Element: ~Copyable>: ~Copyable {}

// MARK: - Test 2: Nested struct WITHOUT explicit ~Copyable (like Set.Ordered)

extension Container {
    struct WithoutExplicitNC {
        // Stored pointer like both Set.Ordered and Array.Bounded have
        var cachedPtr: UnsafeMutablePointer<Element>

        var span: Span<Element> {
            @_lifetime(borrow self)
            borrowing get {
                unsafe Span(_unsafeStart: cachedPtr, count: 1)
            }
        }
    }
}

// Test 2a: Conditional Copyable (like both have)
extension Container.WithoutExplicitNC: Copyable where Element: Copyable {}

// Test 2b: Conformance - does this work?
extension Container.WithoutExplicitNC: ContiguousProtocol {}

// MARK: - Test 3: Nested struct WITH explicit ~Copyable (like Array.Bounded)

extension Container {
    struct WithExplicitNC: ~Copyable {
        // Same stored pointer
        var cachedPtr: UnsafeMutablePointer<Element>

        var span: Span<Element> {
            @_lifetime(borrow self)
            borrowing get {
                unsafe Span(_unsafeStart: cachedPtr, count: 1)
            }
        }
    }
}

// Test 3a: Conditional Copyable - FAILS because explicit ~Copyable
// extension Container.WithExplicitNC: Copyable where Element: Copyable {}

// Test 3b: Conformance - skip due to 3a failure
// extension Container.WithExplicitNC: ContiguousProtocol {}

// MARK: - Test 4: Nested struct with explicit ~Copyable REMOVED (fix for Array.Bounded)

extension Container {
    struct WithExplicitNCRemoved {
        // Same stored pointer
        var cachedPtr: UnsafeMutablePointer<Element>

        var span: Span<Element> {
            @_lifetime(borrow self)
            borrowing get {
                unsafe Span(_unsafeStart: cachedPtr, count: 1)
            }
        }
    }
}

// Test 4a: Conditional Copyable - should work now
extension Container.WithExplicitNCRemoved: Copyable where Element: Copyable {}

// Test 4b: Conformance - should work
extension Container.WithExplicitNCRemoved: ContiguousProtocol {}

// MARK: - Test 5: Type with deinit REQUIRES explicit ~Copyable
//
// A struct with deinit MUST have explicit ~Copyable marker.
// Without it, the struct inherits Copyable from parent (not ~Copyable).
// Error: "deinitializer cannot be declared in struct that conforms to 'Copyable'"
//
// This means:
// - Array.Bounded (no deinit) → CAN remove ~Copyable → conditionally Copyable ✓
// - Array.Unbounded (no deinit) → CAN remove ~Copyable → conditionally Copyable ✓
// - Array.Inline (HAS deinit) → MUST keep ~Copyable → cannot conform to Memory.Contiguous.Protocol
// - Array.Small (HAS deinit) → MUST keep ~Copyable → cannot conform to Memory.Contiguous.Protocol

// MARK: - Main

print("=== Memory.Contiguous.Protocol Conformance Test ===")
print("")
print("If this compiles, BOTH patterns work.")
print("If it fails, check which extension causes the error.")
print("")
print("Test 2 (without ~Copyable): Container.WithoutExplicitNC")
print("Test 3 (with ~Copyable): Container.WithExplicitNC")

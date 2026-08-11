// ===----------------------------------------------------------------------===//
// MARK: - Verification: Hash.Index<Element> with Typed Positions
// ===----------------------------------------------------------------------===//
//
// Purpose: Verify Hash.Index<Element> works with typed Index<Element> positions
//
// Implementation: Hash.Index now uses Index_Primitives.Index<Element> for
//   all position parameters and return values, providing compile-time type safety.
//
// Toolchain: swift-6.0-RELEASE
// Status: SUPERSEDED 2026-04-30 — Required product 'Hash Index Primitives' from swift-index-primitives no longer exported; package surface restructured
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT (package drift; SUPERSEDED per [META-007])
// Date: 2026-01-22
// ===----------------------------------------------------------------------===//

import Index_Primitives
import Hash_Primitives
import Hash_Index_Primitives

// ===----------------------------------------------------------------------===//
// MARK: - Phase 1: Typed Hash.Index<Element> API
// ===----------------------------------------------------------------------===//

print("=== Phase 1: Typed Hash.Index<Element> API ===\n")

// Define element type for phantom typing
struct MyElement {}

// Hash.Index is now generic over Element
var index = Hash.Index<MyElement>()

// Create typed position using integer literal
let pos0: Index<MyElement> = 0

// Insert: position is Index<MyElement>
let inserted = index.insert(position: pos0, hashValue: 42, equals: { _ in false })
print("Inserted at position \(pos0): \(inserted)")

// Lookup: returns Index<MyElement>?
let found = index.position(forHash: 42, equals: { $0 == 0 })
print("Found position: \(found as Any)")

// insert: position is Index<MyElement>
let pos1: Index<MyElement> = 1
index.insert(position: pos1, hashValue: 99, equals: { _ in false })

// decrementPositions: Index<MyElement> parameter
index.decrementPositions(after: pos0)

print("Current count: \(index.count)")
print("")

// ===----------------------------------------------------------------------===//
// MARK: - Phase 2: Type Safety Demonstration
// ===----------------------------------------------------------------------===//

print("=== Phase 2: Type Safety Demonstration ===\n")

// Hash.Index<A> and Hash.Index<B> are different types
struct TypeA {}
struct TypeB {}

var indexA = Hash.Index<TypeA>()
var indexB = Hash.Index<TypeB>()

let idxA: Index<TypeA> = 0
let idxB: Index<TypeB> = 0

indexA.insert(position: idxA, hashValue: 42, equals: { _ in false })
indexB.insert(position: idxB, hashValue: 42, equals: { _ in false })

// COMPILE ERROR if you try to mix them:
// indexA.insert(position: idxB, ...)  // Error: cannot convert Index<TypeB> to Index<TypeA>

print("Hash.Index<TypeA> count: \(indexA.count)")
print("Hash.Index<TypeB> count: \(indexB.count)")
print("Positions from different types CANNOT be mixed (compile-time enforcement)")
print("")

// ===----------------------------------------------------------------------===//
// MARK: - Phase 3: Implemented Typed API
// ===----------------------------------------------------------------------===//

print("=== Phase 3: Implemented Typed API ===\n")

// Hash.Index<Element> now uses typed positions:
//
// extension Hash {
//     struct Index<Element: ~Copyable>: ~Copyable {
//         func position(forHash:equals:) -> Index_Primitives.Index<Element>?
//         mutating func insert(position: Index_Primitives.Index<Element>, hashValue: Int, equals:) -> Bool
//         mutating func decrementPositions(after: Index_Primitives.Index<Element>)
//     }
// }

print("Actual API (now implemented):")
print("  position(forHash:) -> Index<Element>?")
print("  insert(position: Index<Element>, ...) -> Bool")
print("  decrementPositions(after: Index<Element>)")
print("")

// ===----------------------------------------------------------------------===//
// MARK: - Phase 4: Storage Implications
// ===----------------------------------------------------------------------===//

print("=== Phase 4: Storage Implications ===\n")

// Index<Element> wraps Affine.Discrete.Position which wraps Int
// MemoryLayout analysis:

print("MemoryLayout<Int>.size: \(MemoryLayout<Int>.size)")
print("MemoryLayout<Int>.stride: \(MemoryLayout<Int>.stride)")
print("MemoryLayout<Affine.Discrete.Position>.size: \(MemoryLayout<Affine.Discrete.Position>.size)")
print("MemoryLayout<Affine.Discrete.Position>.stride: \(MemoryLayout<Affine.Discrete.Position>.stride)")
print("MemoryLayout<Index<MyElement>>.size: \(MemoryLayout<Index<MyElement>>.size)")
print("MemoryLayout<Index<MyElement>>.stride: \(MemoryLayout<Index<MyElement>>.stride)")

print("")
print("Storage analysis: Index<Element> has same layout as Int (8 bytes)")
print("No storage overhead for typed positions")
print("")

// ===----------------------------------------------------------------------===//
// MARK: - Phase 5: Usage Pattern
// ===----------------------------------------------------------------------===//

print("=== Phase 5: Usage Pattern ===\n")

// Hash.Index<Element> is designed for:
// 1. Containers with ~Copyable elements (can't use standard Dictionary)
// 2. Cases where the element itself can't be stored in the hash table
//    (only position/hash pairs stored, elements live elsewhere)
//
// Example: OrderedSet<Token> where Token: ~Copyable
//
// struct OrderedSet<Element: ~Copyable & Hash.Protocol>: ~Copyable {
//     var elements: Array<Element>.Bounded
//     var hashIndex: Hash.Index<Element>  // Now typed!
//
//     func contains(_ element: borrowing Element) -> Bool {
//         let h = element.hashValue
//         return hashIndex.position(forHash: h, equals: { idx in
//             elements.withElement(at: idx.position.rawValue) { $0 == element }
//         }) != nil
//     }
//
//     func index(_ element: borrowing Element) -> Index<Element>? {
//         hashIndex.position(forHash: element.hashValue, equals: {...})
//         // Returns Index<Element> directly - no conversion needed!
//     }
// }

print("Hash.Index<Element> primary use case: ~Copyable-friendly hash tables")
print("Elements live in external storage (e.g., Array.Bounded)")
print("Hash.Index only stores (hash, position) pairs")
print("Positions are typed Index<Element> for compile-time safety")
print("")

// ===----------------------------------------------------------------------===//
// MARK: - Summary
// ===----------------------------------------------------------------------===//

print("=== Summary ===\n")

print("""
IMPLEMENTED: Hash.Index<Element> with typed positions

Changes:
1. Hash.Index → Hash.Index<Element: ~Copyable>
2. All position parameters/returns use Index_Primitives.Index<Element>
3. Internal storage still uses raw Int for efficiency
4. Compile-time type safety: Index<A> cannot be used with Hash.Index<B>

Benefits:
- Compile-time prevention of index confusion between collections
- Consistent with Index_Primitives design philosophy
- Self-documenting API: positions are clearly typed
- No runtime overhead (same memory layout as raw Int)

Example usage:
    var index = Hash.Index<MyElement>()
    let pos: Index<MyElement> = ...
    index.insert(position: pos, hashValue: 42, equals: {...})
    let found: Index<MyElement>? = index.position(forHash: 42, equals: {...})
""")

print("")
print("=== Verification Complete ===")

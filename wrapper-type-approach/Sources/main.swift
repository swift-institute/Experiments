// MARK: - Wrapper Type Approach
// Purpose: Strategies to avoid Sequence conformance poisoning
// Status: SUPERSEDED
// Result: SUPERSEDED — wrapper approach works but production uses custom Sequence.Protocol + module separation instead
// Date: 2026-01-22 (original), 2026-03-10 (updated)
// Toolchain: Swift 6.2
//
// Original approach: Wrapper types to avoid direct Sequence conformance.
// Production solution: Custom Sequence.Protocol + module separation.
//
// Production architecture (swift-primitives):
//   Module A (Core): Container<Element: ~Copyable> + custom Sequence.Protocol
//   Module B (non-Core): Swift.Sequence conformance (only when Element: Copyable)
//   This avoids constraint poisoning without wrapper types.
//
// The wrapper approach below is valid Swift but is NOT what production uses.

// --- The problem ---
// Adding Swift.Sequence directly to a ~Copyable container poisons it:
// all extensions implicitly gain `where Element: Copyable`.

struct Container<Element: ~Copyable>: ~Copyable {
    var _count: Int = 0
    var count: Int { _count }
    mutating func add() { _count += 1 }
}

// --- Approach 1: Wrapper type (originally proposed) ---
// Creates a Copyable wrapper that copies data out for iteration.
// DRAWBACK: Requires data copy, doesn't work in-place.

struct SequenceWrapper {
    let count: Int
}

extension SequenceWrapper: Sequence {
    func makeIterator() -> IndexingIterator<Range<Int>> {
        (0..<count).makeIterator()
    }
}

// --- Approach 2: Custom protocol (production solution) ---
// Production defines Sequence.Protocol in swift-sequence-primitives
// which supports ~Copyable containers natively. Container conforms
// in the Core module. Swift.Sequence conformance is added in a
// separate integration module (only when Element: Copyable).
//
// This avoids:
//   - Data copying (no wrapper needed)
//   - Constraint poisoning (module boundary isolates it)
//   - API surface pollution (consumers import only what they need)

struct Resource: ~Copyable { var id: Int }

var intContainer = Container<Int>()
intContainer.add(); intContainer.add()
print("Int count: \(intContainer.count)")
assert(intContainer.count == 2)

var resContainer = Container<Resource>()
resContainer.add()
print("Resource count: \(resContainer.count)")
assert(resContainer.count == 1)

// Wrapper approach works but is not what production uses
let wrapper = SequenceWrapper(count: intContainer.count)
for i in wrapper { print("Wrapper item: \(i)") }

print("wrapper-type-approach: SUPERSEDED")
print("Production uses custom Sequence.Protocol + module separation")

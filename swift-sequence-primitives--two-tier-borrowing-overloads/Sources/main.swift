// MARK: - Two-Tier Borrowing Overloads with SuppressedAssociatedTypes
// Purpose: Test whether borrowing closures work for both Copyable and
//          ~Copyable elements through a protocol with Element: ~Copyable,
//          and whether two-tier overloads (borrowing + by-value) coexist.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21) / Xcode 26 beta
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — single-tier borrowing works for both element kinds,
//         borrowing is transparent for Copyable elements (copy/pass/expr),
//         two-tier overloads compile with distinct method names.
// Output:
//   ~Copyable elements: Resource(10), Resource(20), Resource(30)
//   Copyable elements: 1, 2, 3
//   Copyable ops: copy, pass-by-value, expressions all work
//   Two-tier: borrowing + byValue both compile and dispatch
//
// Note: Same-name callAsFunction overloads (borrowing vs by-value)
//       crash the compiler (MoveOnlyChecker assertion failure) when
//       the callAsFunction body is a stub. When the body contains
//       real iteration logic, single-name borrowing works fine.
//       Distinct method names (.borrowing/.byValue) always work.
//
// Date: 2026-02-12

// MARK: - Infrastructure (matching suppressed-associated-types experiment)

protocol IterProto: ~Copyable {
    associatedtype Element: ~Copyable
    mutating func next() -> Element?
}

protocol IterableProtocol: ~Copyable {
    associatedtype Element: ~Copyable
    associatedtype Iterator: IterProto where Iterator.Element == Element
    borrowing func makeIterator() -> Iterator
}

struct ForEachView<Base: ~Copyable>: ~Copyable {
    let base: UnsafeMutablePointer<Base>
    init(_ base: UnsafeMutablePointer<Base>) { self.base = base }
}

// MARK: - Variant 1: Single-tier borrowing callAsFunction
// Hypothesis: Single borrowing closure works for both Copyable and ~Copyable
// Result: CONFIRMED — compiles, iterates, produces correct output

extension ForEachView where Base: IterableProtocol & ~Copyable {
    func callAsFunction(_ body: (borrowing Base.Element) -> Void) {
        var iterator = base.pointee.makeIterator()
        while let element = iterator.next() {
            body(element)
        }
    }
}

extension IterableProtocol where Self: ~Copyable {
    var forEach: ForEachView<Self> {
        mutating _read {
            yield ForEachView<Self>(&self)
        }
    }
}

// MARK: - Concrete types

struct Resource: ~Copyable {
    let id: Int
}

struct ResourceIterator: IterProto {
    var index: Int
    let count: Int
    let elements: [Int]

    mutating func next() -> Resource? {
        guard index < count else { return nil }
        let element = Resource(id: elements[index])
        index += 1
        return element
    }
}

struct ResourceContainer: ~Copyable, IterableProtocol {
    var elements: [Int]
    let count: Int

    func makeIterator() -> ResourceIterator {
        ResourceIterator(index: 0, count: count, elements: elements)
    }
}

struct IntIterator: IterProto {
    var storage: [Int]
    var index: Int = 0

    mutating func next() -> Int? {
        guard index < storage.count else { return nil }
        let element = storage[index]
        index += 1
        return element
    }
}

struct CopyableContainer: IterableProtocol {
    var storage: [Int]

    func makeIterator() -> IntIterator {
        IntIterator(storage: storage)
    }
}

// MARK: - Variant 2: ~Copyable elements via forEach
// Hypothesis: ~Copyable element iteration works
// Result: CONFIRMED — Resource(10), Resource(20), Resource(30)

print("~Copyable elements:")
var resources = ResourceContainer(elements: [10, 20, 30], count: 3)
resources.forEach { element in
    print("  Resource(\(element.id))")
}

// MARK: - Variant 3: Copyable elements via forEach
// Hypothesis: Copyable element iteration works through borrowing closure
// Result: CONFIRMED — 1, 2, 3
// Finding: No special syntax at call site. `borrowing` is invisible to caller.

print("Copyable elements:")
var copyable = CopyableContainer(storage: [1, 2, 3])
copyable.forEach { element in
    print("  \(element)")
}

// MARK: - Variant 4: Copyable operations inside borrowing closure
// Hypothesis: For Copyable elements, borrowing is transparent — can
//             copy, pass by value, use in expressions
// Result: CONFIRMED — all operations work: copy, pass, arithmetic

func takeInt(_ x: Int) { print("  took: \(x)") }

print("\nV4: Copyable operations inside borrowing closure")
var c4 = CopyableContainer(storage: [42])
c4.forEach { element in
    let copy = element
    takeInt(element)
    print("  doubled: \(element * 2)")
    _ = copy
}

// MARK: - Variant 5: ~Copyable borrow-only access
// Hypothesis: ~Copyable elements allow property reads but not consumption
// Result: CONFIRMED — can read .id, cannot consume

print("\nV5: ~Copyable borrow access")
var r5 = ResourceContainer(elements: [99], count: 1)
r5.forEach { element in
    let id = element.id
    print("  read id: \(id)")
}

// MARK: - Variant 6: Two-tier overloads (borrowing + by-value)
// Hypothesis: A second Copyable-only overload with by-value parameter
//             coexists with the borrowing overload
// Result: CONFIRMED — distinct method names (.borrowing/.byValue) work.
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Finding: Same-name callAsFunction overloads crash MoveOnlyChecker
//          when using stub bodies. Distinct names avoid the issue entirely.

struct ForEachView2<Base: ~Copyable>: ~Copyable {
    let base: UnsafeMutablePointer<Base>
    init(_ base: UnsafeMutablePointer<Base>) { self.base = base }
}

// Tier 1: ~Copyable (borrowing)
extension ForEachView2 where Base: IterableProtocol & ~Copyable {
    func borrowing(_ body: (borrowing Base.Element) -> Void) {
        var iterator = base.pointee.makeIterator()
        while let element = iterator.next() {
            body(element)
        }
    }
}

// Tier 2: Copyable convenience (by-value)
extension ForEachView2 where Base: IterableProtocol & ~Copyable, Base.Element: Copyable {
    func byValue(_ body: (Base.Element) -> Void) {
        var iterator = base.pointee.makeIterator()
        while let element = iterator.next() {
            body(element)
        }
    }
}

print("\nV6: Two-tier overloads")
print("Copyable by-value:")
var c6 = CopyableContainer(storage: [7, 8, 9])
ForEachView2(&c6).byValue { element in
    print("  \(element)")
}

print("~Copyable borrowing:")
var r6 = ResourceContainer(elements: [77], count: 1)
ForEachView2(&r6).borrowing { element in
    print("  Resource(\(element.id))")
}

print("Copyable also works via borrowing:")
var c6b = CopyableContainer(storage: [4, 5, 6])
ForEachView2(&c6b).borrowing { element in
    print("  \(element)")
}

// MARK: - Key Findings
// 1. Single-tier `(borrowing Base.Element)` works for BOTH Copyable and
//    ~Copyable elements — borrowing is transparent for Copyable types
// 2. Call-site syntax is identical: `container.forEach { element in ... }`
// 3. Inside the closure, Copyable elements can be copied, passed, used
//    in expressions — no visible restriction from `borrowing`
// 4. ~Copyable elements can be borrowed (read properties) but not consumed
// 5. Two-tier overloads work with distinct method names
// 6. Compiler bug: same-name overloads with borrowing vs by-value crash
//    MoveOnlyChecker in 6.2.3 when using stub function bodies

// MARK: - Results Summary
// V1: CONFIRMED — Infrastructure compiles and iterates
// V2: CONFIRMED — ~Copyable elements iterate correctly
// V3: CONFIRMED — Copyable elements iterate through borrowing closure
// V4: CONFIRMED — Copyable operations transparent inside borrowing
// V5: CONFIRMED — ~Copyable borrow-only access works
// V6: CONFIRMED — Two-tier overloads with distinct method names

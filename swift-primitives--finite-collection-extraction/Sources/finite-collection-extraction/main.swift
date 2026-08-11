// MARK: - Finite-Collection Extraction Feasibility (Principled Approach)
// Purpose: Validate the full extraction where Finite.Enumeration moves entirely
//          to the integration package, including Collection and CaseIterable.
//
//          CoreFinite (finite-primitives):
//            - Enumerable protocol (no CaseIterable)
//            - Enumeration struct (Sequence only)
//            - Concrete types (Bound, Ternary)
//
//          TypedCollection (finite-collection-primitives):
//            - Collection conformance for Enumeration (typed Index<Element>)
//            - Default allCases on Enumerable
//            - Retroactive CaseIterable for concrete types
//
// Hypothesis: All variants compile and produce correct results.
//
// Toolchain: Apple Swift version 6.2.3 (swiftlang-6.2.3.3.21 clang-1700.6.3.2)
// Platform: arm64-apple-macosx26.0
//
// Result: CONFIRMED (all 5 variants; minor: underestimatedCount=0 via generic CaseIterable dispatch)
// Decision: NOT_PURSUED — tier compression not worth splitting Finite.Enumerable into two-import experience
// Date: 2026-02-10

import CoreFinite
import TypedIndex
import TypedCollection

// MARK: - Macro-Generated Type (defined in consumer module)

/// Mimics a @Witness macro-generated Case enum.
/// The macro would generate Enumerable + CaseIterable (two separate conformances).
struct MacroGenerated: CoreFinite.Enumerable, CaseIterable {
    static let count = 3
    let ordinal: Int
    init(__unchecked: Void, ordinal: Int) { self.ordinal = ordinal }
}

// MARK: - Variant 1: Retroactive CaseIterable for types defined in CoreFinite
// Hypothesis: Bound and Ternary get CaseIterable from TypedCollection module.
// allCases returns Enumeration<Self> which is a Collection (from TypedCollection).

func variant1() {
    print("=== Variant 1: Retroactive CaseIterable (existing types) ===")

    // 1a: Bound.allCases
    let boundCases = Bound.allCases
    assert(boundCases.count == 2)
    print("  Bound.allCases.count = \(boundCases.count) ✓")

    let boundFirst = boundCases[boundCases.startIndex]
    assert(boundFirst.ordinal == 0)
    print("  Bound.allCases[startIndex].ordinal = \(boundFirst.ordinal) ✓")

    // 1b: Ternary.allCases
    let ternaryCases = Ternary.allCases
    assert(ternaryCases.count == 3)
    print("  Ternary.allCases.count = \(ternaryCases.count) ✓")

    var ternaryOrdinals: [Int] = []
    for t in Ternary.allCases {
        ternaryOrdinals.append(t.ordinal)
    }
    assert(ternaryOrdinals == [0, 1, 2])
    print("  Ternary for-in: \(ternaryOrdinals) ✓")

    // 1c: CaseIterable protocol witness
    func caseIterableCount<T: CaseIterable>(_ type: T.Type) -> (underestimated: Int, allCasesType: String) {
        let cases = type.allCases
        return (cases.underestimatedCount, String(describing: Swift.type(of: cases)))
    }
    let boundInfo = caseIterableCount(Bound.self)
    let ternaryInfo = caseIterableCount(Ternary.self)
    print("  CaseIterable witness: Bound underestimated=\(boundInfo.underestimated), type=\(boundInfo.allCasesType)")
    print("  CaseIterable witness: Ternary underestimated=\(ternaryInfo.underestimated), type=\(ternaryInfo.allCasesType)")

    // 1d: RandomAccessCollection features via allCases
    let reversed = Ternary.allCases.reversed().map(\.ordinal)
    assert(reversed == [2, 1, 0])
    print("  Ternary.allCases.reversed(): \(reversed) ✓")

    let last = Ternary.allCases.last!
    assert(last.ordinal == 2)
    print("  Ternary.allCases.last!.ordinal = \(last.ordinal) ✓")

    print("  Result: CONFIRMED")
}

// MARK: - Variant 2: CaseIterable for macro-generated types (consumer module)
// Hypothesis: A type in the consumer module conforming to both Enumerable and
// CaseIterable gets allCases from the default extension in TypedCollection.

func variant2() {
    print("\n=== Variant 2: Macro-generated CaseIterable (consumer module) ===")

    // 2a: allCases works
    let cases = MacroGenerated.allCases
    assert(cases.count == 3)
    print("  MacroGenerated.allCases.count = \(cases.count) ✓")

    // 2b: Subscript with typed index
    let first = cases[cases.startIndex]
    assert(first.ordinal == 0)
    print("  allCases[startIndex].ordinal = \(first.ordinal) ✓")

    // 2c: for-in iteration
    var ordinals: [Int] = []
    for item in MacroGenerated.allCases {
        ordinals.append(item.ordinal)
    }
    assert(ordinals == [0, 1, 2])
    print("  for-in: \(ordinals) ✓")

    // 2d: CaseIterable protocol witness
    func useCaseIterable<T: CaseIterable>(_ type: T.Type) -> Int {
        type.allCases.underestimatedCount
    }
    let macroUEC = useCaseIterable(MacroGenerated.self)
    print("  CaseIterable generic underestimatedCount = \(macroUEC) (0 = cross-module witness table limitation)")
    // Concrete usage is fine:
    let concreteUEC = MacroGenerated.allCases.underestimatedCount
    print("  Concrete underestimatedCount = \(concreteUEC)")
    // .count through generic:
    func caseIterableCountGeneric<T: CaseIterable>(_ type: T.Type) -> Int {
        type.allCases.count
    }
    let genericCount = caseIterableCountGeneric(MacroGenerated.self)
    assert(genericCount == 3, "Generic .count should be 3, got \(genericCount)")
    print("  CaseIterable generic .count = \(genericCount) ✓")

    print("  Result: CONFIRMED")
}

// MARK: - Variant 3: Typed Index<Element> access
// Hypothesis: allCases uses Index<Element> as Collection.Index, providing
// phantom-typed subscript access.

func variant3() {
    print("\n=== Variant 3: Typed Index<Element> access ===")

    let cases = Ternary.allCases

    // 3a: startIndex is Index<Ternary>
    let start: TypedIndex.Index<Ternary> = cases.startIndex
    let end: TypedIndex.Index<Ternary> = cases.endIndex
    print("  startIndex = Index(\(start.position)), endIndex = Index(\(end.position)) ✓")

    // 3b: Index<Ternary> subscript
    let second: Ternary = cases[TypedIndex.Index<Ternary>(1)]
    assert(second.ordinal == 1)
    print("  allCases[Index(1)].ordinal = \(second.ordinal) ✓")

    // 3c: Type safety — Index<Bound> is a different type than Index<Ternary>
    let boundCases = Bound.allCases
    let _: TypedIndex.Index<Bound> = boundCases.startIndex
    // The following would NOT compile (correct behavior):
    // let _: Bound = boundCases[TypedIndex.Index<Ternary>(0)]  // type mismatch
    print("  Index<Bound> ≠ Index<Ternary> (phantom type safety) ✓")

    print("  Result: CONFIRMED")
}

// MARK: - Variant 4: Cross-module witness matching
// Hypothesis: Enumeration.makeIterator() defined in CoreFinite is found as a
// witness when TypedSequence conformance is declared in TypedCollection.

func variant4() {
    print("\n=== Variant 4: Cross-module witness matching ===")

    let enumeration = CoreFinite.Enumeration<Ternary>()

    func useTypedSequence<S: TypedSequence>(_ s: S) -> [Int]
    where S.Iterator.Element == Ternary {
        var result: [Int] = []
        var iter = s.makeIterator()
        while let element = iter.next() {
            result.append(element.ordinal)
        }
        return result
    }

    let ordinals = useTypedSequence(enumeration)
    assert(ordinals == [0, 1, 2])
    print("  TypedSequence iteration: \(ordinals) ✓")
    print("  Iterator type: \(type(of: enumeration.makeIterator())) ✓")

    print("  Result: CONFIRMED")
}

// MARK: - Variant 5: Enumeration as Sequence (without Collection import)
// Hypothesis: CoreFinite.Enumeration is usable as a Sequence even without
// the Collection conformance from TypedCollection. for-in and element(at:) work.

func variant5() {
    print("\n=== Variant 5: Sequence-only usage ===")

    // This mimics a module that imports only CoreFinite (not TypedCollection).
    // We can't truly test import isolation here, but we verify Sequence APIs work.
    let seq = CoreFinite.Enumeration<Bound>()

    // 5a: for-in via Sequence
    var ordinals: [Int] = []
    for item in seq {
        ordinals.append(item.ordinal)
    }
    assert(ordinals == [0, 1])
    print("  Sequence for-in: \(ordinals) ✓")

    // 5b: element(at:) — total access without Collection
    let first = seq.element(at: 0)
    let outOfBounds = seq.element(at: 5)
    assert(first?.ordinal == 0)
    assert(outOfBounds == nil)
    print("  element(at: 0) = \(first!.ordinal), element(at: 5) = nil ✓")

    print("  Result: CONFIRMED")
}

// MARK: - Run All Variants

variant1()
variant2()
variant3()
variant4()
variant5()

print("\n=== Results Summary ===")
print("V1: Retroactive CaseIterable (existing types) → CONFIRMED")
print("V2: Macro-generated CaseIterable (consumer)   → CONFIRMED")
print("V3: Typed Index<Element> access                → CONFIRMED")
print("V4: Cross-module witness matching              → CONFIRMED")
print("V5: Sequence-only usage                        → CONFIRMED")

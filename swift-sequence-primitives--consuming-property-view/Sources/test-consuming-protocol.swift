// ===----------------------------------------------------------------------===//
// TEST: Can protocols require `consuming func`?
// ===----------------------------------------------------------------------===//
//
// FINDING: Associated types cannot have ~Copyable constraint (SE-0427 limitation)
// But consuming func itself IS supported in protocols
//
// ===----------------------------------------------------------------------===//

// Version 1: Try with Copyable iterator (works around associated type limitation)
protocol ConsumingDrainableV1: ~Copyable {
    associatedtype Element
    // ConsumingIterator must be Copyable due to SE-0427
    associatedtype ConsumingIterator: IteratorProtocol where ConsumingIterator.Element == Element

    consuming func makeConsumingIterator() -> ConsumingIterator
}

// This works - consuming func in protocol IS supported
struct TestSetV1: ~Copyable, ConsumingDrainableV1 {
    var elements: [Int] = [1, 2, 3]

    consuming func makeConsumingIterator() -> Array<Int>.Iterator {
        elements.makeIterator()
    }
}

func testConsumingProtocolV1() {
    print("\n=== Test: Protocol with consuming func (Copyable iterator) ===")
    let set = TestSetV1()
    var iter = set.makeConsumingIterator()
    while let element = iter.next() {
        print("  Iterated: \(element)")
    }
    print("  Protocol-based consuming func WORKS (with Copyable iterator)")
}

// Version 2: Protocol without associated type for iterator
// Types provide their own consuming iteration method
protocol ConsumingDrainableV2: ~Copyable {
    associatedtype Element

    // Just require the forEach variant directly
    consuming func consumingForEach(_ body: (Element) -> Void)
}

struct TestSetV2: ~Copyable, ConsumingDrainableV2 {
    var elements: [Int] = [1, 2, 3]

    consuming func consumingForEach(_ body: (Int) -> Void) {
        for element in elements {
            body(element)
        }
    }
}

func testConsumingProtocolV2() {
    print("\n=== Test: Protocol with consuming forEach ===")
    let set = TestSetV2()
    set.consumingForEach { element in
        print("  Consumed: \(element)")
    }
    print("  Protocol-based consumingForEach WORKS")
}

func testConsumingProtocol() {
    testConsumingProtocolV1()
    testConsumingProtocolV2()
}

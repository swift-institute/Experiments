// ===----------------------------------------------------------------------===//
// TEST 1: `consuming get` accessor limitations
// ===----------------------------------------------------------------------===//
//
// FINDING: `consuming get` is SYNTACTICALLY accepted but SEMANTICALLY LIMITED
//
// It cannot:
// - Move stored properties out of self
// - Return self
// - Actually consume self in a meaningful way
//
// It CAN:
// - Return trivially copyable values (Int, etc.)
// - Mark self as consumed for lifetime checking
//
// CONCLUSION: `consuming get` is NOT useful for draining containers
//
// ===----------------------------------------------------------------------===//

struct TestContainer: ~Copyable {
    var value: Int = 42

    // Works syntactically, but value is Int (trivially copyable)
    var consumingProperty: Int {
        consuming get {
            return value
        }
    }
}

func testConsumingGet() {
    print("\n=== Test: Consuming get accessor ===")
    let container = TestContainer()
    let val = container.consumingProperty
    print("  Got value: \(val)")
    print("  Container marked as consumed (but Int is trivially copyable)")
}

// These all FAIL - "self is borrowed and cannot be consumed":
//
// 1. Cannot move stored property:
// struct Container2: ~Copyable {
//     var elements: [Int]
//     var drain: [Int] {
//         consuming get { elements }  // ERROR
//     }
// }
//
// 2. Cannot return self:
// struct Container3: ~Copyable {
//     var consumed: Self {
//         consuming get { self }  // ERROR
//     }
// }
//
// 3. Cannot create wrapper from stored property:
// struct Container4: ~Copyable {
//     var elements: [Int]
//     var drainer: Drainer {
//         consuming get { Drainer(elements: elements) }  // ERROR
//     }
// }

// ONLY WORKING PATTERN: consuming func
struct Container2: ~Copyable {
    var elements: [Int] = [1, 2, 3]

    // This works
    consuming func makeDrainer() -> Drainer {
        Drainer(elements: elements)
    }
}

struct Drainer: ~Copyable {
    var elements: [Int]

    consuming func forEach(_ body: (Int) -> Void) {
        for element in elements {
            body(element)
        }
    }
}

func testConsumingPropertyDrain() {
    print("\n=== Test: Consuming func (only working pattern) ===")
    let container = Container2()
    container.makeDrainer().forEach { element in
        print("  Drained: \(element)")
    }
    print("  Container consumed via consuming func")
}

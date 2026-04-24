// MARK: - Variant 7: Same-module isolation tests
// Purpose: Isolate exactly which combination of factors breaks generic subscripts.
// Hypothesis: Generic extension subscripts on stdlib types fail to resolve.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.2 (arm64)
//
// Result: <PENDING>
// Date: 2026-02-10

// ── Shared types ──────────────────────────────────────────────

protocol P {
    var rawValue: Int { get }
    init(rawValue: Int)
}

struct Concrete: P {
    var rawValue: Int
    init(rawValue: Int) { self.rawValue = rawValue }
}

struct Tagged<Tag, Wrapped> {
    var wrapped: Wrapped
    init(_ wrapped: Wrapped) { self.wrapped = wrapped }
}

extension Tagged: P where Wrapped == Concrete {
    var rawValue: Int { wrapped.rawValue }
    init(rawValue: Int) { self.init(Concrete(rawValue: rawValue)) }
}

struct MyBuffer<Element> {
    var storage: [Element]
    init(_ elements: Element...) { self.storage = elements }
}

// MARK: - Test A: Generic subscript on MY OWN type
// Hypothesis: Generic subscripts work on non-stdlib types

extension MyBuffer {
    subscript<O: P>(position: O) -> Element {
        get { storage[position.rawValue] }
    }
}

func testA() {
    var buf = MyBuffer(10, 20, 30)
    let idx = Concrete(rawValue: 1)
    let value = buf[position: idx]
    print("V7-A MyBuffer generic: \(value)")
}

// MARK: - Test B: Generic subscript on UnsafePointer with STDLIB protocol
// Hypothesis: Maybe only custom protocols fail

extension UnsafePointer {
    subscript<I: BinaryInteger>(offset: I) -> Pointee {
        get { unsafe self[Int(offset)] }
    }
}

func testB() {
    let values: [Int] = [10, 20, 30]
    values.withUnsafeBufferPointer { buf in
        let ptr = buf.baseAddress!
        let value = unsafe ptr[offset: UInt(1)]
        print("V7-B UnsafePointer + BinaryInteger: \(value)")
    }
}

// MARK: - Test C: Non-generic subscript on UnsafePointer with custom type
// Hypothesis: Custom type arguments work if not generic

extension UnsafePointer {
    subscript(concrete: Concrete) -> Pointee {
        get { unsafe self[concrete.rawValue] }
    }
}

func testC() {
    let values: [Int] = [10, 20, 30]
    values.withUnsafeBufferPointer { buf in
        let ptr = buf.baseAddress!
        let idx = Concrete(rawValue: 1)
        let value = unsafe ptr[idx]
        print("V7-C UnsafePointer + Concrete (non-generic): \(value)")
    }
}

// MARK: - Test D: Generic subscript on UnsafePointer with custom protocol (THE BUG)
// Hypothesis: This is what fails

extension UnsafePointer {
    subscript<O: P>(position: O) -> Pointee {
        get { unsafe self[position.rawValue] }
    }
}

func testD() {
    let values: [Int] = [10, 20, 30]
    values.withUnsafeBufferPointer { buf in
        let ptr = buf.baseAddress!
        let idx = Concrete(rawValue: 1)
        let value = unsafe ptr[position: idx]
        print("V7-D UnsafePointer + generic P: \(value)")
    }
}

// MARK: - Test E: Generic METHOD on UnsafePointer with custom protocol
// Hypothesis: Maybe only subscripts break, not methods

extension UnsafePointer {
    func element<O: P>(at position: O) -> Pointee {
        unsafe self[position.rawValue]
    }
}

func testE() {
    let values: [Int] = [10, 20, 30]
    values.withUnsafeBufferPointer { buf in
        let ptr = buf.baseAddress!
        let idx = Concrete(rawValue: 1)
        let value = unsafe ptr.element(at: idx)
        print("V7-E UnsafePointer method + generic P: \(value)")
    }
}

// MARK: - Run all tests

testA()
testB()
testC()
testD()
testE()

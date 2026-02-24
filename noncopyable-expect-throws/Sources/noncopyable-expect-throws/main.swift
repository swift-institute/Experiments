// MARK: - Noncopyable Expect Throws
// Purpose: Isolate whether closures capturing ~Copyable vars for mutating
//          throwing calls release the borrow correctly after throw.
// Hypothesis: Basic closures handle this correctly; the hang is specific
//             to #expect(throws:) macro expansion in Swift Testing.
//
// Toolchain: TBD
// Platform: macOS (arm64)
//
// Result: TBD
// Date: 2026-02-10

// MARK: - Minimal ~Copyable type

struct Box: ~Copyable {
    var value: Int = 0
    enum Err: Error { case full }

    mutating func fill() throws(Err) {
        guard value < 2 else { throw .full }
        value += 1
    }
}

// MARK: - Variant 1: Direct do/catch (baseline)
// Hypothesis: Direct do/catch works — no closure, no capture.
// Result: TBD

func variant1() {
    print("V1: Direct do/catch...")
    var box = Box()
    try! box.fill()
    try! box.fill()
    do {
        try box.fill()
        print("V1: FAIL — should have thrown")
    } catch {
        print("V1: PASS — caught \(error)")
    }
    print("V1: value = \(box.value)")
}

// MARK: - Variant 2: Closure captures ~Copyable var, throws
// Hypothesis: A closure capturing ~Copyable var for mutating throwing call
//             releases the borrow after throw.
// Result: TBD

func variant2() {
    print("V2: Closure + ~Copyable + throw...")
    var box = Box()
    try! box.fill()
    try! box.fill()

    let closure: () throws -> Void = { try box.fill() }
    do {
        try closure()
        print("V2: FAIL — should have thrown")
    } catch {
        print("V2: PASS — caught \(error)")
    }
    print("V2: value = \(box.value)")
}

// MARK: - Variant 3: Closure captures ~Copyable var, does NOT throw
// Hypothesis: Non-throwing closure with ~Copyable capture works.
// Result: TBD

func variant3() {
    print("V3: Closure + ~Copyable + no throw...")
    var box = Box()
    let closure: () throws -> Void = { try box.fill() }
    do {
        try closure()
        print("V3: PASS — fill succeeded, value = \(box.value)")
    } catch {
        print("V3: FAIL — unexpected throw: \(error)")
    }
}

// MARK: - Run all variants

variant1()
variant2()
variant3()
print("EXIT: clean shutdown")

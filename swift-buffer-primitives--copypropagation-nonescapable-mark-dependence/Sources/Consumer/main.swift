// Consumer module: exercises the wrapper to trigger deep cross-module inlining.
// The SIL optimizer inlines Middle into Consumer, creating the deep chain.

import Middle

// ─── V1: Basic clear pattern ───

@inlinable
public func testClear() {
    var wrapper = Wrapper<Int>(capacity: 8)
    wrapper.clear(keepingCapacity: true)
    wrapper.clear(keepingCapacity: false)
}

// ─── V2: Clear and check ───

@inlinable
public func testClearAndCheck() {
    var wrapper = Wrapper<Int>(capacity: 8)
    let _ = wrapper.clearAndCheck()
}

// ─── V3: Try/catch ───

@inlinable
public func testTryClear() {
    var wrapper = Wrapper<Int>(capacity: 8)
    wrapper.tryClear()
}

// Exercise all variants
testClear()
testClearAndCheck()
testTryClear()
print("OK")

// MARK: - Mutable Cross-Module Ambiguity Experiment — Consumer Tests
// (See PointerLayer/Pointer.swift for variants A-G, PointerH.swift for variant H)
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21 clang-1700.6.3.2)
// Platform: macOS 26.2 (arm64)
// Date: 2026-01-28

import MemoryLayer
import PointerLayer

#if VARIANT_H

// --- Test 1: PointerH<Int>.Mutable in expression context ---
func testExpression() {
    let ptr = UnsafeMutablePointer<Int>.allocate(capacity: 1)
    unsafe ptr.initialize(to: 99)
    let typedPtr = unsafe PointerH<Int>.Mutable(pointerH: ptr)
    print("Expression: \(unsafe typedPtr.baseH.pointee)")
    unsafe ptr.deallocate()
}

// --- Test 2: PointerH<Int>.Mutable in function parameter ---
func acceptMutable(_ ptr: PointerH<Int>.Mutable) {
    print("Param: \(unsafe ptr.baseH.pointee)")
}

// --- Test 3: PointerH<Int>.Mutable as return type ---
func makeMutable() -> PointerH<Int>.Mutable {
    let ptr = UnsafeMutablePointer<Int>.allocate(capacity: 1)
    unsafe ptr.initialize(to: 33)
    return unsafe PointerH<Int>.Mutable(pointerH: ptr)
}

// --- Test 4: PointerH<Int>.Mutable in local type annotation ---
func testLocal() {
    let ptr = UnsafeMutablePointer<Int>.allocate(capacity: 1)
    unsafe ptr.initialize(to: 77)
    let typedPtr: PointerH<Int>.Mutable = unsafe PointerH<Int>.Mutable(pointerH: ptr)
    print("Local: \(unsafe typedPtr.baseH.pointee)")
    unsafe ptr.deallocate()
}

// --- Test 5: MemoryH.Mutable.Address (the unified mutable address) ---
func testMemoryMutableAddress() {
    var value: Int = 42
    let addr = unsafe MemoryH.Mutable.Address(&value)
    print("MemoryH.Mutable.Address: \(addr)")
}

// --- Test 6: MemoryH.Address (immutable address) ---
func testMemoryAddress() {
    var value: Int = 10
    let addr = unsafe withUnsafePointer(to: &value) { MemoryH.Address($0) }
    print("MemoryH.Address: \(addr)")
}

// --- Test 7: copy from immutable to mutable ---
func testCopy() {
    let src = UnsafeMutablePointer<Int>.allocate(capacity: 2)
    unsafe src.initialize(to: 100)
    unsafe (src + 1).initialize(to: 200)

    let dst = UnsafeMutablePointer<Int>.allocate(capacity: 2)

    let immutable = unsafe PointerH<Int>(pointerH: UnsafePointer(src))
    let mutable = unsafe PointerH<Int>.Mutable(pointerH: dst)
    unsafe immutable.copyH(to: mutable, count: 2)
    print("Copied: \(unsafe dst.pointee), \(unsafe (dst + 1).pointee)")

    unsafe src.deallocate()
    unsafe dst.deallocate()
}

// --- Run all ---
unsafe testExpression()
unsafe testLocal()

do {
    let ptr = UnsafeMutablePointer<Int>.allocate(capacity: 1)
    unsafe ptr.initialize(to: 55)
    unsafe acceptMutable(PointerH<Int>.Mutable(pointerH: ptr))
    unsafe ptr.deallocate()
}

do {
    let result = unsafe makeMutable()
    print("Return: \(unsafe result.baseH.pointee)")
    unsafe result.baseH.deallocate()
}

unsafe testMemoryMutableAddress()
unsafe testMemoryAddress()
unsafe testCopy()

print("All consumer Variant H tests passed!")

#elseif VARIANT_C

func testExpressionOnly() {
    let ptr = UnsafeMutablePointer<Int>.allocate(capacity: 1)
    unsafe ptr.initialize(to: 99)
    let typedPtr = unsafe Pointer<Int>.Mutable(ptr)
    print("Expression context: \(unsafe typedPtr.base.pointee)")
    unsafe ptr.deallocate()
}

unsafe testExpressionOnly()
print("Consumer VARIANT_C expression test passed!")

#else
print("Consumer: no variant selected")
#endif

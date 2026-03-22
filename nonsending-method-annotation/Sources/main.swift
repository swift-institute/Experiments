// MARK: - Nonsending Method Annotation Validation
// Purpose: Validate that nonisolated(nonsending) on callAsFunction() method
//          propagates isolation identically to the deprecated isolation: parameter.
//          Specifically tests the #83812 workaround: does `await self()` in
//          map/flatMap still propagate isolation through method dispatch?
//
// Toolchain: Apple Swift 6.2 (Xcode 26)
// Platform: macOS 26.0 (arm64)
//
// Tests:
//   T1: Basic callAsFunction isolation — does @MainActor caller stay on MainActor?
//   T2: map isolation — does sync transform in map run on MainActor?
//   T3: Chained map isolation — does 3-level chain preserve isolation?
//   T4: flatMap isolation — does flatMap preserve isolation?
//   T5: Non-Sendable Value — does unconstrained Value work?
//   T6: Double-nonsending pattern — function + operation closure both nonsending
//   T7: sending parameter — nonisolated(nonsending) with sending Element
//
// Date: 2026-03-22

import Darwin

func isMainThread() -> Bool {
    pthread_main_np() != 0
}

// ============================================================================
// MARK: - Approach A: nonisolated(nonsending) on method (NEW — stdlib pattern)
// ============================================================================

struct Callback<Value> {
    @usableFromInline
    let operation: nonisolated(nonsending) () async -> Value

    @inlinable
    init(_ operation: nonisolated(nonsending) @escaping () async -> Value) {
        self.operation = operation
    }

    @inlinable
    init(value: Value) {
        self.operation = { value }
    }

    // NEW PATTERN: nonisolated(nonsending) on method itself
    // No isolation: parameter needed
    @inlinable
    nonisolated(nonsending)
    func callAsFunction() async -> Value {
        await operation()
    }

    // map uses `await self()` — the #83812 workaround
    @inlinable
    func map<NewValue>(
        _ transform: @escaping (Value) -> NewValue
    ) -> Callback<NewValue> {
        .init { transform(await self()) }
    }

    @inlinable
    func flatMap<NewValue>(
        _ transform: @escaping (Value) -> Callback<NewValue>
    ) -> Callback<NewValue> {
        .init { await transform(await self())() }
    }
}

// ============================================================================
// MARK: - Approach B: isolation: parameter (OLD — deprecated pattern)
// For comparison to ensure identical behavior
// ============================================================================

struct CallbackOld<Value> {
    let operation: nonisolated(nonsending) () async -> Value

    init(_ operation: nonisolated(nonsending) @escaping () async -> Value) {
        self.operation = operation
    }

    init(value: Value) {
        self.operation = { value }
    }

    // OLD PATTERN: isolation: parameter
    func callAsFunction(
        isolation: isolated (any Actor)? = #isolation
    ) async -> Value {
        await operation()
    }

    func map<NewValue>(
        _ transform: @escaping (Value) -> NewValue
    ) -> CallbackOld<NewValue> {
        .init { transform(await self()) }
    }

    func flatMap<NewValue>(
        _ transform: @escaping (Value) -> CallbackOld<NewValue>
    ) -> CallbackOld<NewValue> {
        .init { await transform(await self())() }
    }
}

// ============================================================================
// MARK: - Non-Sendable test type
// ============================================================================

class NonSendableBox {
    var value: Int
    init(_ value: Int) { self.value = value }
}

// ============================================================================
// MARK: - T1: Basic callAsFunction isolation
// ============================================================================

@MainActor
func testT1() async {
    print("--- T1: Basic callAsFunction isolation ---")

    let callbackNew = Callback { 42 }
    let resultNew = await callbackNew.callAsFunction()
    let onMainNew = isMainThread()

    let callbackOld = CallbackOld { 42 }
    let resultOld = await callbackOld.callAsFunction()
    let onMainOld = isMainThread()

    print("  NEW: mainThread=\(onMainNew)")
    print("  OLD: mainThread=\(onMainOld)")
    print("  T1: \(onMainNew && onMainOld ? "PASS" : "FAIL") — both preserve MainActor")
}

// ============================================================================
// MARK: - T2: map isolation
// ============================================================================

@MainActor
func testT2() async {
    print("--- T2: map isolation ---")

    var newOnMain = false
    let callbackNew = Callback { 21 }.map { value -> Int in
        newOnMain = isMainThread()
        return value * 2
    }
    let resultNew = await callbackNew()

    var oldOnMain = false
    let callbackOld = CallbackOld { 21 }.map { value -> Int in
        oldOnMain = isMainThread()
        return value * 2
    }
    let resultOld = await callbackOld()

    print("  NEW: value=\(resultNew), transform on mainThread=\(newOnMain)")
    print("  OLD: value=\(resultOld), transform on mainThread=\(oldOnMain)")
    print("  T2: \(newOnMain && oldOnMain ? "PASS" : "FAIL") — map transform runs on MainActor")
}

// ============================================================================
// MARK: - T3: Chained map isolation (3 levels)
// ============================================================================

@MainActor
func testT3() async {
    print("--- T3: Chained map isolation (3 levels) ---")

    var level1 = false, level2 = false, level3 = false
    let callback = Callback { 10 }
        .map { v -> Int in level1 = isMainThread(); return v + 1 }
        .map { v -> Int in level2 = isMainThread(); return v * 2 }
        .map { v -> Int in level3 = isMainThread(); return v - 3 }
    let result = await callback()

    print("  value=\(result), L1=\(level1), L2=\(level2), L3=\(level3)")
    print("  T3: \(level1 && level2 && level3 ? "PASS" : "FAIL") — all 3 levels on MainActor")
}

// ============================================================================
// MARK: - T4: flatMap isolation
// ============================================================================

@MainActor
func testT4() async {
    print("--- T4: flatMap isolation ---")

    var outerOnMain = false, innerOnMain = false
    let callback = Callback { 10 }.flatMap { value -> Callback<Int> in
        outerOnMain = isMainThread()
        return Callback { innerOnMain = isMainThread(); return value * 3 }
    }
    let result = await callback()

    print("  value=\(result), outer=\(outerOnMain), inner=\(innerOnMain)")
    print("  T4: \(outerOnMain && innerOnMain ? "PASS" : "FAIL") — flatMap preserves MainActor")
}

// ============================================================================
// MARK: - T5: Non-Sendable Value
// ============================================================================

@MainActor
func testT5() async {
    print("--- T5: Non-Sendable Value ---")

    let callback = Callback { NonSendableBox(42) }
        .map { box -> Int in box.value * 2 }
    let result = await callback()

    print("  value=\(result)")
    print("  T5: \(result == 84 ? "PASS" : "FAIL") — non-Sendable Value works")
}

// ============================================================================
// MARK: - T6: Double-nonsending pattern (withDependencies-style)
// ============================================================================

nonisolated(nonsending)
func withScope<T, E: Error>(
    _ modify: () -> Void,
    operation: nonisolated(nonsending) () async throws(E) -> T
) async throws(E) -> T {
    modify()
    return try await operation()
}

@MainActor
func testT6() async {
    print("--- T6: Double-nonsending pattern ---")

    var modifyOnMain = false
    var operationOnMain = false

    let result = await withScope({
        modifyOnMain = isMainThread()
    }, operation: {
        operationOnMain = isMainThread()
        return 42
    })

    print("  value=\(result), modify=\(modifyOnMain), operation=\(operationOnMain)")
    print("  T6: \(modifyOnMain && operationOnMain ? "PASS" : "FAIL") — both closures on MainActor")
}

// ============================================================================
// MARK: - T7: sending parameter with nonisolated(nonsending) function
// ============================================================================

struct Sender<Element: Sendable> {
    nonisolated(nonsending)
    func send(_ element: sending Element) async {
        // Simulates Channel.send pattern
        _ = element
    }
}

@MainActor
func testT7() async {
    print("--- T7: sending parameter with nonisolated(nonsending) ---")

    let sender = Sender<Int>()
    await sender.send(42)
    let onMain = isMainThread()

    print("  mainThread=\(onMain)")
    print("  T7: \(onMain ? "PASS" : "FAIL") — sending param + nonsending method on MainActor")
}

// ============================================================================
// MARK: - Runner
// ============================================================================

@MainActor
func main() async {
    print("=== Nonsending Method Annotation Validation ===")
    print()

    await testT1()
    print()
    await testT2()
    print()
    await testT3()
    print()
    await testT4()
    print()
    await testT5()
    print()
    await testT6()
    print()
    await testT7()
    print()

    print("=== All tests complete ===")
}

await main()

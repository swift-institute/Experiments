// Status: SUPERSEDED -- compiler-limitation finding stable; production uses .position.rawValue workaround per [COPY-FIX-*]. (Phase 1b stale-triage 2026-04-30)
// Revalidated: Swift 6.3.1 (2026-04-30) — SUPERSEDED (per existing Status line; not re-run)
// ============================================================================
// EXPERIMENT: pointer-subscript-modify
// ============================================================================
// HYPOTHESIS: Custom UnsafeMutablePointer subscript with unsafeMutableAddress
//             should work in _modify context with `yield &`, just like stdlib's
//             ptr[Int] subscript.
//
// TRIGGER: In production code, `yield &(unsafe ptr[index])` fails with:
//          "cannot yield immutable value" or "cannot assign through subscript"
//          But `yield &(unsafe ptr[index.position.rawValue])` (using Int) works.
//
// RESULT: CONFIRMED - This is a Swift compiler limitation/bug
// ============================================================================
//
// FINDINGS:
//
// | Variant | Pattern                  | Subscript    | Result |
// |---------|--------------------------|--------------|--------|
// | V1      | Direct storage           | Int (stdlib) | PASS   |
// | V4      | Direct storage           | TypedIndex   | PASS   |
// | V5      | if-let                   | Int (stdlib) | PASS   |
// | V6      | if-let                   | TypedIndex   | FAIL   |
// | V7      | if-let + let ptr         | TypedIndex   | FAIL   |
// | V8      | if-let + VAR ptr         | TypedIndex   | PASS   |
// | V9      | Force unwrap             | TypedIndex   | PASS   |
// | V10     | guard let                | TypedIndex   | FAIL   |
//
// ROOT CAUSE:
// Custom subscripts with `unsafeMutableAddress` accessor don't receive the
// same special compiler treatment as the stdlib's Int subscript when accessed
// through let-bound values from optional binding (if-let, guard-let).
//
// The stdlib's `UnsafeMutablePointer.subscript(i: Int)` is hardcoded in the
// compiler to be recognized as providing mutable access even through let
// bindings. Custom subscripts don't get this treatment.
//
// WORKAROUNDS (both work):
// 1. Use `var ptr = heap.pointer` intermediate variable
// 2. Use force unwrap `heap!.pointer[typed: index]`
//
// RECOMMENDED: Use `var` intermediate for safety (avoids force unwrap):
//     if let heap {
//         var ptr = heap.pointer
//         yield &(unsafe ptr[typed: index])
//     }
//
// ============================================================================

// MARK: - V2: Custom typed index (like Index<Element>) - PUBLIC

public struct TypedIndex: Sendable {
    public var rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let zero = TypedIndex(rawValue: 0)
}

// MARK: - V3: Custom subscript

extension UnsafeMutablePointer {
    @inlinable
    subscript(typed index: TypedIndex) -> Pointee {
        unsafeAddress {
            unsafe UnsafePointer(self + index.rawValue)
        }
        unsafeMutableAddress {
            unsafe self + index.rawValue
        }
    }
}

// MARK: - V1: Direct storage with Int subscript

struct V1_Container {
    var storage: UnsafeMutablePointer<Int>

    subscript(index: Int) -> Int {
        _read { yield unsafe storage[index] }
        _modify { yield &(unsafe storage[index]) }
    }
}

// MARK: - V4: Direct storage with custom subscript (no if-let)

struct V4_Container {
    var storage: UnsafeMutablePointer<Int>

    subscript(index: TypedIndex) -> Int {
        _read { yield unsafe storage[typed: index] }
        _modify { yield &(unsafe storage[typed: index]) }
    }
}

// MARK: - V5: if-let with Int subscript

struct V5_Heap {
    var pointer: UnsafeMutablePointer<Int>
}

struct V5_Container_Int {
    var heap: V5_Heap?

    subscript(index: Int) -> Int {
        _read {
            if let heap { yield unsafe heap.pointer[index] }
            else { fatalError() }
        }
        _modify {
            if let heap { yield &(unsafe heap.pointer[index]) }
            else { fatalError() }
        }
    }
}

// MARK: - V8: if-let with VAR intermediate (WORKAROUND)

struct V8_Container_IntermediateVar {
    var heap: V5_Heap?

    subscript(index: TypedIndex) -> Int {
        _read {
            if let heap { yield unsafe heap.pointer[typed: index] }
            else { fatalError() }
        }
        _modify {
            if let heap {
                var ptr = heap.pointer  // VAR, not LET - this is the workaround
                yield &(unsafe ptr[typed: index])
            } else { fatalError() }
        }
    }
}

// MARK: - V9: Force unwrap instead of if-let (ALTERNATIVE WORKAROUND)

struct V9_Container_ForceUnwrap {
    var heap: V5_Heap?

    subscript(index: TypedIndex) -> Int {
        _read { yield unsafe heap!.pointer[typed: index] }
        _modify { yield &(unsafe heap!.pointer[typed: index]) }
    }
}

// MARK: - Test

func main() {
    let buffer = UnsafeMutablePointer<Int>.allocate(capacity: 10)
    buffer.initialize(repeating: 0, count: 10)
    defer { buffer.deallocate() }

    var v1 = V1_Container(storage: buffer)
    v1[0] = 42
    print("V1 (direct Int subscript) passed: \(v1[0])")

    var v4 = V4_Container(storage: buffer)
    v4[.zero] = 100
    print("V4 (direct typed subscript) passed: \(v4[.zero])")

    var v5 = V5_Container_Int(heap: V5_Heap(pointer: buffer))
    v5[0] = 200
    print("V5 (if-let Int subscript) passed: \(v5[0])")

    var v8 = V8_Container_IntermediateVar(heap: V5_Heap(pointer: buffer))
    v8[.zero] = 500
    print("V8 (if-let VAR intermediate) passed: \(v8[.zero])")

    var v9 = V9_Container_ForceUnwrap(heap: V5_Heap(pointer: buffer))
    v9[.zero] = 600
    print("V9 (force unwrap) passed: \(v9[.zero])")

    print("All tests passed!")
}

main()

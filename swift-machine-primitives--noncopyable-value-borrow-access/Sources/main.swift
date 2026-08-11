// Toolchain: Swift 6.3.1 (2026-04-30) — anchor added during Phase 7a sweep [EXP-007a]
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//
// ===----------------------------------------------------------------------===//
// Experiment: ~Copyable Value with Borrow Access
//
// Purpose: Validate that Machine.Value can be evolved to:
//   1. Store ~Copyable payloads (via `consuming` construction)
//   2. Provide borrow access via `_read` subscript (no closure)
//   3. Provide borrow access via ~Escapable Ref (lifetime-dependent)
//   4. Maintain backward compatibility via deprecated aliases
//   5. Enable rendering-style dispatch (type-erased borrow through raw pointer)
//
// If all tests pass → implement in Machine Value Primitives production code.
// ===----------------------------------------------------------------------===//

import Testing

// MARK: - Mode Infrastructure (mirrors Machine.Capture.Mode)

enum Mode {}
extension Mode {
    struct Reference: Sendable { init() {} }
    struct Unchecked { init() {} }
}

// MARK: - Value (mirrors Machine.Value with ~Copyable improvements)

@safe
struct Value<M> {
    @usableFromInline
    let type: ObjectIdentifier

    @usableFromInline
    let storage: _Storage

    @usableFromInline
    final class _Storage: @unchecked Sendable {
        @usableFromInline
        let payload: UnsafeMutableRawPointer

        @usableFromInline
        let table: _Table

        @usableFromInline
        init(payload: UnsafeMutableRawPointer, table: _Table) {
            self.payload = payload
            self.table = table
        }

        deinit {
            table.destroy(payload)
        }
    }

    @usableFromInline
    struct _Table: Sendable {
        @usableFromInline
        let destroy: @Sendable (UnsafeMutableRawPointer) -> Void

        // CHANGE: Widened from <T> to <T: ~Copyable>
        @usableFromInline
        init<T: ~Copyable>(_: T.Type) {
            self.destroy = { raw in
                raw.assumingMemoryBound(to: T.self).deinitialize(count: 1)
                raw.deallocate()
            }
        }
    }

    @usableFromInline
    init(type: ObjectIdentifier, storage: _Storage) {
        self.type = type
        self.storage = storage
    }

    @usableFromInline
    func _project<T: ~Copyable>(_: T.Type) -> UnsafePointer<T> {
        unsafe UnsafePointer(storage.payload.assumingMemoryBound(to: T.self))
    }

    // MARK: - NEW: _read subscript (borrow access, no closure)

    /// Borrow access to the stored value via `_read`.
    ///
    /// Usage: `V._render(value[as: V.self], context: &ctx)`
    ///
    /// No closure wrapping needed. The `_read` coroutine yields a borrow
    /// scoped to the accessor call.
    subscript<T: ~Copyable>(as type: T.Type) -> T {
        _read {
            precondition(
                self.type == ObjectIdentifier(T.self),
                "Value type mismatch: expected \(T.self)"
            )
            yield unsafe _project(type).pointee
        }
    }

    // MARK: - NEW: ~Escapable Ref (lifetime-dependent borrow)

    /// A ~Escapable reference to a stored value.
    ///
    /// Carries a lifetime dependency back to the `Value`, ensuring the
    /// reference cannot outlive its storage. Access the payload via
    /// the `value` property (_read accessor).
    struct Ref<T: ~Copyable>: ~Copyable, ~Escapable {
        @usableFromInline
        let _pointer: UnsafePointer<T>

        @usableFromInline
        init(_pointer: UnsafePointer<T>) {
            self._pointer = _pointer
        }

        var value: T {
            _read { yield unsafe _pointer.pointee }
        }
    }

    /// Returns a ~Escapable reference to the stored value.
    ///
    /// The returned `Ref` carries a lifetime dependency on `self`.
    /// No closure needed — use `ref.value` to borrow.
    ///
    /// Uses `_overrideLifetime` (the "returning model", 28 sites in the
    /// ecosystem) to bridge from the raw pointer to the lifetime system.
    @_lifetime(borrow self)
    func borrow<T: ~Copyable>(as type: T.Type) -> Ref<T> {
        precondition(
            self.type == ObjectIdentifier(T.self),
            "Value type mismatch: expected \(T.self)"
        )
        let ref = unsafe Ref(_pointer: _project(type))
        return unsafe _overrideLifetime(ref, borrowing: self)
    }

    // MARK: - Legacy API (deprecated, backward compatible)

    /// Attempts to extract the value as the specified type.
    @available(*, deprecated, renamed: "subscript(as:)")
    func take<T>(_ expectedType: T.Type) -> T? {
        guard type == ObjectIdentifier(T.self) else {
            return nil
        }
        return _project(T.self).pointee
    }

    /// Precondition-checked type projection (copies out).
    @available(*, deprecated, renamed: "subscript(as:)")
    func read<T>(_ expectedType: T.Type) -> T {
        precondition(
            type == ObjectIdentifier(T.self),
            "Value type mismatch: expected \(T.self), got type with id \(type)"
        )
        return _project(T.self).pointee
    }
}

extension Value: Sendable where M: Sendable {}

// MARK: - Construction: Unchecked Mode (~Copyable payload)

extension Value where M == Mode.Unchecked {
    // CHANGE: Widened from <T> to <T: ~Copyable>, parameter is `consuming`
    @inlinable
    static func make<T: ~Copyable>(_ value: consuming T) -> Value<M> {
        let payload = UnsafeMutablePointer<T>.allocate(capacity: 1)
        payload.initialize(to: value)

        let table = _Table(T.self)
        let storage = _Storage(
            payload: UnsafeMutableRawPointer(payload),
            table: table
        )

        return Value<M>(
            type: ObjectIdentifier(T.self),
            storage: storage
        )
    }
}

// MARK: - Construction: Reference Mode (Sendable + ~Copyable payload)

extension Value where M == Mode.Reference {
    // CHANGE: Widened from <T: Sendable> to <T: Sendable & ~Copyable>
    @inlinable
    static func make<T: Sendable & ~Copyable>(_ value: consuming T) -> Value<M> {
        let payload = UnsafeMutablePointer<T>.allocate(capacity: 1)
        payload.initialize(to: value)

        let table = _Table(T.self)
        let storage = _Storage(
            payload: UnsafeMutableRawPointer(payload),
            table: table
        )

        return Value<M>(
            type: ObjectIdentifier(T.self),
            storage: storage
        )
    }
}

// MARK: - Legacy Operations (Copyable payloads only, deprecated)

extension Value where M == Mode.Unchecked {
    @available(*, deprecated, message: "Use subscript(as:) for borrow access")
    func apply<In, Out>(_ transform: (In) -> Out) -> Value<M> {
        .make(transform(read(In.self)))
    }

    @available(*, deprecated, message: "Use subscript(as:) for borrow access")
    func combine<A, B, Out>(
        _ other: Value<M>,
        using combineFn: (A, B) -> Out
    ) -> Value<M> {
        .make(combineFn(read(A.self), other.read(B.self)))
    }
}

// ===----------------------------------------------------------------------===//
// MARK: - Test Domain: ~Copyable View (mirrors Rendering.View)
// ===----------------------------------------------------------------------===//

protocol View: ~Copyable {
    associatedtype Body: View & ~Copyable
    var body: Body { get }
    static func _render(_ view: borrowing Self, output: inout [String])
}

extension Never: View {
    typealias Body = Never
    var body: Never { fatalError() }
    static func _render(_ view: borrowing Self, output: inout [String]) {}
}

// A ~Copyable leaf view
struct UniqueLeaf: ~Copyable, View {
    let text: String
    typealias Body = Never
    var body: Never { fatalError() }

    static func _render(_ view: borrowing Self, output: inout [String]) {
        output.append(view.text)
    }
}

// A Copyable leaf view
struct TextLeaf: View {
    let text: String
    typealias Body = Never
    var body: Never { fatalError() }

    static func _render(_ view: borrowing Self, output: inout [String]) {
        output.append(view.text)
    }
}

// A Copyable composite with ~Copyable body
struct Wrapper: View {
    let label: String
    typealias Body = UniqueLeaf
    var body: UniqueLeaf { UniqueLeaf(text: "\(label)-content") }

    static func _render(_ view: borrowing Self, output: inout [String]) {
        output.append("[\(view.label)")
        Body._render(view.body, output: &output)
        output.append("]\(view.label)")
    }
}

// ===----------------------------------------------------------------------===//
// MARK: - Test Domain: Dispatch Thunk (mirrors Rendering.Thunk)
// ===----------------------------------------------------------------------===//

struct Thunk {
    let dispatch: (Value<Mode.Unchecked>, inout [String]) -> Void

    // Direct ~Copyable view dispatch via _read subscript
    init<V: View & ~Copyable>(_: V.Type) {
        self.dispatch = { value, output in
            V._render(value[as: V.self], output: &output)
        }
    }

    // Composite: store Copyable view, compute ~Copyable body transiently
    init<V: View & Copyable>(view _: V.Type) where V.Body: View {
        self.dispatch = { value, output in
            V.Body._render(value[as: V.self].body, output: &output)
        }
    }
}

// ===----------------------------------------------------------------------===//
// MARK: - Tests
// ===----------------------------------------------------------------------===//

nonisolated(unsafe) var passed = 0
nonisolated(unsafe) var failed = 0

func expect(
    _ condition: Bool,
    _ message: String,
    file: String = #file,
    line: Int = #line
) {
    if condition {
        passed += 1
        print("  ✓ \(message)")
    } else {
        failed += 1
        print("  ✗ FAILED: \(message) (\(file):\(line))")
    }
}

// --- Phase 0: ObjectIdentifier works with ~Copyable types ---

func testObjectIdentifierNonCopyable() {
    print("Phase 0: ObjectIdentifier + ~Copyable")

    let id = ObjectIdentifier(UniqueLeaf.self)
    let id2 = ObjectIdentifier(UniqueLeaf.self)
    expect(id == id2, "ObjectIdentifier(~Copyable.self) is stable")

    let idText = ObjectIdentifier(TextLeaf.self)
    expect(id != idText, "ObjectIdentifier distinguishes types")
}

// --- Phase 1: Construction with ~Copyable payloads ---

func testConstructionNonCopyable() {
    print("\nPhase 1: Construction with ~Copyable payloads")

    // Unchecked mode — ~Copyable payload
    let leaf = UniqueLeaf(text: "hello")
    let value = Value<Mode.Unchecked>.make(leaf)
    expect(value.type == ObjectIdentifier(UniqueLeaf.self),
           "Unchecked make<~Copyable> stores correct type id")

    // Reference mode — Sendable + ~Copyable payload
    // (UniqueLeaf is not Sendable, so test with a Sendable ~Copyable type)
    // For now, test with Copyable+Sendable to confirm the widened signature compiles
    let textValue = Value<Mode.Reference>.make(TextLeaf(text: "ref"))
    expect(textValue.type == ObjectIdentifier(TextLeaf.self),
           "Reference make<Sendable> still works (backward compat)")
}

// --- Phase 2: _read subscript borrow access ---

func testReadSubscript() {
    print("\nPhase 2: _read subscript borrow access")

    // Copyable payload — subscript returns borrow
    let value = Value<Mode.Unchecked>.make(TextLeaf(text: "sub"))
    let text = value[as: TextLeaf.self].text
    expect(text == "sub", "_read subscript borrows Copyable payload")

    // ~Copyable payload — subscript returns borrow
    let ncValue = Value<Mode.Unchecked>.make(UniqueLeaf(text: "unique"))
    var output: [String] = []
    UniqueLeaf._render(ncValue[as: UniqueLeaf.self], output: &output)
    expect(output == ["unique"], "_read subscript borrows ~Copyable payload for _render")
}

// --- Phase 3: ~Escapable Ref borrow access ---

func testEscapableRef() {
    print("\nPhase 3: ~Escapable Ref borrow access")

    // Copyable payload
    let value = Value<Mode.Unchecked>.make(TextLeaf(text: "ref-test"))
    let ref = value.borrow(as: TextLeaf.self)
    expect(ref.value.text == "ref-test", "Ref borrows Copyable payload")

    // ~Copyable payload
    let ncValue = Value<Mode.Unchecked>.make(UniqueLeaf(text: "nc-ref"))
    let ncRef = ncValue.borrow(as: UniqueLeaf.self)
    var output: [String] = []
    UniqueLeaf._render(ncRef.value, output: &output)
    expect(output == ["nc-ref"], "Ref borrows ~Copyable payload for _render")
}

// --- Phase 4: Thunk dispatch via _read subscript ---

func testThunkDispatch() {
    print("\nPhase 4: Thunk dispatch (rendering-style)")

    // Direct ~Copyable leaf dispatch
    let ncValue = Value<Mode.Unchecked>.make(UniqueLeaf(text: "thunk"))
    let thunk = Thunk(UniqueLeaf.self)
    var output: [String] = []
    thunk.dispatch(ncValue, &output)
    expect(output == ["thunk"], "Thunk dispatches ~Copyable leaf via subscript")

    // Composite: Copyable view with ~Copyable body
    let wrapperValue = Value<Mode.Unchecked>.make(Wrapper(label: "w"))
    let compositeThunk = Thunk(view: Wrapper.self)
    var output2: [String] = []
    compositeThunk.dispatch(wrapperValue, &output2)
    expect(output2 == ["w-content"],
           "Composite thunk: store Copyable view, borrow ~Copyable body")
}

// --- Phase 5: Iterative work stack (full rendering simulation) ---

func testIterativeWorkStack() {
    print("\nPhase 5: Iterative work stack simulation")

    enum Work {
        case render(value: Value<Mode.Unchecked>, thunk: Thunk)
        case action(String)
    }

    var stack: [Work] = []
    var output: [String] = []

    // Push three views (reverse order for LIFO)
    stack.append(.action("pop-container"))
    stack.append(.render(
        value: .make(UniqueLeaf(text: "c")),
        thunk: Thunk(UniqueLeaf.self)
    ))
    stack.append(.render(
        value: .make(UniqueLeaf(text: "b")),
        thunk: Thunk(UniqueLeaf.self)
    ))
    stack.append(.render(
        value: .make(UniqueLeaf(text: "a")),
        thunk: Thunk(UniqueLeaf.self)
    ))
    stack.append(.action("push-container"))

    // Iterative dispatch loop
    while let work = stack.popLast() {
        switch work {
        case .render(let value, let thunk):
            thunk.dispatch(value, &output)
            // ARC handles cleanup — no manual destroy
        case .action(let action):
            output.append(action)
        }
    }

    expect(
        output == ["push-container", "a", "b", "c", "pop-container"],
        "Iterative loop: LIFO ordering preserved, ARC cleanup automatic"
    )
}

// --- Phase 6: ARC cleanup on early exit (no manual _cleanupStack) ---

func testARCCleanup() {
    print("\nPhase 6: ARC cleanup on scope exit")

    var destructionCount = 0

    final class Tracker: @unchecked Sendable {
        let onDeinit: () -> Void
        init(onDeinit: @escaping () -> Void) { self.onDeinit = onDeinit }
        deinit { onDeinit() }
    }

    do {
        var stack: [Value<Mode.Unchecked>] = []
        stack.append(.make(Tracker { destructionCount += 1 }))
        stack.append(.make(Tracker { destructionCount += 1 }))
        stack.append(.make(Tracker { destructionCount += 1 }))
        // Stack goes out of scope — ARC destroys all three
    }

    expect(destructionCount == 3,
           "ARC destroys all values when stack drops (no manual cleanup)")
}

// --- Phase 7: Deprecated API backward compat ---

func testDeprecatedBackwardCompat() {
    print("\nPhase 7: Deprecated API backward compatibility")

    let value = Value<Mode.Unchecked>.make(42)
    let taken: Int? = value.take(Int.self)
    expect(taken == 42, "Deprecated take<T> still works")

    let readVal: Int = value.read(Int.self)
    expect(readVal == 42, "Deprecated read<T> still works")

    let wrong: String? = value.take(String.self)
    expect(wrong == nil, "Deprecated take<T> returns nil on mismatch")
}

// --- Phase 8: Deep nesting (rendering-style, ~Copyable through stack) ---

func testDeepNesting() {
    print("\nPhase 8: Deep nesting through iterative stack")

    var stack: [Value<Mode.Unchecked>] = []
    var output: [String] = []

    // Simulate 500 levels of nesting via the stack
    let depth = 500
    for i in 0..<depth {
        stack.append(.make(UniqueLeaf(text: "leaf-\(i)")))
    }

    let thunk = Thunk(UniqueLeaf.self)
    while let value = stack.popLast() {
        thunk.dispatch(value, &output)
    }

    expect(output.count == depth, "500 ~Copyable views dispatched iteratively")
    expect(output.last == "leaf-0", "LIFO order: last pushed = first dispatched")
    expect(output.first == "leaf-499", "LIFO order: first pushed = last dispatched")
}

// ===----------------------------------------------------------------------===//
// MARK: - Run
// ===----------------------------------------------------------------------===//

testObjectIdentifierNonCopyable()
testConstructionNonCopyable()
testReadSubscript()
testEscapableRef()
testThunkDispatch()
testIterativeWorkStack()
testARCCleanup()
testDeprecatedBackwardCompat()
testDeepNesting()

print("\n=== Results: \(passed) passed, \(failed) failed ===")

if failed > 0 {
    fatalError("\(failed) test(s) failed")
}

// MARK: - Minimal reproduction: CopyPropagation ownership error
// Purpose: SILGen produces `load [take]` for a trivial field in a ~Copyable
//          generic enum tuple payload, mismatching `switch_enum forwarding: @none`.
//
// Toolchain: Apple Swift 6.3 (swiftlang-6.3.0.123.5 clang-2100.0.123.102)
// Platform: macOS 26.0 (arm64)
//
// Build: rm -rf .build && swift build -c release
// Result: CONFIRMED — signal 6, "Found ownership error?!"
// Debug: swift build — passes
// Date: 2026-03-31
//
// Required ingredients (removing any one makes it pass):
// 1. Generic ~Copyable enum with tuple payload containing a trivial field
// 2. A ~Copyable State struct with a mutating method returning the enum
// 3. A class wrapping Mutex<State> with a withLock forwarding method
// 4. A function calling withLock → state.receive() → switch consume

import Synchronization

struct NC: ~Copyable, Sendable { let x: Int }

enum Action<E: ~Copyable>: ~Copyable, @unchecked Sendable {
    case found(E, tag: Int?)
    case empty
}

struct State<E: ~Copyable>: ~Copyable {
    var pending: E?
    init() { pending = nil }
    mutating func receive() -> Action<E> {
        if let e = pending.take() { return .found(e, tag: nil) }
        return .empty
    }
}

final class Box<E: ~Copyable & Sendable>: Sendable {
    let mu: Mutex<State<E>>
    init() { mu = Mutex(State()) }
    func withLock<R: ~Copyable & Sendable>(
        _ body: (inout sending State<E>) -> sending R
    ) -> sending R { mu.withLock(body) }
}

func process<E: ~Copyable & Sendable>(box: Box<E>) -> E? {
    let a: Action<E> = box.withLock { s in s.receive() }
    switch consume a {
    case .found(let e, _): return e
    case .empty: return nil
    }
}

let b = Box<NC>()
if let r = process(box: b) { print(r.x) } else { print("nil") }

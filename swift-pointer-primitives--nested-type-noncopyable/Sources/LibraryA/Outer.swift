// ===----------------------------------------------------------------------===//
// EXPERIMENT: Nested types with ~Copyable across modules
//
// HYPOTHESIS: Nested types inside generic structs with ~Copyable constraints
//             cause constraint issues when accessed with ~Copyable type parameter.
//
// METHODOLOGY: [EXP-004a] Incremental Construction
//
// RESULT: CONFIRMED - Fix found
//
// ROOT CAUSE: When declaring a nested type inside a generic struct with
// `Element: ~Copyable`, Swift requires explicit `where Element: ~Copyable`
// on the extension where the nested type is declared.
//
// FIX: Change from:
//   extension Outer {
//       struct Inner { ... }
//   }
// To:
//   extension Outer where Element: ~Copyable {
//       struct Inner { ... }
//   }
//
// And for extensions on the nested type:
//   extension Outer.Inner where Element: ~Copyable {
//       func method() { ... }
//   }
//
// This fix works both same-module and cross-module.
// ===----------------------------------------------------------------------===//

/// Outer type with ~Copyable generic parameter (like Pointer<Pointee>)
public struct Outer<Element: ~Copyable>: Copyable {
    public var value: Int

    public init(value: Int) {
        self.value = value
    }
}

// FIX: Nested type with EXPLICIT where clause
extension Outer where Element: ~Copyable {
    /// Nested type that inherits Element from outer type
    public struct Inner: Copyable {
        public var innerValue: Int

        public init(innerValue: Int) {
            self.innerValue = innerValue
        }
    }
}

// FIX: Extension with EXPLICIT ~Copyable constraint
extension Outer.Inner where Element: ~Copyable {
    public func doSomething() -> Int {
        innerValue * 2
    }
}

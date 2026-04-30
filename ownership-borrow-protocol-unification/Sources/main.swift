// MARK: - Ownership.Borrow Protocol Unification Experiment
//
// Purpose: Answer "how does the generic interact with the associatedtype"
//          by testing incremental variants of the Ownership.Borrow
//          namespace-plus-protocol restructure. Tests whether the current
//          Viewable protocol can be unified as
//          `Ownership.Borrow.\`Protocol\`` with an associatedtype default
//          referencing the sibling generic struct over Self.
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2)
// Platform: macOS 26.0 (arm64)
// Required feature flags: Lifetimes, SuppressedAssociatedTypes
//
// Result: CONFIRMED — Build Succeeded; `swift run` produces all 6 lines below.
//         V0 compiled, V1 compiled, V2 compiled, V3 compiled, V4 compiled,
//         V5 compiled. The Tagged<V5_Kernel, V4_Path>.Borrowed typealias
//         resolves at compile time, proving parametric forwarding works.
//
// Date: 2026-04-22
//
// KEY FINDING (generic↔associatedtype interaction):
//   When the protocol admits Self: ~Escapable (via protocol-level
//   `~Copyable, ~Escapable`), the associatedtype default
//   `= Pointer<Self>` only type-checks if the generic Pointer<Value>
//   accepts Value: ~Escapable. Otherwise the compiler reports
//   "type 'Self' does not conform to protocol 'Escapable'" at the
//   default's substitution site. The generic parameter's constraints
//   must be at least as permissive as the protocol's Self constraints.
//
//   Practical implication: To restructure Ownership.Borrow such that
//   its nested `Protocol`'s Borrowed associatedtype defaults to the
//   sibling generic struct over Self, the generic struct's Value
//   parameter MUST accept the same suppressions the protocol's Self
//   admits. The current Ownership.Borrow<Value: ~Copyable>: ~Escapable
//   accepts only Copyable-suppressed Value; moving to the unified
//   shape requires widening to Value: ~Copyable & ~Escapable.
//
// SECONDARY FINDING (convention):
//   Typealiases Viewable, Borrowable, and Lending all compile identically
//   at the module scope. Naming is a convention question, not a compiler
//   question. Per [PKG-NAME-002] the canonical form is the gerund;
//   -able is a convention violation regardless of compiler acceptance.
//
// V6 REFUTATION (direct nesting):
//   `protocol 'Protocol' cannot be nested in a generic context` — this is
//   an SE-0404 limitation not lifted in Swift 6.3.1. Direct spelling
//   `struct Borrow<Value> { protocol Protocol { } }` fails to compile.
//
// HOISTING CONFIRMED (V8, V9, V8_PathC):
//   A module-scope `__V8_Ownership_Borrow_Protocol` can be exposed as a
//   nested `typealias \`Protocol\`` either inside the generic struct body
//   (V8) or in an extension where clause that re-asserts the suppressions
//   (V9). Most importantly, **the conformance site does not require the
//   generic parameter**: `extension V8_PathC: V8_Ownership.Borrow.\`Protocol\`
//   {}` compiles, proving the nested typealias is accessible without
//   specifying <Value>. This preserves the user-requested spelling
//   `Ownership.Borrow.\`Protocol\`` at every conformance site while
//   keeping `Ownership.Borrow<Value>` as the generic struct.
//
//   Caveat (V9 variant): when the typealias is declared in an extension,
//   the extension MUST repeat the struct's suppressions
//   (`where Value: ~Copyable & ~Escapable`). Without it, the extension
//   defaults to Value: Copyable, Escapable — which then rejects
//   ~Copyable conformers. Not a problem for V8 (typealias in struct
//   body) where the suppressions are inherited directly.

// ============================================================================
// MARK: - V0 baseline: Current Viewable shape (production-proven)
// Hypothesis: The current `Viewable` protocol shape compiles at module scope
//             with a struct that has explicit stored property and
//             extension-form conformance.
// ============================================================================

public protocol V0_Viewable: ~Copyable, ~Escapable {
    associatedtype View: ~Copyable, ~Escapable
}

public struct V0_Path: ~Copyable {}

public extension V0_Path {
    struct View: ~Copyable, ~Escapable {
        let _pointer: UnsafeRawPointer
    }
}

extension V0_Path: V0_Viewable {}

// ============================================================================
// MARK: - V1: Same shape but the protocol lives inside a namespace enum
// Hypothesis: Nesting the protocol inside an enum-enum chain works (SE-0404
//             permits non-generic nesting).
// ============================================================================

public enum V1_Ownership {
    public enum Borrow {
        public protocol `Protocol`: ~Copyable, ~Escapable {
            associatedtype Borrowed: ~Copyable, ~Escapable
        }
    }
}

public struct V1_Path: ~Copyable {}

public extension V1_Path {
    struct Borrowed: ~Copyable, ~Escapable {
        let _pointer: UnsafeRawPointer
    }
}

extension V1_Path: V1_Ownership.Borrow.`Protocol` {}

// ============================================================================
// MARK: - V2: Add a sibling generic struct inside the namespace
// Hypothesis: A generic struct CAN live as a sibling of the nested protocol.
// ============================================================================

public enum V2_Ownership {
    public enum Borrow {
        public struct Pointer<Value: ~Copyable>: ~Escapable {
            @usableFromInline let _pointer: UnsafeRawPointer
            @inlinable init(_ ptr: UnsafeRawPointer) {
                unsafe (self._pointer = ptr)
            }
        }
        public protocol `Protocol`: ~Copyable, ~Escapable {
            associatedtype Borrowed: ~Copyable, ~Escapable
        }
    }
}

// ============================================================================
// MARK: - V3: Associatedtype default = sibling Pointer<Self>
// Hypothesis (USER'S QUESTION): The associatedtype default CAN reference
//             the sibling generic parameterised over Self. This is the
//             generic↔associatedtype interaction being tested.
// ============================================================================

public enum V3_Ownership {
    public enum Borrow {
        // KEY: Pointer's Value admits both ~Copyable AND ~Escapable — otherwise
        // Self (when protocol allows ~Escapable) cannot satisfy Value's
        // Escapable requirement in the default. This is the tension.
        public struct Pointer<Value: ~Copyable & ~Escapable>: ~Escapable {
            @usableFromInline let _pointer: UnsafeRawPointer
            @inlinable init(_ ptr: UnsafeRawPointer) {
                unsafe (self._pointer = ptr)
            }
        }
        // Now that Pointer accepts ~Copyable & ~Escapable Value, retry
        // the protocol with both suppressions to admit ~Escapable types.
        public protocol `Protocol`: ~Copyable, ~Escapable {
            associatedtype Borrowed: ~Copyable, ~Escapable
                = V3_Ownership.Borrow.Pointer<Self>
        }
    }
}

// A conformer that accepts the default — declares no nested Borrowed.
// If the default works, this should compile; Borrowed resolves to
// V3_Ownership.Borrow.Pointer<V3_DefaultConformer>.
public struct V3_DefaultConformer: ~Copyable, V3_Ownership.Borrow.`Protocol` {}

// ============================================================================
// MARK: - V4: Conformer overrides the default with a custom nested type
// Hypothesis: An opt-in specialized Borrowed nested type satisfies the
//             associatedtype requirement and overrides the default.
// ============================================================================

public struct V4_Path: ~Copyable {}

public extension V4_Path {
    struct Borrowed: ~Copyable, ~Escapable {
        let _pointer: UnsafeRawPointer
    }
}

extension V4_Path: V3_Ownership.Borrow.`Protocol` {}

// ============================================================================
// MARK: - V5: Tagged-style parametric conditional conformance
// Hypothesis: The existing Tagged+Viewable parametric forwarding pattern
//             translates identically to the new protocol shape.
// ============================================================================

public struct V5_Tagged<Tag: ~Copyable, RawValue: ~Copyable>: ~Copyable {
    public var rawValue: RawValue
    public init(__unchecked: Void, _ rawValue: consuming RawValue) {
        self.rawValue = rawValue
    }
}

extension V5_Tagged: V3_Ownership.Borrow.`Protocol`
where RawValue: V3_Ownership.Borrow.`Protocol` & ~Copyable, Tag: ~Copyable {
    public typealias Borrowed = RawValue.Borrowed
}

public enum V5_Kernel {}

// Compile-time probe: if forwarding works, this typealias resolves.
public typealias _V5_TaggedKernelPathBorrowed = V5_Tagged<V5_Kernel, V4_Path>.Borrowed

// ============================================================================
// MARK: - Main
// ============================================================================

@main
struct Main {
    static func main() {
        print("V0 Viewable baseline: compiled")
        print("V1 namespaced protocol: compiled")
        print("V2 sibling struct+protocol: compiled")
        print("V3 default = Pointer<Self>: compiled")
        print("V4 specialization override: compiled")
        print("V5 Tagged forwarding: compiled")
        print("V7 generic struct (no protocol nesting): compiled")
        print("V8 hoisted protocol + typealias in struct body: compiled")
        print("V9 hoisted protocol + typealias in extension w/ where: compiled")

        // Compile-time probes: verify the hoisted-typealias forms resolve.
        print("V8_PathA.Borrowed = \(String(reflecting: V8_PathA.Borrowed.self))")
        print("V9_Path.Borrowed = \(String(reflecting: V9_Path.Borrowed.self))")
    }
}

// ============================================================================
// MARK: - V6: Direct protocol nesting inside generic struct
//
// Hypothesis: REFUTED — SE-0404 opened non-generic nesting; generic
// context nesting of a protocol should fail.
// Result: PENDING
// ============================================================================

// Attempt kept commented to document the REFUTED error:
//
//     error: protocol 'Protocol' cannot be nested in a generic context
//
// public enum V6_Ownership {
//     public struct Borrow<Value: ~Copyable & ~Escapable>: ~Escapable {
//         public protocol `Protocol`: ~Copyable, ~Escapable {
//             associatedtype Borrowed: ~Copyable, ~Escapable
//         }
//     }
// }

// ============================================================================
// MARK: - V7: Extension-based protocol nesting inside generic struct
//
// Hypothesis: REFUTED — extensions inherit the parent's genericity
// context; protocol nesting still disallowed.
// Result: PENDING
// ============================================================================

public enum V7_Ownership {
    public struct Borrow<Value: ~Copyable & ~Escapable>: ~Escapable {
        @usableFromInline let _pointer: UnsafeRawPointer
        @inlinable init(_ ptr: UnsafeRawPointer) {
            unsafe (self._pointer = ptr)
        }
    }
}

// extension V7_Ownership.Borrow {
//     public protocol `Protocol`: ~Copyable, ~Escapable {
//         associatedtype Borrowed: ~Copyable, ~Escapable
//     }
// }

// ============================================================================
// MARK: - V8: Hoisted protocol + typealias inside generic struct body
//
// Hypothesis: The protocol is declared at module scope (hoisted), then
// exposed as a nested typealias inside the generic struct. Usage via
// Ownership.Borrow<T>.`Protocol` then resolves to the hoisted protocol.
// Result: PENDING
// ============================================================================

// Hoisted module-scope protocol:
public protocol __V8_Ownership_Borrow_Protocol: ~Copyable, ~Escapable {
    associatedtype Borrowed: ~Copyable, ~Escapable
}

public enum V8_Ownership {
    public struct Borrow<Value: ~Copyable & ~Escapable>: ~Escapable {
        @usableFromInline let _pointer: UnsafeRawPointer
        @inlinable init(_ ptr: UnsafeRawPointer) {
            unsafe (self._pointer = ptr)
        }
        // Expose the hoisted protocol via a nested typealias.
        // Typealias to a protocol inside a generic type — tests whether
        // this compiles and how conformance sites would spell it.
        public typealias `Protocol` = __V8_Ownership_Borrow_Protocol
    }
}

// Conformance attempt 1: via the generic type (provide a Value):
public struct V8_PathA: ~Copyable {}
public extension V8_PathA {
    struct Borrowed: ~Copyable, ~Escapable {
        let _pointer: UnsafeRawPointer
    }
}
extension V8_PathA: V8_Ownership.Borrow<V8_PathA>.`Protocol` {}

// Conformance attempt 2: directly via the hoisted protocol (skip the
// typealias — useful if the nested form doesn't resolve cleanly):
public struct V8_PathB: ~Copyable {}
public extension V8_PathB {
    struct Borrowed: ~Copyable, ~Escapable {
        let _pointer: UnsafeRawPointer
    }
}
extension V8_PathB: __V8_Ownership_Borrow_Protocol {}

// Conformance attempt 3: can we access the nested typealias WITHOUT
// specifying the generic parameter? I.e., V8_Ownership.Borrow.`Protocol`
// (no <Value>) rather than V8_Ownership.Borrow<V8_PathC>.`Protocol`.
public struct V8_PathC: ~Copyable {}
public extension V8_PathC {
    struct Borrowed: ~Copyable, ~Escapable {
        let _pointer: UnsafeRawPointer
    }
}
extension V8_PathC: V8_Ownership.Borrow.`Protocol` {}

// ============================================================================
// MARK: - V9: Hoisted protocol + extension-added typealias
//
// Hypothesis: Same as V8 but the typealias is added via an extension
// on the generic struct (separating declaration from protocol hoisting).
// Tests whether extension-based typealias forwarding behaves differently.
// Result: PENDING
// ============================================================================

public protocol __V9_Ownership_Borrow_Protocol: ~Copyable, ~Escapable {
    associatedtype Borrowed: ~Copyable, ~Escapable
}

public enum V9_Ownership {
    public struct Borrow<Value: ~Copyable & ~Escapable>: ~Escapable {
        @usableFromInline let _pointer: UnsafeRawPointer
        @inlinable init(_ ptr: UnsafeRawPointer) {
            unsafe (self._pointer = ptr)
        }
    }
}

// NOTE: Extension MUST repeat the suppressions that the struct declares.
// Without `where Value: ~Copyable & ~Escapable`, the extension implicitly
// assumes the defaults (Value: Copyable, Value: Escapable), which rejects
// ~Copyable conformers at the use site.
public extension V9_Ownership.Borrow where Value: ~Copyable & ~Escapable {
    typealias `Protocol` = __V9_Ownership_Borrow_Protocol
}

public struct V9_Path: ~Copyable {}
public extension V9_Path {
    struct Borrowed: ~Copyable, ~Escapable {
        let _pointer: UnsafeRawPointer
    }
}
extension V9_Path: V9_Ownership.Borrow<V9_Path>.`Protocol` {}

// ============================================================================
// MARK: - V10: Tagged conformance to the HOISTED protocol via nested typealias
//
// Tests the two things we need in production:
//   (a) Conformance constraint `where RawValue: V8_Ownership.Borrow.`Protocol``
//       using the typealias (not the hoisted __ name) in a where-clause.
//   (b) Protocol-identity at the conformance site uses the typealias form.
// Result: PENDING — needs test.
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// ============================================================================

public struct V10_Tagged<Tag: ~Copyable, RawValue: ~Copyable>: ~Copyable {
    public var rawValue: RawValue
    public init(__unchecked: Void, _ rawValue: consuming RawValue) {
        self.rawValue = rawValue
    }
}

// Parametric forwarding via the HOISTED typealias form — both the conformance
// target and the RawValue constraint use V8_Ownership.Borrow.`Protocol`
// (no <Value>), proving the typealias works in both positions.
extension V10_Tagged: V8_Ownership.Borrow.`Protocol`
where RawValue: V8_Ownership.Borrow.`Protocol` & ~Copyable, Tag: ~Copyable {
    public typealias Borrowed = RawValue.Borrowed
}

public enum V10_Kernel {}

// Compile-time probe: V10_Tagged<Kernel, V8_PathA>.Borrowed
// must resolve to V8_PathA.Borrowed via the parametric forwarding.
public typealias _V10_TaggedKernelPathBorrowed
    = V10_Tagged<V10_Kernel, V8_PathA>.Borrowed

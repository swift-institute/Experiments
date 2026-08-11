// Status: SUPERSEDED -- direct nested enum pattern shipped; see [API-ERR-001] typed throws. (Phase 1b stale-triage 2026-04-30)
// Revalidated: Swift 6.3.1 (2026-04-30) — SUPERSEDED (per existing Status line; not re-run)
// ============================================================================
// EXPERIMENT: typed-throws-error-alias
// ============================================================================
//
// HYPOTHESIS:
// The issue is accessing .Error through a generic nested type path like
// `Container<Element>.Fixed.Error`. Need to find a way to break the generic chain.
//
// TRIGGER:
// Using `throws(Heap.Fixed.Error)` instead of `throws(__Heap.Fixed.Error)` causes:
// - "Cannot infer contextual base in reference to member 'empty'"
// - "Type 'Element' does not conform to protocol 'Copyable'"
//
// METHODOLOGY: [EXP-004a] Incremental Construction
// Test different approaches to break the generic chain.
//
// RESULT: [CONFIRMED]
//
// | Variant | Pattern                                         | Result    |
// |---------|------------------------------------------------|-----------|
// | A       | Direct hoisted: throws(__Type)                  | COMPILES  |
// | B       | Non-generic namespace: throws(NonGeneric.Error) | COMPILES  |
// | C       | Extension typealias: throws(Generic.Fixed.Error)| FAILS     |
// | D       | Body typealias: throws(Generic.Fixed.Error)     | COMPILES  |
// | F       | Direct nested enum: throws(Generic.Fixed.Error) | COMPILES  |
//
// KEY FINDINGS:
// 1. The typealias MUST be declared inside the struct body, NOT in an extension.
//    When the typealias is in an extension on a generic nested type, the compiler
//    cannot properly resolve the error type in typed throws context.
//
// 2. A DIRECT NESTED ENUM works without any hoisting at all! This is the cleanest
//    solution - define the Error enum directly inside the struct body.
//
// RECOMMENDED FIX FOR HEAP PACKAGE (Option F - cleanest):
// Remove the hoisted __Heap.Fixed.Error entirely and define Error directly
// inside the Heap.Fixed struct body:
//
//   public struct Fixed: ~Copyable {
//       public enum Error: Swift.Error, Sendable, Equatable {
//           case empty
//           case invalidCapacity
//       }
//       // ... rest of struct
//   }
//
// ALTERNATIVE FIX (Option D - if hoisting is preferred):
// Move `public typealias Error = __Heap.Fixed.Error` from the extension
// into the `Heap.Fixed` struct body.
//
// ============================================================================

// Minimal comparison protocol
public protocol Ordering: ~Copyable {
    static func < (lhs: borrowing Self, rhs: borrowing Self) -> Bool
}

// ============================================================================
// VARIANT A: DIRECT HOISTED TYPE (no typealias through generic)
// ============================================================================

public enum __ContainerAFixedError: Swift.Error, Sendable, Equatable {
    case empty
    case invalidCapacity
}

public struct ContainerA<Element: ~Copyable & Ordering>: ~Copyable {
    var count: Int = 0

    public struct Fixed: ~Copyable {
        var count: Int = 0
    }
}

// Test: Does throws(__ContainerAFixedError) work directly?
extension ContainerA.Fixed where Element: ~Copyable & Ordering {
    // Direct use of hoisted type - EXPECTED TO WORK
    public mutating func popA() throws(__ContainerAFixedError) -> Element {
        throw .empty
    }
}

// ============================================================================
// VARIANT B: TYPEALIAS ON NON-GENERIC TYPE
// ============================================================================

public enum __ContainerBFixedError: Swift.Error, Sendable, Equatable {
    case empty
    case invalidCapacity
}

// Non-generic namespace to hold the typealias
public enum ContainerBFixed {
    public typealias Error = __ContainerBFixedError
}

public struct ContainerB<Element: ~Copyable & Ordering>: ~Copyable {
    var count: Int = 0

    public struct Fixed: ~Copyable {
        var count: Int = 0
    }
}

// Test: Does throws(ContainerBFixed.Error) work via non-generic namespace?
extension ContainerB.Fixed where Element: ~Copyable & Ordering {
    // Typealias through NON-generic type - EXPECTED TO WORK
    public mutating func popB() throws(ContainerBFixed.Error) -> Element {
        throw .empty
    }
}

// ============================================================================
// VARIANT C: TYPEALIAS ON GENERIC NESTED TYPE (original issue - via extension)
// ============================================================================

public enum __ContainerCFixedError: Swift.Error, Sendable, Equatable {
    case empty
    case invalidCapacity
}

public struct ContainerC<Element: ~Copyable & Ordering>: ~Copyable {
    var count: Int = 0

    public struct Fixed: ~Copyable {
        var count: Int = 0
    }
}

extension ContainerC.Fixed {
    public typealias Error = __ContainerCFixedError
}

// Test: Does throws(ContainerC.Fixed.Error) work?
// COMMENTED OUT - KNOWN TO FAIL
// extension ContainerC.Fixed where Element: ~Copyable & Ordering {
//     // Typealias through GENERIC type (in extension) - EXPECTED TO FAIL
//     public mutating func popC() throws(ContainerC.Fixed.Error) -> Element {
//         throw .empty
//     }
// }

// ============================================================================
// VARIANT D: TYPEALIAS INSIDE STRUCT BODY (not extension)
// ============================================================================

public enum __ContainerDFixedError: Swift.Error, Sendable, Equatable {
    case empty
    case invalidCapacity
}

public struct ContainerD<Element: ~Copyable & Ordering>: ~Copyable {
    var count: Int = 0

    public struct Fixed: ~Copyable {
        public typealias Error = __ContainerDFixedError  // Inside body, not extension
        var count: Int = 0
    }
}

// Test: Does throws(ContainerD.Fixed.Error) work when typealias is in body?
extension ContainerD.Fixed where Element: ~Copyable & Ordering {
    // Typealias defined in struct body - EXPECTED TO ???
    public mutating func popD() throws(ContainerD.Fixed.Error) -> Element {
        throw .empty
    }
}

// ============================================================================
// VARIANT E: LOCAL TYPEALIAS IN METHOD (within extension)
// ============================================================================

public enum __ContainerEFixedError: Swift.Error, Sendable, Equatable {
    case empty
    case invalidCapacity
}

public struct ContainerE<Element: ~Copyable & Ordering>: ~Copyable {
    var count: Int = 0

    public struct Fixed: ~Copyable {
        var count: Int = 0
    }
}

// COMMENTED OUT - visibility mismatch (not the issue we're investigating)
// extension ContainerE.Fixed where Element: ~Copyable & Ordering {
//     private typealias _Error = __ContainerEFixedError
//     public mutating func popE() throws(_Error) -> Element {
//         throw .empty
//     }
// }

// ============================================================================
// VARIANT F: DIRECT NESTED ENUM IN NESTED STRUCT (no hoisting, no typealias)
// ============================================================================

public struct ContainerF<Element: ~Copyable & Ordering>: ~Copyable {
    var count: Int = 0

    public struct Fixed: ~Copyable {
        // Error defined directly as nested enum - no hoisting at all
        public enum Error: Swift.Error, Sendable, Equatable {
            case empty
            case invalidCapacity
        }
        var count: Int = 0
    }
}

// Test: Does throws(ContainerF.Fixed.Error) work with direct nested enum?
extension ContainerF.Fixed where Element: ~Copyable & Ordering {
    // Direct nested enum in nested struct - WORKS
    public mutating func popF() throws(ContainerF.Fixed.Error) -> Element {
        throw .empty
    }
}

// ============================================================================
// VARIANT G: DIRECT NESTED ENUM IN OUTER GENERIC STRUCT
// ============================================================================

public struct ContainerG<Element: ~Copyable & Ordering>: ~Copyable {
    // Error defined directly in the outer generic struct
    public enum Error: Swift.Error, Sendable, Equatable {
        case empty
    }

    var count: Int = 0
}

// Test: Does throws(ContainerG.Error) work with direct nested enum in outer type?
extension ContainerG where Element: ~Copyable & Ordering {
    // Direct nested enum in outer generic - EXPECTED TO ???
    public mutating func popG() throws(ContainerG.Error) -> Element {
        throw .empty
    }
}

// ============================================================================
// MAIN
// ============================================================================

struct TestElement: Ordering {
    let value: Int
    static func < (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        lhs.value < rhs.value
    }
}

print("Experiment: typed-throws-error-alias")
print("Testing variants:")
print("A: Direct hoisted type - throws(__ContainerAFixedError)")
print("B: Non-generic namespace typealias - throws(ContainerBFixed.Error)")
print("C: Extension typealias on generic - throws(ContainerC.Fixed.Error)")
print("D: Body typealias on generic - throws(ContainerD.Fixed.Error)")
print("E: Local typealias in extension - throws(_Error)")

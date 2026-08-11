// MARK: - ~Copyable Cross-Module Propagation Investigation
// Purpose: Identify exact conditions where ~Copyable fails to propagate to cross-module generic types
//
// Hypothesis: The failure is triggered by specific struct configurations, not by the cross-module
// reference itself. We will find a struct configuration that works.
//
// Toolchain: Swift 6.0 (swift-6.0-RELEASE)
// Status: SUPERSEDED 2026-04-30 — Tagged<Element, Cardinal> generic arity surface changed; experiment's typed-count idiom requires re-targeting
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT (deep API drift; SUPERSEDED per [META-007])
// Platform: macOS Darwin 25.0.0
//
// Test Progression: [EXP-004a] Incremental Construction
//
// Results: TBD
// Date: 2026-01-20

@_exported import List_Primitives  // Module name uses underscores even though product uses spaces

// ============================================================================
// MARK: - Variant 1: Empty enum (baseline - should work, matches List pattern)
// ============================================================================
// Hypothesis: Empty enum with cross-module storage compiles
// Result: TBD

public enum V1_EmptyEnum<Element: ~Copyable> {}

extension V1_EmptyEnum where Element: ~Copyable {
    public struct Linked: ~Copyable {
        var _storage: List<Element>.Linked<1>

        public init() {
            self._storage = List<Element>.Linked<1>()
        }
    }
}

// ============================================================================
// MARK: - Variant 2: Struct with NO stored properties
// ============================================================================
// Hypothesis: Empty struct (no stored properties) with cross-module storage compiles
// Result: TBD

public struct V2_EmptyStruct<Element: ~Copyable>: ~Copyable {}

extension V2_EmptyStruct where Element: ~Copyable {
    public struct Linked: ~Copyable {
        var _storage: List<Element>.Linked<1>

        public init() {
            self._storage = List<Element>.Linked<1>()
        }
    }
}

// ============================================================================
// MARK: - Variant 3: Struct with unrelated stored property (Int)
// ============================================================================
// Hypothesis: Struct with simple stored property fails
// Result: TBD

public struct V3_StructWithInt<Element: ~Copyable>: ~Copyable {
    var _value: Int = 0
}

extension V3_StructWithInt where Element: ~Copyable {
    public struct Linked: ~Copyable {
        var _storage: List<Element>.Linked<1>

        public init() {
            self._storage = List<Element>.Linked<1>()
        }
    }
}

// ============================================================================
// MARK: - Variant 4: Struct with nested class using Element (like Queue.Storage)
// ============================================================================
// Hypothesis: Struct with class storing Element fails
// Result: TBD

public struct V4_StructWithStorage<Element: ~Copyable>: ~Copyable {
    final class Storage: ManagedBuffer<Int, Element> {
        static func create() -> Storage {
            let storage = Storage.create(minimumCapacity: 0) { _ in 0 }
            return unsafeDowncast(storage, to: Storage.self)
        }
    }

    var _storage: Storage

    public init() {
        self._storage = Storage.create()
    }
}

extension V4_StructWithStorage where Element: ~Copyable {
    public struct Linked: ~Copyable {
        var _storage: List<Element>.Linked<1>

        public init() {
            self._storage = List<Element>.Linked<1>()
        }
    }
}

// ============================================================================
// MARK: - Variant 5: Struct, nested type in body (not extension)
// ============================================================================
// Hypothesis: Nested type directly in struct body still fails
// Result: TBD

public struct V5_NestedInBody<Element: ~Copyable>: ~Copyable {
    var _value: Int = 0

    public struct Linked: ~Copyable {
        var _storage: List<Element>.Linked<1>

        public init() {
            self._storage = List<Element>.Linked<1>()
        }
    }
}

// ============================================================================
// MARK: - Variant 6: Module-level wrapper type
// ============================================================================
// Hypothesis: A module-level wrapper that captures ~Copyable might work
// Result: TBD

public struct LinkedListWrapper<Element: ~Copyable>: ~Copyable {
    var _inner: List<Element>.Linked<1>

    public init() {
        self._inner = List<Element>.Linked<1>()
    }
}

public struct V6_UsingWrapper<Element: ~Copyable>: ~Copyable {
    var _value: Int = 0
}

extension V6_UsingWrapper where Element: ~Copyable {
    public struct Linked: ~Copyable {
        var _storage: LinkedListWrapper<Element>

        public init() {
            self._storage = LinkedListWrapper<Element>()
        }
    }
}

// ============================================================================
// MARK: - Variant 7: Nested type with own generic parameter (SKIPPED)
// ============================================================================
// Hypothesis: Adding explicit generic parameter with constraint might work
// Result: SKIPPED - same-type constraint syntax issue, not relevant to investigation

// public struct V7_ExplicitGeneric<Element: ~Copyable>: ~Copyable {
//     var _value: Int = 0
// }
//
// extension V7_ExplicitGeneric where Element: ~Copyable {
//     public struct Linked<E: ~Copyable>: ~Copyable where E == Element {
//         var _storage: List<E>.Linked<1>
//
//         public init() {
//             self._storage = List<E>.Linked<1>()
//         }
//     }
// }

// ============================================================================
// MARK: - Variant 8: Conditional Copyable on outer struct
// ============================================================================
// Hypothesis: Making outer struct conditionally Copyable affects propagation
// Result: TBD

public struct V8_ConditionalCopyable<Element: ~Copyable>: ~Copyable {
    var _value: Int = 0
}

extension V8_ConditionalCopyable: Copyable where Element: Copyable {}

extension V8_ConditionalCopyable where Element: ~Copyable {
    public struct Linked: ~Copyable {
        var _storage: List<Element>.Linked<1>

        public init() {
            self._storage = List<Element>.Linked<1>()
        }
    }
}

// ============================================================================
// MARK: - Variant 9: Full Queue-like structure (with Storage class and @safe)
// ============================================================================
// Hypothesis: The full Queue structure might trigger the issue
// Result: TBD

@safe
public struct V9_FullQueue<Element: ~Copyable>: ~Copyable {
    final class Storage: ManagedBuffer<(head: Int, tail: Int, count: Int), Element> {
        static func create() -> Storage {
            let storage = Storage.create(minimumCapacity: 4) { _ in (0, 0, 0) }
            return unsafeDowncast(storage, to: Storage.self)
        }
    }

    var _storage: Storage
    var _cachedPtr: UnsafeMutablePointer<Element>

    public init() {
        self._storage = Storage.create()
        unsafe (self._cachedPtr = _storage.withUnsafeMutablePointerToElements { $0 })
    }

    // Nested linked type inside body
    @safe
    public struct Linked: ~Copyable {
        var _storage: List<Element>.Linked<1>

        public init() {
            self._storage = List<Element>.Linked<1>()
        }

        // Doubly-nested type
        @safe
        public struct Bounded: ~Copyable {
            var _storage: List<Element>.Linked<1>.Bounded

            public init(capacity: Int) throws {
                self._storage = try List<Element>.Linked<1>.Bounded(capacity: capacity)
            }
        }
    }
}

// ============================================================================
// MARK: - Test Execution
// ============================================================================

print("Testing ~Copyable cross-module propagation variants...")

// Test V1 - Empty enum
do {
    var v1 = V1_EmptyEnum<Int>.Linked()
    print("V1 (Empty enum): PASS")
}

// Test V2 - Empty struct
do {
    var v2 = V2_EmptyStruct<Int>.Linked()
    print("V2 (Empty struct): PASS")
}

// Test V3 - Struct with Int
do {
    var v3 = V3_StructWithInt<Int>.Linked()
    print("V3 (Struct with Int): PASS")
}

// Test V4 - Struct with Storage
do {
    var v4 = V4_StructWithStorage<Int>.Linked()
    print("V4 (Struct with Storage): PASS")
}

// Test V5 - Nested in body
do {
    var v5 = V5_NestedInBody<Int>.Linked()
    print("V5 (Nested in body): PASS")
}

// Test V6 - Using wrapper
do {
    var v6 = V6_UsingWrapper<Int>.Linked()
    print("V6 (Using wrapper): PASS")
}

// Test V7 - Explicit generic (SKIPPED)
print("V7 (Explicit generic): SKIPPED - syntax issue")

// Test V8 - Conditional Copyable
do {
    var v8 = V8_ConditionalCopyable<Int>.Linked()
    print("V8 (Conditional Copyable): PASS")
}

print("\nAll variants that compiled are listed above.")
print("Any variant that failed to compile will have produced a compile error.")

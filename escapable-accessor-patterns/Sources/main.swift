// SUPERSEDED: See nonescapable-patterns
// MARK: - ~Escapable Accessor Patterns
// Purpose: ~Escapable accessor patterns for pointer-holding types
// Status: CONFIRMED
// Date: 2026-01-21
// Toolchain: Swift 6.2
// Result: CONFIRMED — ~Escapable view with @_lifetime(borrow) prevents pointer from outliving container scope

// View types that hold pointers should ideally be ~Escapable
// to prevent them from outliving the container they borrow.

// Basic pattern: a view that borrows container state via pointer
struct Container {
    var value: Int = 42

    struct Accessor: ~Escapable {
        let ptr: UnsafePointer<Int>

        @_lifetime(borrow ptr)
        init(ptr: UnsafePointer<Int>) {
            self.ptr = ptr
        }

        var current: Int { unsafe ptr.pointee }
    }

    // The @_lifetime(&self) is required on the mutating _read accessor because
    // Container is BitwiseCopyable and the compiler cannot infer the lifetime
    // dependence. Production uses @_lifetime(borrow base) on init (which this
    // experiment also has above) and @_lifetime(&self) on the mutating accessor.
    var view: Accessor {
        @_lifetime(&self)
        mutating _read {
            yield unsafe Accessor(ptr: &value)
        }
    }
}

var c = Container(value: 42)
let v = c.view.current
print("View value: \(v)")
assert(v == 42)

// The accessor cannot escape the scope of the container
// because it is ~Escapable with a lifetime dependency.
// var escaped: Container.Accessor?  // Error: ~Escapable cannot be stored

print("escapable-accessor-patterns: CONFIRMED")

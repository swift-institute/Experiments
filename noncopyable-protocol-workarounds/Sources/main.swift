// MARK: - ~Copyable Protocol Workarounds
// Purpose: Protocols without Element associatedtype
// Status: WORKAROUND FOUND
// Date: 2026-01-22
// Toolchain: Swift 6.2

// Problem: Swift protocols implicitly require associated types to be Copyable.
// associatedtype Element: ~Copyable is not yet supported.

// Attempt 1: Protocol with associatedtype — this constrains to Copyable
protocol CollectionProtocol {
    associatedtype Element  // Implicitly: Element: Copyable
    var count: Int { get }
}

// Attempt 2: Generic struct without protocol — WORKAROUND
// Instead of protocols, use concrete generic types with ~Copyable constraints.
// The struct itself remains Copyable (all stored properties are Copyable),
// but it can be parameterized over ~Copyable element types.
struct Container<Element: ~Copyable> {
    private var _count: Int

    init() { _count = 0 }

    var count: Int { _count }

    mutating func add() {
        _count += 1
    }
}

// Attempt 3: Protocol with generic method instead of associated type — WORKAROUND
// Use a protocol that doesn't mention Element at all.
protocol CountableProtocol {
    var count: Int { get }
}

// Container can conform because it is Copyable (stored properties are all Copyable).
// The ~Copyable parameter doesn't affect the struct's own Copyability.
extension Container: CountableProtocol where Element: Copyable {}

// For ~Copyable elements, use the concrete type directly (no protocol witness)
struct Resource: ~Copyable { var id: Int }

var intContainer = Container<Int>()
intContainer.add()
intContainer.add()
print("Int container count: \(intContainer.count)")  // 2
assert(intContainer.count == 2)

// Can use protocol for Copyable element types
let countable: any CountableProtocol = intContainer
print("Protocol count: \(countable.count)")  // 2

var resContainer = Container<Resource>()
resContainer.add()
print("Resource container count: \(resContainer.count)")  // 1
assert(resContainer.count == 1)
// Cannot use protocol: Container<Resource> does not conform to CountableProtocol
// because the conformance requires `where Element: Copyable`

print("noncopyable-protocol-workarounds: WORKAROUND FOUND")

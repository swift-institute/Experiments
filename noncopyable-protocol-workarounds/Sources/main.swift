// SUPERSEDED: See noncopyable-constraint-behavior
// MARK: - ~Copyable Protocol Workarounds
// Purpose: Protocol associatedtype ~Copyable support
// Status: RESOLVED (was WORKAROUND FOUND)
// Result: CONFIRMED — SuppressedAssociatedTypes feature flag enables associatedtype Element: ~Copyable directly
// Date: 2026-01-22 (original), 2026-03-10 (updated)
// Toolchain: Swift 6.2 (original), Swift 6.2.4 (resolution)
//
// Original limitation: `associatedtype Element: ~Copyable` was not supported.
// Resolution: SuppressedAssociatedTypes experimental feature enables it.
// Production: Sequence.Protocol, Hash.Protocol, Equation.Protocol all use
//   `associatedtype Element: ~Copyable` with the feature flag enabled in
//   every production Package.swift.
//
// Production example (swift-sequence-primitives):
//   public protocol `Protocol`: ~Copyable, ~Escapable {
//       associatedtype Element: ~Copyable
//       ...
//   }

// --- Historical limitation (Swift 6.2 without feature flag) ---
// protocol CollectionProtocol {
//     associatedtype Element  // Implicitly: Element: Copyable
//     var count: Int { get }
// }
// Cannot use CollectionProtocol with ~Copyable element types.

// --- Demonstration without the feature flag ---
// Without SuppressedAssociatedTypes, concrete generics are the workaround:

struct Container<Element: ~Copyable>: ~Copyable {
    private var _count: Int

    init() { _count = 0 }
    var count: Int { _count }
    mutating func add() { _count += 1 }
}

// Protocol without Element associated type still works.
// Note: the protocol itself must suppress Copyable to accept ~Copyable conformers.
protocol Countable: ~Copyable {
    var count: Int { get }
}

extension Container: Countable where Element: ~Copyable {}

struct Resource: ~Copyable { var id: Int }

var intContainer = Container<Int>()
intContainer.add()
intContainer.add()
print("Int container count: \(intContainer.count)")
assert(intContainer.count == 2)

// Can use protocol for both Copyable and ~Copyable element types
print("Protocol-conforming Int container: \(intContainer.count)")

var resContainer = Container<Resource>()
resContainer.add()
print("Resource container count: \(resContainer.count)")
assert(resContainer.count == 1)

// With SuppressedAssociatedTypes (production), the concrete-generic
// workaround is no longer needed. Production uses protocols directly:
//
//   public protocol `Protocol`: ~Copyable, ~Escapable {
//       associatedtype Element: ~Copyable
//       func forEach(_ body: (borrowing Element) -> Void)
//   }
//
// Enabled by: .enableExperimentalFeature("SuppressedAssociatedTypes")

print("noncopyable-protocol-workarounds: RESOLVED")

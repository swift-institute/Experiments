// Protocols module — simulates Collection_Primitives
// Tests cross-module protocol inheritance with ~Copyable subscript { get }
// Incrementally adds production-specific factors to find the trigger

// Phantom-typed index (simulates Index_Primitives.Index<Element>)
public struct PhantomIndex<Element: ~Copyable>: Comparable, Sendable {
    public let position: Int
    public init(position: Int) { self.position = position }
    public static func < (lhs: PhantomIndex, rhs: PhantomIndex) -> Bool {
        lhs.position < rhs.position
    }
}

// ============================================================================
// MARK: - Top-level protocols (original experiment — CONFIRMED working)
// ============================================================================

public protocol CollectionProtocol: ~Copyable {
    associatedtype Element: ~Copyable
    typealias Index = PhantomIndex<Element>
    var startIndex: Index { get }
    var endIndex: Index { get }
    subscript(_ position: Index) -> Element { get }
    func index(after i: Index) -> Index
}

public protocol Bidirectional: CollectionProtocol & ~Copyable {
    func index(before i: Index) -> Index
}

// ============================================================================
// MARK: - Nested protocols (simulates Collection.Protocol / .Bidirectional)
// ============================================================================

// V7 namespace: same name as stdlib Collection — test name collision
public enum Collection {}

extension Collection {
    public protocol `Protocol`: ~Copyable {
        associatedtype Element: ~Copyable
        typealias Index = PhantomIndex<Element>
        var startIndex: Index { get }
        var endIndex: Index { get }
        subscript(_ position: Index) -> Element { get }
        func index(after i: Index) -> Index
    }
}

extension Collection {
    public protocol Bidir: Collection.`Protocol` & ~Copyable {
        func index(before i: Index) -> Index
    }
}

// ============================================================================
// MARK: - Nested protocols + separate Indexed (no Element, no subscript)
// ============================================================================

extension Collection {
    public protocol Indexed: ~Copyable {
        associatedtype Index: Comparable
        var startIndex: Index { get }
        var endIndex: Index { get }
        func index(after i: Index) -> Index
    }
}

// ============================================================================
// MARK: - Namespace for array-like types
// ============================================================================

public enum Arr<Element: ~Copyable> {}

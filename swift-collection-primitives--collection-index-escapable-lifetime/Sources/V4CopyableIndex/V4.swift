// MARK: - V4: ~Copyable Index associatedtype — the hard wall
// The other half of "suppress where possible": can the Index be ~Copyable?
// Reduced per [EXP-004] to the first blocker — the subscript parameter.
// Status: EXPECT REFUTED — subscript cannot take a noncopyable parameter (6.3)
// Toolchain: Apple Swift 6.3.2
// Result: REFUTED — error: subscripts cannot have noncopyable parameters yet
//   (V4.swift:19). Cmd: swift build --target V4CopyableIndex
public import Comparison_Primitives

public enum ExpCollectionNC {}

extension ExpCollectionNC {
    public protocol `Protocol`: ~Copyable {
        associatedtype Element: ~Copyable

        // The bound admits a ~Copyable index (Comparison.`Protocol` is ~Copyable).
        associatedtype Index: Comparison.`Protocol` & ~Copyable

        // The blocker: a noncopyable index as a subscript parameter.
        subscript(_ position: Index) -> Element { get }
    }
}

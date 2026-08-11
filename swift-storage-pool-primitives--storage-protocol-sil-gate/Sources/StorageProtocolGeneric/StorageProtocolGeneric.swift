// MARK: - Storage.Protocol Specialization Gate
//
// Purpose: Prove a `some Storage.`Protocol`` generic specializes to ZERO
//          witness-table dispatch through real STRUCT (Storage.Inline) and
//          CLASS (Storage.Pool) conformers, in release + cross-module.
// Hypothesis: With both conformers `@inlinable` and specializable, a generic
//          that calls `capacity` and `pointer(at:)` emits NO `witness_method`
//          in the specialized concrete call bodies under -c release.
//
// Toolchain: Apple Swift 6.3.2 (default macOS toolchain)
// Platform: macOS 26 (arm64)
//
// Status: see Outputs/sil-grep.txt and Outputs/build-release.txt
// Result: CONFIRMED — under -O the @inlinable probe<S> body inlines into the two
//         concrete callers; the inlined capacity / pointer(at:) sites carry 0
//         witness_method (and 0 class_method) for BOTH Inline and Pool.

public import Storage_Protocol_Primitives
public import Index_Primitives

/// Reads slot `slot` and the storage's `capacity` through the
/// `Storage.`Protocol`` witness, touching BOTH requirements so the SIL dump
/// records dispatch for each.
///
/// `@inlinable` is required for cross-module specialization: the body must be
/// visible to the second module for the optimizer to emit a specialized,
/// witness-free clone.
@inlinable
public func probe<S: Storage.`Protocol` & ~Copyable>(
    _ storage: borrowing S,
    at slot: Index<Int>
) -> Int where S.Element == Int {
    // capacity requirement
    let capacity: Index<Int>.Count = storage.capacity
    // pointer(at:) requirement
    let pointer: UnsafeMutablePointer<Int> = unsafe storage.pointer(at: slot)
    // Touch both so neither call is dead-code-eliminated before specialization.
    return unsafe pointer.pointee &+ Int(bitPattern: capacity)
}

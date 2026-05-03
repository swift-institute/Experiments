@_exported public import L1Defs
public import Carrier_Primitives

// L2 spec namespace — plain struct + Carrier conformance as trivial
// self-carrier. Per-package convention: the L2 type is the canonical
// data type and its own Underlying. Adding `: Carrier` with
// `typealias Underlying = Self` is a one-line opt-in that costs nothing
// and unlocks `some Carrier<L2.Type>` generics across the ecosystem.
public enum ISO_9945 {}
extension ISO_9945 { public enum Kernel {} }
extension ISO_9945.Kernel { public enum File {} }

extension ISO_9945.Kernel.File {
    public struct Stats: Sendable, Equatable {
        public let size: Int64
        public let permissions: UInt16

        public init(descriptor: Int32) throws(FooError) {
            if descriptor == -1 { throw FooError.interrupted }
            self.size = 1024
            self.permissions = 0o644
        }
    }
}

// Trivial self-carrier conformance — `Underlying == Self`. The
// default `var underlying: Self { _read { yield self } }` and
// `init(_:)` come from the extension at
// `swift-carrier-primitives/Sources/Carrier Primitives/Carrier where
// Underlying == Self.swift`.
extension ISO_9945.Kernel.File.Stats: Carrier.`Protocol` {
    public typealias Underlying = ISO_9945.Kernel.File.Stats
}

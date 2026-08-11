//
//  Kernel.Descriptor — opaque kernel file descriptor.
//
//  NOTE: Kept Copyable in this sketch to keep the focus on composition via
//  .map. The ~Copyable form is exercised in io-witness-shape-f. Mixing
//  ~Copyable return types with the @Witness macro's Observe synthesis is
//  tested separately in io-witness-macro-generic-compat-adjacent sketches.
//

extension Kernel {
    public struct Descriptor: Sendable {
        public let raw: Int32

        public init(raw: Int32) {
            self.raw = raw
        }
    }
}

extension Kernel {
    public struct Descriptor {  // Copyable for sketch simplicity
        public let raw: Int32

        public init(raw: Int32) {
            self.raw = raw
        }
    }
}

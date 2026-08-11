// V04: Cross-Module Core — Types defined in separate module
// Supports: diagnosis Step 8 — cross-module boundary effect
//
// In production, types extending Buffer from a DIFFERENT module
// always crash (even 1 type in struct-body pattern). The struct-body
// threshold only holds within the defining module.

public import Storage_Primitives

public enum Container<Element: ~Copyable> {
    public struct Header: ~Copyable {
        public var count: Int

        public init() { self.count = 0 }
    }
}

// Type defined here (in Core module), consumed from V04-cross-module
extension Container {
    public struct Ring: ~Copyable {
        public var header: Header

        @_rawLayout(likeArrayOf: Element, count: capacity)
        public struct Inline<let capacity: Int>: ~Copyable {
            public init() {}
            deinit { }
        }

        public init() {
            self.header = Header()
        }
    }
}

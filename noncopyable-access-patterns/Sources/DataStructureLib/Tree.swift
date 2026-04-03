public import BufferLib

public struct Tree<Element: ~Copyable, let N: Int>: ~Copyable {
    // Forces deinit to execute cross-module
    private var _deinitWorkaround: AnyObject? = nil

    public var buffer: Buffer<Element, N>

    @inlinable
    public init() {
        buffer = Buffer<Element, N>()
    }

    deinit {
        buffer.removeAll()  // consuming call — consumes buffer in deinit
    }
}

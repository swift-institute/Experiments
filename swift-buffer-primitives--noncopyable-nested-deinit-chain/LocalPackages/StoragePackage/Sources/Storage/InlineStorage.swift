// Minimal @_rawLayout storage for reproducing swiftlang/swift #86652.
//
// @_rawLayout is the critical ingredient. When a ~Copyable struct in package A
// stores this type from package B, the compiler fails to synthesize member
// destruction — elements silently leak.

/// Single-element inline storage using @_rawLayout.
public struct RawBox<Element: ~Copyable>: ~Copyable {

    @_rawLayout(like: Element)
    @usableFromInline
    package struct _Raw: ~Copyable {
        @usableFromInline
        init() {}
    }

    @usableFromInline
    package var _storage: _Raw

    @usableFromInline
    package var _initialized: Bool

    @inlinable
    public init(_ element: consuming Element) {
        _storage = _Raw()
        _initialized = true
        let ptr = unsafe _pointer()
        unsafe ptr.initialize(to: element)
    }

    @unsafe
    @usableFromInline
    func _pointer() -> UnsafeMutablePointer<Element> {
        unsafe withUnsafePointer(to: _storage) { raw in
            unsafe UnsafeMutablePointer(
                mutating: UnsafeRawPointer(raw).assumingMemoryBound(to: Element.self)
            )
        }
    }

    /// Manual cleanup for workaround callers.
    @inlinable
    public mutating func destroy() {
        if _initialized {
            unsafe _pointer().deinitialize(count: 1)
            _initialized = false
        }
    }

    deinit {
        if _initialized {
            unsafe _pointer().deinitialize(count: 1)
        }
    }
}

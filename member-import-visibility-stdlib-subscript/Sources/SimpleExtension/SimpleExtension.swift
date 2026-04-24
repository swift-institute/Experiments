// Non-generic extension subscript on UnsafePointer — no protocol constraint

extension UnsafePointer {
    @inlinable
    public subscript(at offset: Int) -> Pointee {
        get {
            unsafe self[offset]
        }
    }
}

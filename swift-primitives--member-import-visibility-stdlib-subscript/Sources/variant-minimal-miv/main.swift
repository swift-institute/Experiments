// Verify underscore internal name workaround

protocol P { var rawValue: Int { get } }
struct Idx: P { var rawValue: Int }

extension Array {
    subscript<O: P>(position _position: O) -> Element { self[_position.rawValue] }
}

extension UnsafePointer {
    subscript<O: P>(position _position: O) -> Pointee {
        get { unsafe self[_position.rawValue] }
    }
}

print([1, 2, 3][position: Idx(rawValue: 0)])

[10, 20, 30].withUnsafeBufferPointer { buf in
    let ptr = buf.baseAddress!
    print(unsafe ptr[position: Idx(rawValue: 1)])
}

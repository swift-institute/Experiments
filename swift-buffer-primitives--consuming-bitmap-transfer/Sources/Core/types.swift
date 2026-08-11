// Core module — mimics Buffer_Primitives_Core
// The type is declared here, consumed in another module.

/// Mimics Bit.Vector — a ~Copyable type with heap storage.
public struct Bitmap: ~Copyable {
    public var data: [Int]

    public init(data: [Int]) {
        self.data = data
    }

    deinit {
        print("Bitmap.deinit (data: \(data))")
    }
}

/// Mimics Storage<Element>.Heap — a class (Copyable).
public final class Storage: Sendable {
    public let name: String
    public init(name: String) { self.name = name }
}

/// Mimics Buffer.Slab.Header — ~Copyable because it contains Bitmap.
public struct Header: ~Copyable {
    public var bitmap: Bitmap

    public init(bitmap: consuming Bitmap) {
        self.bitmap = bitmap
    }

    /// Replaces the bitmap with an empty one and returns the original.
    /// The caller takes ownership; deinit will find the empty replacement.
    public mutating func takeBitmap() -> Bitmap {
        var empty = Bitmap(data: [])
        swap(&bitmap, &empty)
        return empty
    }
}

/// Mimics Buffer.Slab — ~Copyable, declared in Core, consumed in another module.
public struct Container: ~Copyable {
    public var header: Header
    public var storage: Storage

    public init(header: consuming Header, storage: Storage) {
        self.header = header
        self.storage = storage
    }

    deinit {
        print("Container.deinit — bitmap at deinit has \(header.bitmap.data)")
    }
}

// MARK: - Frozen variants (Variant 6)

@frozen
public struct FrozenHeader: ~Copyable {
    public var bitmap: Bitmap
    public init(bitmap: consuming Bitmap) {
        self.bitmap = bitmap
    }
}

@frozen
public struct FrozenContainer: ~Copyable {
    public var header: FrozenHeader
    public var storage: Storage

    public init(header: consuming FrozenHeader, storage: Storage) {
        self.header = header
        self.storage = storage
    }

    deinit {
        print("FrozenContainer.deinit — bitmap at deinit has \(header.bitmap.data)")
    }
}

// MARK: - No-deinit variant (Variant 8)

public struct NoDeinitContainer: ~Copyable {
    public var header: Header
    public var storage: Storage

    public init(header: consuming Header, storage: Storage) {
        self.header = header
        self.storage = storage
    }
    // No deinit — partial consumption should work in same module
}

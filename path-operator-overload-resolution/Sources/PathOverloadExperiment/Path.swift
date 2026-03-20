// Faithful reproduction of Path for overload resolution testing.
// Matches the real swift-paths types' protocol conformances and throwing initializers.

public struct Path: Copyable, Sendable, Hashable {
    @usableFromInline
    internal var _storage: [UInt8]

    public init(_ string: String) throws(Error) {
        guard !string.isEmpty else { throw .empty }
        var buffer: [UInt8] = []
        buffer.reserveCapacity(string.utf8.count + 1)
        for byte in string.utf8 {
            if byte == 0 { throw .containsInteriorNUL }
            if byte < 0x20 || byte == 0x7F { throw .containsControlCharacters }
            buffer.append(byte)
        }
        buffer.append(0)
        self._storage = buffer
    }

    @usableFromInline
    internal init(unchecked storage: [UInt8]) {
        self._storage = storage
    }

    @inlinable
    public var string: String {
        String(decoding: _storage.dropLast(), as: UTF8.self)
    }

    public var isAbsolute: Bool {
        _storage.first.map { $0 == UInt8(ascii: "/") } ?? false
    }

    @inlinable
    public func appending(_ component: Component) -> Path {
        let s = string
        let needsSep = !s.isEmpty && !s.hasSuffix("/")
        let newPath = needsSep ? s + "/" + component.string : s + component.string
        return (try? Path(newPath)) ?? self
    }

    @inlinable
    public func appending(_ other: Path) -> Path {
        if other.isAbsolute { return other }
        let s = string
        let needsSep = !s.isEmpty && !s.hasSuffix("/")
        let newPath = needsSep ? s + "/" + other.string : s + other.string
        return (try? Path(newPath)) ?? self
    }

    public enum Error: Swift.Error, Sendable, Equatable {
        case empty
        case containsControlCharacters
        case containsInteriorNUL
    }
}

// MARK: - Component

extension Path {
    public struct Component: Copyable, Sendable, Hashable {
        @usableFromInline
        internal var _storage: [UInt8]

        public init(_ string: String) throws(Error) {
            guard !string.isEmpty else { throw .empty }
            var buffer: [UInt8] = []
            buffer.reserveCapacity(string.utf8.count + 1)
            for byte in string.utf8 {
                if byte == 0 { throw .containsInteriorNUL }
                if byte == UInt8(ascii: "/") { throw .containsPathSeparator }
                if byte < 0x20 || byte == 0x7F { throw .containsControlCharacters }
                buffer.append(byte)
            }
            buffer.append(0)
            self._storage = buffer
        }

        @inlinable
        public var string: String {
            String(decoding: _storage.dropLast(), as: UTF8.self)
        }

        public enum Error: Swift.Error, Sendable, Equatable {
            case empty
            case containsPathSeparator
            case containsControlCharacters
            case containsInteriorNUL
        }
    }
}

// MARK: - Operators (Baseline: both overloads)

extension Path {
    @inlinable
    public static func / (lhs: Path, rhs: Component) -> Path {
        lhs.appending(rhs)
    }

    @_disfavoredOverload
    @inlinable
    public static func / (lhs: Path, rhs: Path) -> Path {
        lhs.appending(rhs)
    }
}

// MARK: - ExpressibleByStringLiteral

extension Path: ExpressibleByStringLiteral {
    @inlinable
    public init(stringLiteral value: String) {
        do {
            try self.init(value)
        } catch {
            fatalError("Invalid path literal: \(value) (\(error))")
        }
    }
}

extension Path: ExpressibleByStringInterpolation {}

extension Path.Component: ExpressibleByStringLiteral {
    @inlinable
    public init(stringLiteral value: String) {
        do {
            try self.init(value)
        } catch {
            fatalError("Invalid component literal: \(value) (\(error))")
        }
    }
}

extension Path.Component: ExpressibleByStringInterpolation {}

// MARK: - CustomStringConvertible

extension Path: CustomStringConvertible {
    public var description: String { string }
}

extension Path: CustomDebugStringConvertible {
    public var debugDescription: String { "Path(\"\(string)\")" }
}

extension Path.Component: CustomStringConvertible {
    public var description: String { string }
}

extension Path.Component: CustomDebugStringConvertible {
    public var debugDescription: String { "Path.Component(\"\(string)\")" }
}

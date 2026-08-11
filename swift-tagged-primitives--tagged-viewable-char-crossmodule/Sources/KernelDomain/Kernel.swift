// KernelDomain module: Kernel namespace + typealiases (mirrors kernel-primitives)

public import Core
public import StringDomain
public import PathDomain

public enum Kernel {}

extension Kernel {
    public typealias Path = Tagged<Kernel, MyPath>
    public typealias String = Tagged<Kernel, MyString>
}

// View works (protocol-based via Viewable)
public let _viewTestPath: Kernel.Path.View.Type = MyPath.View.self
public let _viewTestString: Kernel.String.View.Type = MyString.View.self

// Char must use raw type directly (compiler bug prevents Tagged.Char)
public let _charTestPath: MyPath.Char.Type = UInt8.self
public let _charTestString: MyString.Char.Type = UInt8.self

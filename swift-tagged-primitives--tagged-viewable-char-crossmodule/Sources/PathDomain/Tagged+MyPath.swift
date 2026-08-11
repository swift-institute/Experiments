// PathDomain module: Tagged extension for Path (mirrors path-primitives)
// NOTE: Char typealias removed — causes Swift compiler bug when two constrained
// extensions on Tagged both provide a typealias with the same name.

public import Core

// This extension WORKS in isolation. It FAILS when StringDomain also provides Char.
// extension Tagged where RawValue == MyPath, Tag: ~Copyable {
//     public typealias Char = MyPath.Char
// }

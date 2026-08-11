// StringDomain module: Tagged extension for String (mirrors string-primitives)
// NOTE: Char typealias removed — causes Swift compiler bug when two constrained
// extensions on Tagged both provide a typealias with the same name.

public import Core

// This extension WORKS in isolation. It FAILS when PathDomain also provides Char.
// extension Tagged where RawValue == MyString, Tag: ~Copyable {
//     public typealias Char = MyString.Char
// }

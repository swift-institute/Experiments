// MARK: - Tagged Constrained Extension Typealias Collision
// Purpose: Verify whether two constrained extensions on Tagged<Tag, RawValue>,
//          each providing `typealias Char`, can coexist when both are visible.
//
// Hypothesis: Two non-overlapping constrained extensions on a generic type
//             (where RawValue == A vs where RawValue == B) should each resolve
//             their own Char typealias independently.
//
// Module structure (mirrors production):
//   Core:         Tagged, Viewable, Tagged: Viewable
//   StringDomain: MyString, MyString.Char, extension Tagged where RawValue == MyString { Char }
//   PathDomain:   MyPath, MyPath.Char, extension Tagged where RawValue == MyPath { Char }
//   KernelDomain: Kernel.Path = Tagged<Kernel, MyPath>, Kernel.String = Tagged<Kernel, MyString>
//   App:          Uses Kernel.Path.Char + Kernel.String.Char
//
// Toolchain: swift-6.2-DEVELOPMENT-SNAPSHOT-2026-02-13-a
// Platform: macOS 26.0 (arm64)
//
// Result: REFUTED — Swift compiler bug. When two constrained extensions on a
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//         generic type both provide a typealias with the same name, the compiler
//         picks the first one found and errors instead of evaluating constraints.
//
//         Error: 'Tagged<Tag, RawValue>.Char' (aka 'UInt8') requires the types
//                'MyPath' and 'MyString' be equivalent
//         Command: swift build (from experiment root)
//
//         Variants tested, ALL fail the same way:
//           - Cross-module extensions (original reproduction)
//           - Same-module extensions
//           - With/without Tag: ~Copyable
//           - Fully constrained (Tag == X, RawValue == Y)
//           - With/without Viewable conformance
//           - With/without MemberImportVisibility
//
//         Protocol-based resolution (Viewable for View) works correctly.
//         Resolution: Don't put Char on Tagged. Use Path.Char / String.Char directly.
//
// Date: 2026-02-28

import Core
import StringDomain
import PathDomain
import KernelDomain

// Direct types work — no ambiguity
let _: MyPath.Char.Type = UInt8.self
let _: MyString.Char.Type = UInt8.self
print("Direct MyPath.Char + MyString.Char: CONFIRMED")

// Protocol-based View resolution works
let _: Kernel.Path.View.Type = MyPath.View.self
let _: Kernel.String.View.Type = MyString.View.self
print("Kernel.Path.View + Kernel.String.View (via Viewable): CONFIRMED")

// Kernel.Path.Char and Kernel.String.Char CANNOT coexist.
// Uncommenting either line below produces:
//   error: 'Tagged<Tag, RawValue>.Char' requires the types 'MyPath' and 'MyString' be equivalent
//
// let _: Kernel.Path.Char.Type = UInt8.self     // FAILS
// let _: Kernel.String.Char.Type = UInt8.self   // FAILS

print("All executable variants passed.")

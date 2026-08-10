// Check #2 — does `String.UTF8View.withContiguousStorageIfAvailable` fire?
//
// Verifies: for the Strings that real JSON consumers pass, does the
// contiguous-storage fast path engage, or does the slow path always
// kick in?
//
// Probes (all without Foundation):
//   1. Small ASCII literal              (small-string optimization)
//   2. Larger ASCII string built at runtime
//   3. Unicode string with non-ASCII content
//   4. Slice / Substring's `.utf8` view (composability check)
//   5. String built from `[UInt8]` via decoding
//   6. String built from utf8 literal with many code points
//
// Also runs Span access — for each probe, if `withContiguousStorageIfAvailable`
// fires, then ALSO try `.utf8.span` directly (Swift 6.x stdlib).

import Foundation  // permitted in check tooling only — confirms NSString bridging behavior

func describeWCSA(label: String, _ string: String) {
    let utf8 = string.utf8
    let count = utf8.count
    let result = utf8.withContiguousStorageIfAvailable { buffer -> Int in
        // Touch the buffer to prove we got real storage
        var sum: UInt64 = 0
        for b in buffer { sum = sum &+ UInt64(b) }
        return Int(truncatingIfNeeded: sum)
    }
    let fired = result != nil
    print("  \(label): count=\(count), withContiguousStorageIfAvailable=\(fired ? "FIRED" : "NIL")")
}

print("=== check-contiguous-storage ===")
print("Probes for String.UTF8View.withContiguousStorageIfAvailable")
print("")

// Probe 1: small ASCII literal
describeWCSA(label: "small ASCII literal (15 chars)", "hello world JSON")

// Probe 2: larger ASCII built at runtime
let larger = String(repeating: "abc", count: 1000)
describeWCSA(label: "large ASCII (3000 chars, runtime-built)", larger)

// Probe 3: Unicode with non-ASCII
describeWCSA(label: "Unicode (Cyrillic + emoji)", "Привет, мир! 🚀")

// Probe 4: Substring's .utf8 view
let parent = "the quick brown fox jumps over the lazy dog"
let sub = parent.dropFirst(4).prefix(15)  // "quick brown fox"
print("  substring .utf8.withContiguousStorageIfAvailable:")
let subResult = sub.utf8.withContiguousStorageIfAvailable { buf -> Int in buf.count }
print("    fired=\(subResult != nil) count=\(sub.utf8.count)")

// Probe 5: String built from [UInt8] via decoding
let bytes: [UInt8] = Array("decoded from bytes".utf8)
let decoded = String(decoding: bytes, as: UTF8.self)
describeWCSA(label: "String(decoding: [UInt8])", decoded)

// Probe 6: Bridged NSString (Foundation interop — the doc's known-slow case)
let nsString = NSString(string: "bridged from NSString")
let bridged = nsString as String
describeWCSA(label: "NSString-as-String (bridged)", bridged)

// Probe 7: NSString constructed in a way that may stay bridged
let nsString2 = NSString(string: String(repeating: "x", count: 100))
let bridged2 = nsString2 as String
describeWCSA(label: "longer NSString-as-String", bridged2)

// Probe 8: .span direct access — modern Swift 6.x form
print("")
print("=== Modern .span direct access (Swift 6.x stdlib) ===")
let arr: [UInt8] = Array("array of bytes for span test".utf8)
do {
    let s = arr.span
    var sum: UInt64 = 0
    for i in s.indices { sum = sum &+ UInt64(s[i]) }
    print("  [UInt8].span: count=\(s.count), sum=\(sum) (PASS)")
}

// .utf8.span isn't yet a stable stdlib method on String.UTF8View as of writing.
// Probe via reflection — does `String.UTF8View` have a `.span` accessor?
let testStr = "span-on-utf8-view test"
let mirror = Mirror(reflecting: testStr.utf8)
print("  String.UTF8View mirror children: \(mirror.children.count)")

print("")
print("done.")

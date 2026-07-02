// MARK: - client — cross-module consumer of the alias front-doors ([EXP-017])
//
// Exercises every spelling a real consumer would write, from ANOTHER module:
//   1. canonical alias:            Vector<Int>
//   2. variant via nested alias:   Vector<Int>.Small<8>
//   3. value-generic pinned init through the alias chain
//   4. a ~Copyable element through the same chain
//   5. generic algorithm over the carrier (any column)
//
// Result: CONFIRMED — all five spellings compile+run cross-module, debug AND release,
//         with 0 witness_method in the -O client SIL. See FrontDoors.swift header.

import FrontDoors

// 1. Canonical spelling + init through the alias.
var v = Vector<Int>(minimumCapacity: 2)
v.append(10)
v.append(20)
v.append(30) // forces growth past minimumCapacity
print("canonical: count=\(v.count) v[2]=\(v[2])")

// 2 + 3. Variant spelling THROUGH the canonical alias; value-generic pinned init.
var s = Vector<Int>.Small<8>()
s.append(1)
s.append(2)
s[1] += 40
print("small: count=\(s.count) s[1]=\(s[1])")

// 4. ~Copyable element through the whole chain.
struct MO: ~Copyable {
    var x: Int
    init(_ x: Int) { self.x = x }
}
var m = Vector<MO>.Small<4>()
m.append(MO(7))
m[0].x += 1
print("moSmall: count=\(m.count) m[0].x=\(m[0].x)")

// 5. Generic algorithm over ANY column (the write-once consumer surface).
func total<S: Seam & ~Copyable>(_ vec: borrowing __Vector<S>) -> Int where S.Element == Int {
    var t = 0
    for i in 0..<vec.count { t += vec[i] }
    return t
}
print("generic: total(v)=\(total(v)) total(s)=\(total(s))")

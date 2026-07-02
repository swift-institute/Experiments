// p7: bare `extension` on a ~Copyable-generic type constrains to Copyable. Expect: ERROR at use with MO.
// Result (Apple Swift 6.3.3, 2026-07-02): STILL PRESENT — bare extension constrains to Copyable; error at ~Copyable use site.
struct W7<T: ~Copyable>: ~Copyable { var t: T }
extension W7 { func f() {} }
struct MO: ~Copyable {}
let w = W7(t: MO())
w.f()
print("p7 compiled (unexpected)")

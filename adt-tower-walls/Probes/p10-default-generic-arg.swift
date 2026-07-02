// p10: default generic arguments. Expect: ERROR (not grammar).
// Result (Apple Swift 6.3.3, 2026-07-02): STILL PRESENT — default generic arguments are not grammar.
struct D<A, B = Int> { }
print("p10 compiled (unexpected)")

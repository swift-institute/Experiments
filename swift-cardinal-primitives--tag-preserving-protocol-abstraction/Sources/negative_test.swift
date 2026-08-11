// Negative test: this file should NOT compile.
// Uncomment the body to verify cross-domain rejection.

#if NEGATIVE_TEST
enum NegFoo {}
enum NegBar {}

func negativeCrossDomainTest() {
    let taggedO = Tagged<NegFoo, Ordinal>(__unchecked: (), Ordinal(10))
    let badC = Tagged<NegBar, Cardinal>(__unchecked: (), Cardinal(3))
    // This should produce: "Generic parameter 'C' (Tagged<NegBar, Cardinal>) requires
    // that 'NegBar' and 'NegFoo' be the same type" (or similar)
    let _ = taggedO + badC
}
#endif

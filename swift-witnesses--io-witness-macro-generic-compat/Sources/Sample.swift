//
// Sample namespace — hosts the sample leaf-error type used to instantiate
// IO<LeafError> in this experiment. Separated from IO because IO's generic
// parameter slot (`LeafError`) is already the "error" position for IO —
// nesting a concrete error as `IO.Error` would conflict with that role and
// mislead readers into thinking it is the canonical error type of IO.
//
// `Sample.Error` instead reads as "the sample leaf error used to demonstrate
// macro-generic compatibility", which matches the experiment's intent.
//

public enum Sample {}

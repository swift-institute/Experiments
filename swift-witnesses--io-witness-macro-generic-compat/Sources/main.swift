public import Witnesses

// If IO.swift compiles, this line confirms `unimplemented()` respects the
// generic parameter. If it doesn't compile, the build failure is already
// the answer.
let demo: IO<Sample.Error> = .unimplemented()
_ = demo

print("Macro-generic-compat built — hypothesis REFUTED in the surprising direction: macro handles generics.")

// Module B — the box + the evidence matrix. Run BOTH configs:
//   swift run Repro            (debug — expect all OK)
//   swift run -c release Repro (release — expect the `box + IKUR` rows to print SKIP)
//
// SKIP means: the user deinit did NOT run (oracleDeinit=0) while the stored fields WERE
// destroyed (fieldFree=1) — elements would leak while their bytes are freed.
import Nested

final class Box<W: ~Copyable> {                    // the generic refcounted box
    var w: W
    init(_ w: consuming W) { self.w = w }
}

final class BoxEmptyDeinit<W: ~Copyable> {         // probed mitigation: empty user deinit — ✗
    var w: W
    init(_ w: consuming W) { self.w = w }
    deinit {}
}

final class BoxDrain {                             // the WORKING mitigation: deinit DRAINS — ✓
    var w: NS<Region>.InnerD<Payload>
    init(_ w: consuming NS<Region>.InnerD<Payload>) { self.w = w }
    deinit { w.drain() }
}

final class Payload {}

var failures = 0

@MainActor
func check(_ label: String, expectDrains: Int = 0, _ body: () -> Void) {
    Counter.shared.reset()
    body()
    let d = Counter.shared.deinits, f = Counter.shared.fieldFrees, r = Counter.shared.drains
    let ok = f == 1 && (expectDrains > 0 ? r == expectDrains : d == 1)
    if !ok { failures += 1 }
    print("\(label): userDeinit=\(d) fieldFree=\(f) drains=\(r) \(ok ? "OK" : "** SKIP — user deinit omitted **")")
}

check("nested, no box, direct drop          ") { _ = NS<Region>.Inner<Payload>(region: Region()) }
check("nested, boxed, NO uniqueness call    ") { _ = Box(NS<Region>.Inner<Payload>(region: Region())) }
check("nested, boxed, + isKnownUniquelyRef  ") {
    var b = Box(NS<Region>.Inner<Payload>(region: Region()))
    _ = isKnownUniquelyReferenced(&b)
    _ = b
}
check("FLAT,   boxed, + isKnownUniquelyRef  ") {   // control: top-level generic — does not reproduce
    var b = Box(FlatInner<Payload>())
    _ = isKnownUniquelyReferenced(&b)
    _ = b
}
check("nested, boxed+IKUR, empty box deinit ") {   // mitigation ✗
    var b = BoxEmptyDeinit(NS<Region>.Inner<Payload>(region: Region()))
    _ = isKnownUniquelyReferenced(&b)
    _ = b
}
check("nested, boxed+IKUR, AnyObject? field ") {   // mitigation ✗ ([MEM-SAFE-027]-style)
    var b = Box(NS<Region>.InnerW<Payload>(region: Region()))
    _ = isKnownUniquelyReferenced(&b)
    _ = b
}
check("nested, boxed+IKUR, DRAIN box deinit ", expectDrains: 1) {   // mitigation ✓
    var b = BoxDrain(NS<Region>.InnerD<Payload>(region: Region()))
    _ = isKnownUniquelyReferenced(&b)
    _ = b
}

print(failures == 0
    ? "RESULT: all shapes correct (expected in -Onone; a fixed toolchain would also print this under -O)"
    : "RESULT: \(failures) shape(s) SKIPPED the user deinit (the 6.3.2 -O miscompile reproduces)")

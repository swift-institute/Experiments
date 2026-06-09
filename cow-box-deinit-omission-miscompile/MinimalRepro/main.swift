import Inner3

final class Box<W: ~Copyable> {
    var w: W
    init(_ w: consuming W) { self.w = w }
}

final class Payload {}

typealias Col = NB<NS<Region3>.Inner<Payload>>.Wrap

func check(_ label: String, _ body: () -> Void) {
    let d0 = Counter3.shared.deinits, f0 = Counter3.shared.fieldFrees
    body()
    let d = Counter3.shared.deinits - d0, f = Counter3.shared.fieldFrees - f0
    print("\(label): oracleDeinit=\(d) fieldFree=\(f) \(d == 1 && f == 1 ? "OK" : "** SKIP **")")
}

check("nested, box, no IKUR ") { _ = Box(Col(inner: NS<Region3>.Inner<Payload>(region: Region3()))) }
check("nested, box + IKUR   ") {
    var b = Box(Col(inner: NS<Region3>.Inner<Payload>(region: Region3())))
    _ = isKnownUniquelyReferenced(&b)
    _ = b
}
check("nested, no box, drop ") { _ = Col(inner: NS<Region3>.Inner<Payload>(region: Region3())) }

final class BoxD<W: ~Copyable> {
    var w: W
    init(_ w: consuming W) { self.w = w }
    deinit {}                                  // mitigation probe: force destruction through the user class deinit
}

func more() {
    check("no-Wrap box + IKUR   ") {
        var b = Box(NS<Region3>.Inner<Payload>(region: Region3()))
        _ = isKnownUniquelyReferenced(&b)
        _ = b
    }
    check("BoxD(deinit) + IKUR  ") {
        var b = BoxD(Col(inner: NS<Region3>.Inner<Payload>(region: Region3())))
        _ = isKnownUniquelyReferenced(&b)
        _ = b
    }
}
more()

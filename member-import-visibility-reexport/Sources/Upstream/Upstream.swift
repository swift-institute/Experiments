// A type defined in the upstream module
public struct UpstreamColor: Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

public func makeDefaultColor() -> UpstreamColor {
    UpstreamColor(red: 1.0, green: 0.0, blue: 0.0)
}

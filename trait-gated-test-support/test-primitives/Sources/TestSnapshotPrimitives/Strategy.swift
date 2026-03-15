// Simulates Test.Snapshot.Strategy from swift-test-primitives
public struct SnapshotStrategy<Value, Format> {
    public let transform: (Value) -> Format

    public init(transform: @escaping (Value) -> Format) {
        self.transform = transform
    }

    public static func pullback<NewValue>(
        _ transform: @escaping (NewValue) -> Value
    ) -> SnapshotStrategy<NewValue, Format> where Value == String, Format == String {
        SnapshotStrategy<NewValue, Format> { newValue in
            transform(newValue)
        }
    }
}

extension SnapshotStrategy where Value == String, Format == String {
    public static var lines: Self {
        .init { $0 }
    }
}

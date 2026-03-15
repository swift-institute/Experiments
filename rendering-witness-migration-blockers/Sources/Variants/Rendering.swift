// MARK: - Rendering namespace + minimal types
public enum Rendering {
    public enum Push {}
    public enum Pop {}

    public enum Semantic {
        public enum Block: Sendable, Equatable { case heading(level: Int), paragraph }
        public enum Inline: Sendable, Equatable { case emphasis, strong }
        public enum List: Sendable, Equatable { case ordered, unordered }
    }

    public struct Style: Sendable, Equatable {
        public static let empty = Style()
    }
}

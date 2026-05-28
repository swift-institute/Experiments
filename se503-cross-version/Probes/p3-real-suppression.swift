protocol Box { associatedtype Item: ~Copyable }
struct MoveOnly: ~Copyable {}
struct UserBox: Box { typealias Item = MoveOnly }

typealias NC = ~Copyable
protocol Box { associatedtype Item: NC }
struct MoveOnly: ~Copyable {}
struct UserBox: Box { typealias Item = MoveOnly }

extension File {
    public enum Error: Swift.Error {
        case io(IO<Never>.Error)
        case readOnly
    }
}

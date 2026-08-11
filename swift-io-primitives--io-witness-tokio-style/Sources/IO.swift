//
// Namespace enum for I/O domain. Because the Tokio-style split produces three
// independent witnesses (Reader, Writer, Closer) plus an Error type plus a
// bundle (Duplex), IO is a multi-inhabitant namespace rather than a single
// witness type — genuine namespace per [API-NAME-001a].
//

public enum IO {}

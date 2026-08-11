//
// Socket — namespace for socket-level types. Used in the demo to show
// how a higher-layer error type (`Socket.Error`) wraps `IO.Error`,
// and how `IO.Free.mapError` lifts the error vocabulary across the
// boundary.
//
// In production, Socket would have additional types (Address,
// Connection, etc.). This experiment uses only Socket.Error.
//

public enum Socket {}

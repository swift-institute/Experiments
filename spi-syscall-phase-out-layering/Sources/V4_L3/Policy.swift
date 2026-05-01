import V4_L2

public enum Policy {}

extension Policy {
    public static func close(_ fd: consuming V4_L2.Descriptor) throws(V4_L2.Close.Error) {
        try V4_L2.Close.close(fd)
    }
}

import V6_L2

public enum Policy {}

extension Policy {
    public static func close(_ fd: consuming V6_L2.Descriptor) throws(V6_L2.Close.Error) {
        try V6_L2.Close.close(fd)
    }
}

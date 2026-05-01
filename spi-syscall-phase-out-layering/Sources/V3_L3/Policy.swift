import V3_L2

public enum Policy {}

extension Policy {
    public static func close(_ fd: consuming V3_L2.Descriptor) throws(V3_L2.Close.Error) {
        try V3_L2.Close.close(fd)
    }
}

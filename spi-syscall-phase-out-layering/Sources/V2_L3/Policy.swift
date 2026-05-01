import V2_L2

public enum Policy {}

extension Policy {
    public static func close(_ fd: consuming V2_L2.Descriptor) throws(V2_L2.Close.Error) {
        try V2_L2.Close.close(fd)
    }
}

import V1_L2

public enum Policy {}

extension Policy {
    /// L3-policy wrapper: in production would add EINTR retry, error
    /// normalization, etc. Here it simply forwards to the L2 typed form.
    public static func close(_ fd: consuming V1_L2.Descriptor) throws(V1_L2.Close.Error) {
        try V1_L2.Close.close(fd)
    }
}

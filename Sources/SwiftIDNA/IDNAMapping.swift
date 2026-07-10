public import CSwiftIDNA

@nonexhaustive
@available(SwiftStdlib 5.1, *)
public enum IDNAMapping: Equatable {
    @nonexhaustive
    public enum IDNA2008Status {
        case NV8
        case XV8
        case none
    }

    case valid(IDNA2008Status)
    case mapped(IDNAUnicodeScalarView)
    case deviation(IDNAUnicodeScalarView)
    case disallowed
    case ignored
}

@available(SwiftStdlib 5.1, *)
extension IDNAMapping {
    /// Look up IDNA mapping for a given Unicode scalar
    /// - Parameter scalar: The Unicode scalar to look up
    /// - Returns: The corresponding `IDNAMapping` value
    @inlinable
    public static func `for`(scalar: Unicode.Scalar) -> IDNAMapping {
        /// `unsafelyUnwrapped` because the C function is guaranteed to return a non-nil pointer.
        /// There are also extensive tests in IDNATests for this function.
        let result = unsafe cswift_idna_mapping_lookup(scalar.value).unsafelyUnwrapped.pointee
        let status: IDNAMapping.IDNA2008Status

        switch unsafe result.status {
        case 0:
            status = .NV8
        case 1:
            status = .XV8
        default:
            assert(unsafe result.status == 2)
            status = .none
        }
        let scalars = unsafe IDNAUnicodeScalarView(
            staticPointer: UnsafeBufferPointer(
                start: result.mapped_utf8_bytes,
                count: Int(result.mapped_byte_count)
            )
        )

        switch unsafe result.type {
        case 0:
            return .valid(status)
        case 1:
            return .mapped(scalars)
        case 2:
            return .deviation(scalars)
        case 3:
            return .disallowed
        default:
            assert(unsafe result.type == 4)
            return .ignored
        }
    }
}

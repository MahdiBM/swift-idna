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
        let packedValue = cswift_idna_packed_value(scalar.value)
        let tag = packedValue >> 13
        let payload = UInt32(packedValue & 0x1FFF)

        switch tag {
        case UInt16(CSWIFT_IDNA_TAG_VALID_NONE):
            return .valid(.none)
        case UInt16(CSWIFT_IDNA_TAG_VALID_NV8):
            return .valid(.NV8)
        case UInt16(CSWIFT_IDNA_TAG_VALID_XV8):
            return .valid(.XV8)
        case UInt16(CSWIFT_IDNA_TAG_IGNORED):
            return .ignored
        case UInt16(CSWIFT_IDNA_TAG_DISALLOWED):
            return .disallowed
        case UInt16(CSWIFT_IDNA_TAG_DEVIATION):
            return .deviation(Self.mappedView(sliceIndex: payload))
        default:
            assert(tag == UInt16(CSWIFT_IDNA_TAG_MAPPED))
            return .mapped(Self.mappedView(sliceIndex: payload))
        }
    }

    @inlinable
    static func mappedView(sliceIndex: UInt32) -> IDNAUnicodeScalarView {
        let slice = cswift_idna_mapped_slice(sliceIndex)
        return unsafe IDNAUnicodeScalarView(
            staticPointer: UnsafeBufferPointer(
                start: cswift_idna_mapped_utf8_at(slice >> 8),
                count: Int(slice & 0xFF)
            )
        )
    }
}

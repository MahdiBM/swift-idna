public import CSwiftIDNA

@available(SwiftStdlib 5.1, *)
@usableFromInline
struct IDNAMapping {
    @usableFromInline
    enum Tag: UInt16 {
        case validNone = 0
        case validNV8 = 1
        case validXV8 = 2
        case ignored = 3
        case disallowed = 4
        case deviation = 5
        case mapped = 6
    }

    @usableFromInline
    let tag: Tag
    /// Only valid for `mapped` and `deviation` tags. Otherwise an invalid value.
    /// We don't guard access to it with e.g. an assert because again
    /// the tests are exhaustive and they'd fail anyway.
    @usableFromInline
    let mappedScalars: IDNAUnicodeScalarView

    @inlinable
    init(tag: Tag, mappedScalars: IDNAUnicodeScalarView) {
        self.tag = tag
        self.mappedScalars = mappedScalars
    }
}

@available(SwiftStdlib 5.1, *)
extension IDNAMapping {
    /// Look up IDNA mapping for a given Unicode scalar
    /// - Parameter scalar: The Unicode scalar to look up
    /// - Returns: The corresponding `IDNAMapping` value
    @inlinable
    static func `for`(scalar: Unicode.Scalar) -> IDNAMapping {
        let packedValue = cswift_idna_packed_value(scalar.value)
        /// This is exhaustively tested, so `unsafelyUnwrapped` is safe.
        let tag = unsafe Tag(rawValue: packedValue >> 13).unsafelyUnwrapped
        let hasPayload = tag == .mapped || tag == .deviation
        let sliceIndex = hasPayload ? UInt32(packedValue & 0x1FFF) : 0
        let slice = cswift_idna_mapped_slice(sliceIndex)
        let payloadPtr = unsafe cswift_idna_mapped_utf8_at(slice >> 8)
        let payloadCount = Int(slice & 0xFF)
        let payload = unsafe IDNAUnicodeScalarView(
            staticPointer: UnsafeBufferPointer(
                start: payloadPtr,
                count: payloadCount
            )
        )
        return IDNAMapping(tag: tag, mappedScalars: payload)
    }
}

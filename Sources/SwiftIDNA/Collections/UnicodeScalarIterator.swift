/// An iterator that decodes Unicode scalars from the same span of UTF-8 bytes.
@available(SwiftStdlib 5.1, *)
@usableFromInline
struct UnicodeScalarIterator {
    @usableFromInline
    var currentCodeUnitOffset: Int

    @inlinable
    init() {
        self.currentCodeUnitOffset = 0
    }

    /// Decodes and returns the next Unicode scalar and the range of utf8 bytes it was decoded from.
    ///
    /// Only pass the span to any single instance of this iterator.
    /// As always, tests will fail if this is not the case.
    @inlinable
    mutating func nextWithRange(
        in bytes: Span<UInt8>
    ) -> (codePoint: Unicode.Scalar, range: Range<Int>)? {
        guard self.currentCodeUnitOffset < bytes.count else { return nil }

        let firstByte = unsafe bytes[unchecked: self.currentCodeUnitOffset]

        if firstByte.isASCII {
            let range = unsafe Range<Int>(
                uncheckedBounds: (self.currentCodeUnitOffset, self.currentCodeUnitOffset &+ 1)
            )
            self.currentCodeUnitOffset = range.upperBound
            return (Unicode.Scalar(firstByte), range)
        }

        /// Unicode scalar byte-length == count of leading ones in the first byte
        let scalarUTF8Length = (~firstByte).leadingZeroBitCount

        let lowerBound = self.currentCodeUnitOffset
        self.currentCodeUnitOffset &+= scalarUTF8Length

        var bits: UInt32 = 0
        var idx = 0
        while idx < scalarUTF8Length {
            defer { idx &+= 1 }
            let byteIdx = lowerBound &+ idx
            let byte = unsafe bytes[unchecked: byteIdx]
            bits |= UInt32(byte &+ 1) &<< (idx &<< 3)
        }
        let scalar = UnicodeScalarIterator.decode(bits, utf8Count: scalarUTF8Length)

        let range = unsafe Range<Int>(
            uncheckedBounds: (lowerBound, self.currentCodeUnitOffset)
        )
        return (scalar, range)
    }

    /// Decodes and returns the next Unicode scalar.
    ///
    /// Only pass the span to any single instance of this iterator.
    /// As always, tests will fail if this is not the case.
    @inlinable
    mutating func next(in bytes: Span<UInt8>) -> Unicode.Scalar? {
        self.nextWithRange(in: bytes)?.codePoint
    }

    @inline(__always)
    @inlinable
    static func decode(_ bits: UInt32, utf8Count: Int) -> Unicode.Scalar {
        switch utf8Count {
        case 1:
            return unsafe Unicode.Scalar(bits &- 0x01).unsafelyUnwrapped
        case 2:
            let bits = bits &- 0x0101
            var value = (bits & 0b0_______________________11_1111__0000_0000) &>> 8
            value |= (bits & 0b0________________________________0001_1111) &<< 6
            return unsafe Unicode.Scalar(value).unsafelyUnwrapped
        case 3:
            let bits = bits &- 0x010101
            var value = (bits & 0b0____________11_1111__0000_0000__0000_0000) &>> 16
            value |= (bits & 0b0_______________________11_1111__0000_0000) &>> 2
            value |= (bits & 0b0________________________________0000_1111) &<< 12
            return unsafe Unicode.Scalar(value).unsafelyUnwrapped
        default:
            let bits = bits &- 0x0101_0101
            var value = (bits & 0b0_11_1111__0000_0000__0000_0000__0000_0000) &>> 24
            value |= (bits & 0b0____________11_1111__0000_0000__0000_0000) &>> 10
            value |= (bits & 0b0_______________________11_1111__0000_0000) &<< 4
            value |= (bits & 0b0________________________________0000_0111) &<< 18
            return unsafe Unicode.Scalar(value).unsafelyUnwrapped
        }
    }
}

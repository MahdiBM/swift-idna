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
        let scalar = UnicodeScalarIterator._decode(bits, utf8Count: scalarUTF8Length)

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

    @inlinable
    static func _decode(_ bits: UInt32, utf8Count: Int) -> Unicode.Scalar {
        let bitsSubtract: UInt32 = 0x0101_0101 &>> ((4 &- utf8Count) &* 8)
        let bits = bits &- bitsSubtract

        let _m1: UInt32 = 0b0_____________________________0111_1110
        let m1: UInt32 = _m1 &>> utf8Count
        let m2: UInt32 = 0b0________________11_1111_0000_0000_0000
        let m3: UInt32 = 0b0___________11_1111_0000_0000_0000_0000
        let m4: UInt32 = 0b0_11_1111_0000_0000_0000_0000_0000_0000

        let m2Bits = bits &<< 4

        /// y = 6x - 6; x = 1 -> y = 0; x = 2 -> y = 6; x = 3 -> y = 12; x = 4 -> y = 18
        let s1 = 6 &* utf8Count &- 6
        /// y = -6x + 24; x = 1 -> y = 18; x = 2 -> y = 12; x = 3 -> y = 6; x = 4 -> y = 0
        let s2 = -6 &* utf8Count &+ 24
        /// y = -6x + 34; x = 1 -> y = 28; x = 2 -> y = 22; x = 3 -> y = 16; x = 4 -> y = 10
        let s3 = -6 &* utf8Count &+ 34
        /// y = -6x + 48; x = 1 -> y = 42; x = 2 -> y = 36; x = 3 -> y = 30; x = 4 -> y = 24
        let s4 = -6 &* utf8Count &+ 48

        let r1 = (bits & m1) &<< s1
        let r2 = (m2Bits & m2) &>> s2
        let r3 = (bits & m3) &>> s3
        let r4 = (bits & m4) &>> s4

        let value = r1 | r2 | r3 | r4
        let scalar = Unicode.Scalar(value)
        return unsafe scalar.unsafelyUnwrapped
    }
}

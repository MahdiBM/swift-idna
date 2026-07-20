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
    /// Always tries to decode regardless if the uncode offset is valid.
    ///
    /// Only pass the same span to any single instance of this iterator.
    /// As always, tests will fail if this is not the case.
    @inline(__always)
    @inlinable
    mutating func uncheckedNext(in bytes: Span<UInt8>) -> Unicode.Scalar {
        let firstByte = unsafe bytes[unchecked: self.currentCodeUnitOffset]

        /// Count of leading ones in the first byte: 0 for ASCII, else the scalar's byte-length
        let leadingOnes = Swift.min(4, (~firstByte).leadingZeroBitCount)
        let scalarUTF8Length = Swift.max(1, leadingOnes)

        let lowerBound = self.currentCodeUnitOffset
        self.currentCodeUnitOffset &+= scalarUTF8Length

        var value = UInt32(firstByte & (0b0111_1111 &>> leadingOnes))

        let iterRange = unsafe Range<Int>(
            uncheckedBounds: (lowerBound &+ 1, self.currentCodeUnitOffset)
        )
        for byteIdx in iterRange {
            let byte = unsafe bytes[unchecked: byteIdx]
            value = (value &<< 6) | UInt32(byte & 0b0011_1111)
        }
        let scalar = unsafe Unicode.Scalar(value).unsafelyUnwrapped

        return scalar
    }

    /// Decodes and returns the next Unicode scalar.
    ///
    /// Only pass the same span to any single instance of this iterator.
    /// As always, tests will fail if this is not the case.
    @inline(__always)
    @inlinable
    mutating func next(in bytes: Span<UInt8>) -> Unicode.Scalar? {
        guard self.currentCodeUnitOffset < bytes.count else { return nil }
        return self.uncheckedNext(in: bytes)
    }

    /// Decodes and returns the next Unicode scalar and the range of utf8 bytes it was decoded from;
    /// without checking if the offset is valid.
    ///
    /// Only pass the same span to any single instance of this iterator.
    /// As always, tests will fail if this is not the case.
    @inline(__always)
    @inlinable
    mutating func uncheckedNextWithRange(in bytes: Span<UInt8>) -> (Unicode.Scalar, Range<Int>)? {
        let lowerBound = self.currentCodeUnitOffset
        let next = self.uncheckedNext(in: bytes)
        let range = unsafe Range<Int>(
            uncheckedBounds: (lowerBound, self.currentCodeUnitOffset)
        )
        return (next, range)
    }

    /// Decodes and returns the next Unicode scalar and the range of utf8 bytes it was decoded from.
    ///
    /// Only pass the same span to any single instance of this iterator.
    /// As always, tests will fail if this is not the case.
    @inline(__always)
    @inlinable
    mutating func nextWithRange(in bytes: Span<UInt8>) -> (Unicode.Scalar, Range<Int>)? {
        guard self.currentCodeUnitOffset < bytes.count else { return nil }
        let lowerBound = self.currentCodeUnitOffset
        let next = self.uncheckedNext(in: bytes)
        let range = unsafe Range<Int>(
            uncheckedBounds: (lowerBound, self.currentCodeUnitOffset)
        )
        return (next, range)
    }
}

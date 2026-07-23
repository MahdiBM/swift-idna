/// Decodes UTF-8 into Unicode scalars a fixed-size window at a time.
///
/// Only pass the same span to any single decode/walk sequence; tests will fail otherwise.
@available(SwiftStdlib 5.1, *)
@usableFromInline
struct SIMDUnicodeScalarDecoder: ~Copyable, ~Escapable {
    /// Bytes decoded per window. Matches the natural byte-vector width.
    @usableFromInline
    static var windowSize: Int { 16 }
    /// Extra bytes for speculative decoding.
    @usableFromInline
    static var tempBytesSize: Int { Self.windowSize &+ 3 }

    /// Temp storage for faster speculative decoding.
    /// Initialized to zeros via `withTemporaryDecoder(_:)`.
    /// Of length `Self.tempBytesSize`.
    @usableFromInline
    var tempBytes: MutableSpan<UInt8>
    /// Decoded UTF-8 byte length (1...4) per window position.
    /// Of length `Self.windowSize`.
    @usableFromInline
    var scalarUTF8Lengths: MutableSpan<UInt8>
    /// Decoded scalar value per window position.
    /// Of length `Self.windowSize`.
    @usableFromInline
    var uncheckedScalarValues: MutableSpan<UInt32>

    @inlinable
    @_lifetime(copy tempBytes, copy scalarUTF8Lengths, copy uncheckedScalarValues)
    init(
        tempBytes: consuming MutableSpan<UInt8>,
        scalarUTF8Lengths: consuming MutableSpan<UInt8>,
        uncheckedScalarValues: consuming MutableSpan<UInt32>
    ) {
        self.tempBytes = tempBytes
        self.scalarUTF8Lengths = scalarUTF8Lengths
        self.uncheckedScalarValues = uncheckedScalarValues
    }

    /// Runs `body` with a decoder backed by temporary stack allocations.
    @inlinable
    @inline(__always)
    static func withTemporaryDecoder<R: ~Copyable, Failure: Error>(
        _ body: (inout SIMDUnicodeScalarDecoder) throws(Failure) -> R
    ) throws(Failure) -> R {
        try withUnsafeTemporaryAllocation(
            of: UInt8.self,
            capacity: Self.tempBytesSize
        ) { tempBytes throws(Failure) -> R in
            try withUnsafeTemporaryAllocation(
                of: UInt8.self,
                capacity: Self.windowSize
            ) { scalarUTF8Lengths throws(Failure) -> R in
                try withUnsafeTemporaryAllocation(
                    of: UInt32.self,
                    capacity: Self.windowSize
                ) { uncheckedScalarValues throws(Failure) -> R in
                    unsafe tempBytes.initialize(repeating: 0)
                    var decoder = unsafe SIMDUnicodeScalarDecoder(
                        tempBytes: tempBytes.mutableSpan,
                        scalarUTF8Lengths: scalarUTF8Lengths.mutableSpan,
                        uncheckedScalarValues: uncheckedScalarValues.mutableSpan
                    )
                    return try body(&decoder)
                }
            }
        }
    }

    @inlinable
    @inline(__always)
    mutating func _decodeWindow(of encodedBytes: Span<UInt8>) {
        assert(encodedBytes.count >= 0 && encodedBytes.count <= Self.tempBytesSize)

        /// Write `encodedBytes` into `tempBytes`.
        /// `tempBytes` is initialized-memory by above code (`tempBytes.initialize(repeating: 0)`), so it's valid anyway.
        /// The pad bytes are not important.
        tempBytes.withUnsafeMutableBufferPointer { temp in
            encodedBytes.withUnsafeBufferPointer { encoded in
                let rawTemp = UnsafeMutableRawBufferPointer(temp)
                let rawEncodedBytes = UnsafeRawBufferPointer(encoded)
                unsafe rawTemp.copyMemory(from: rawEncodedBytes)
            }
        }

        /// This loop is auto-vectorized by LLVM.
        for idx in 0..<Self.windowSize {
            let leadByte = unsafe tempBytes[unchecked: idx]
            /// We have 3 extra bytes for speculative decoding so we won't run out of bytes.
            /// See `tempBytes` doc comments.
            let continuationByte1 = unsafe tempBytes[unchecked: idx &+ 1]
            let continuationByte2 = unsafe tempBytes[unchecked: idx &+ 2]
            let continuationByte3 = unsafe tempBytes[unchecked: idx &+ 3]

            let (scalarUTF8Length, uncheckedScalar) = UnicodeScalarIterator.decodeScalar(
                leadByte: leadByte,
                continuationByte1: continuationByte1,
                continuationByte2: continuationByte2,
                continuationByte3: continuationByte3
            )
            unsafe self.scalarUTF8Lengths[unchecked: idx] = UInt8(
                truncatingIfNeeded: scalarUTF8Length
            )
            unsafe self.uncheckedScalarValues[unchecked: idx] = uncheckedScalar
        }
    }

    /// Returns window end index.
    @inlinable
    @inline(__always)
    mutating func decodeNextWindow(
        of bytes: Span<UInt8>,
        startIdx: Int
    ) -> Int {
        let totalCount = bytes.count
        let lowerBound = startIdx
        let upperBound = min(lowerBound &+ Self.tempBytesSize, totalCount)
        let windowEnd = min(lowerBound &+ Self.windowSize, totalCount)
        let decodeRange = unsafe Range<Int>(
            uncheckedBounds: (lowerBound, upperBound)
        )
        let span = unsafe bytes.extracting(unchecked: decodeRange)
        self._decodeWindow(of: span)
        return windowEnd
    }
}

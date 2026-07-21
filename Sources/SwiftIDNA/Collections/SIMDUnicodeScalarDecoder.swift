/// Decodes UTF-8 into Unicode scalars a fixed-size window at a time.
///
/// Only pass the same span to any single decode/walk sequence; tests will fail otherwise.
@available(SwiftStdlib 5.1, *)
@usableFromInline
@safe
struct SIMDUnicodeScalarDecoder: ~Copyable, ~Escapable {
    /// Bytes decoded per window. Matches the natural byte-vector width.
    @usableFromInline
    static var windowSize: Int { 16 }

    /// The current window's bytes plus 3 additional bytes for speculative decoding.
    /// Of length `Self.windowSize &+ 3`.
    @usableFromInline
    var paddedWindowBytes: MutableSpan<UInt8>
    /// Decoded UTF-8 byte length (1...4) per window position.
    /// Of length `Self.windowSize`.
    @usableFromInline
    var scalarUTF8Lengths: MutableSpan<UInt8>
    /// Decoded scalar value per window position.
    /// Of length `Self.windowSize`.
    @usableFromInline
    var scalarValues: MutableSpan<UInt32>

    @inlinable
    @_lifetime(copy paddedWindowBytes, copy scalarUTF8Lengths, copy scalarValues)
    init(
        paddedWindowBytes: consuming MutableSpan<UInt8>,
        scalarUTF8Lengths: consuming MutableSpan<UInt8>,
        scalarValues: consuming MutableSpan<UInt32>
    ) {
        self.paddedWindowBytes = paddedWindowBytes
        self.scalarUTF8Lengths = scalarUTF8Lengths
        self.scalarValues = scalarValues
    }

    /// Runs `body` with a decoder backed by temporary stack allocations.
    @inlinable
    @inline(__always)
    static func withDecoder<R: ~Copyable, Failure: Error>(
        _ body: (inout SIMDUnicodeScalarDecoder) throws(Failure) -> R
    ) throws(Failure) -> R {
        try withUnsafeTemporaryAllocation(
            of: UInt8.self,
            capacity: Self.windowSize &+ 3
        ) { paddedWindowBytes throws(Failure) -> R in
            try withUnsafeTemporaryAllocation(
                of: UInt8.self,
                capacity: Self.windowSize
            ) { scalarUTF8Lengths throws(Failure) -> R in
                try withUnsafeTemporaryAllocation(
                    of: UInt32.self,
                    capacity: Self.windowSize
                ) { scalarValues throws(Failure) -> R in
                    var decoder = unsafe SIMDUnicodeScalarDecoder(
                        paddedWindowBytes: paddedWindowBytes.mutableSpan,
                        scalarUTF8Lengths: scalarUTF8Lengths.mutableSpan,
                        scalarValues: scalarValues.mutableSpan
                    )
                    return try body(&decoder)
                }
            }
        }
    }

    @inlinable
    mutating func decodeWindow(of bytes: Span<UInt8>, range: Range<Int>) {
        let copyCount = Swift.min(Self.windowSize &+ 3, range.count)
        var i = 0
        while i < copyCount {
            unsafe self.paddedWindowBytes[unchecked: i] = bytes[unchecked: range.lowerBound &+ i]
            i &+= 1
        }
        while i < (Self.windowSize &+ 3) {
            unsafe self.paddedWindowBytes[unchecked: i] = 0
            i &+= 1
        }

        /// This loop is auto-vectorized by LLVM.
        for position in 0..<Self.windowSize {
            let leadByte = unsafe self.paddedWindowBytes[unchecked: position]
            /// We have 3 extra bytes for speculative decoding so we won't run out of bytes.
            /// See `paddedWindowBytes` doc comments.
            let continuationByte1 = unsafe self.paddedWindowBytes[unchecked: position &+ 1]
            let continuationByte2 = unsafe self.paddedWindowBytes[unchecked: position &+ 2]
            let continuationByte3 = unsafe self.paddedWindowBytes[unchecked: position &+ 3]

            let (scalarUTF8Length, value) = UnicodeScalarIterator.decodeScalar(
                leadByte: leadByte,
                continuationByte1: continuationByte1,
                continuationByte2: continuationByte2,
                continuationByte3: continuationByte3
            )
            unsafe self.scalarUTF8Lengths[unchecked: position] = UInt8(
                truncatingIfNeeded: scalarUTF8Length
            )
            unsafe self.scalarValues[unchecked: position] = value
        }
    }
}

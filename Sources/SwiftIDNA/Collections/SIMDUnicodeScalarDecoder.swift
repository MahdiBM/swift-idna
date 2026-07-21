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
    let paddedWindowBytes: UnsafeMutableBufferPointer<UInt8>
    /// Decoded UTF-8 byte length (1...4) per window position.
    /// Of length `Self.windowSize`.
    @usableFromInline
    let scalarByteLengths: UnsafeMutableBufferPointer<UInt8>
    /// Decoded scalar value per window position.
    /// Of length `Self.windowSize`.
    @usableFromInline
    let scalarValues: UnsafeMutableBufferPointer<UInt32>

    @inlinable
    @_lifetime(borrow scalarValues)
    init(
        paddedWindowBytes: UnsafeMutableBufferPointer<UInt8>,
        scalarByteLengths: UnsafeMutableBufferPointer<UInt8>,
        scalarValues: UnsafeMutableBufferPointer<UInt32>
    ) {
        unsafe self.paddedWindowBytes = paddedWindowBytes
        unsafe self.scalarByteLengths = scalarByteLengths
        unsafe self.scalarValues = scalarValues
    }

    /// Runs `body` with a decoder backed by temporary stack allocations.
    @inlinable
    @inline(__always)
    static func withDecoder<R: ~Copyable, Failure: Error>(
        _ body: (borrowing SIMDUnicodeScalarDecoder) throws(Failure) -> R
    ) throws(Failure) -> R {
        try withUnsafeTemporaryAllocation(
            of: UInt8.self,
            capacity: Self.windowSize &+ 3
        ) { paddedWindowBytes throws(Failure) -> R in
            try withUnsafeTemporaryAllocation(
                of: UInt8.self,
                capacity: Self.windowSize
            ) { scalarByteLengths throws(Failure) -> R in
                try withUnsafeTemporaryAllocation(
                    of: UInt32.self,
                    capacity: Self.windowSize
                ) { scalarValues throws(Failure) -> R in
                    let decoder = unsafe SIMDUnicodeScalarDecoder(
                        paddedWindowBytes: paddedWindowBytes,
                        scalarByteLengths: scalarByteLengths,
                        scalarValues: scalarValues
                    )
                    return try body(decoder)
                }
            }
        }
    }

    /// Decodes the window starting at `start` of `bytes`.
    @inlinable
    func decodeWindow(of bytes: Span<UInt8>, start: Int, inputCount: Int) {
        let copyCount = Swift.min(Self.windowSize &+ 3, inputCount &- start)
        var i = 0
        while i < copyCount {
            unsafe self.paddedWindowBytes[i] = bytes[unchecked: start &+ i]
            i &+= 1
        }
        while i < (Self.windowSize &+ 3) {
            unsafe self.paddedWindowBytes[i] = 0
            i &+= 1
        }

        /// This loop is auto-vectorized by LLVM.
        for position in 0..<Self.windowSize {
            let leadByte = unsafe self.paddedWindowBytes[position]
            let continuationByte1 = unsafe self.paddedWindowBytes[position &+ 1]
            let continuationByte2 = unsafe self.paddedWindowBytes[position &+ 2]
            let continuationByte3 = unsafe self.paddedWindowBytes[position &+ 3]

            let (scalarUTF8Length, value) = UnicodeScalarIterator.decodeScalar(
                leadByte: leadByte,
                continuationByte1: continuationByte1,
                continuationByte2: continuationByte2,
                continuationByte3: continuationByte3
            )
            unsafe self.scalarByteLengths[position] = UInt8(truncatingIfNeeded: scalarUTF8Length)
            unsafe self.scalarValues[position] = value
        }
    }
}

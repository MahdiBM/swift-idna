/// The implementations below in this file, do not pass the un-sanitized user-input `span` to
/// any functions outside this file.
/// The other functions outside this file can assume they are operating on UTF8-only bytes.
/// Still, the punycode decode needs to take into account the possibility of decoding non-UTF8.
@available(SwiftStdlib 5.1, *)
extension IDNA {
    /// `ToASCII` IDNA implementation.
    /// https://www.unicode.org/reports/tr46/#ToASCII
    @inlinable
    func _toASCII(span: Span<UInt8>) throws(CollectedMappingErrors) -> ConversionResult {
        switch IDNA.performByteCheck(on: span) {
        case .containsOnlyIDNANoOpCharacters:
            return .noChangesNeeded
        case .onlyNeedsLowercasingOfUppercasedASCIILetters:
            /// At this point we know the bytes are ASCII, so we know they are valid UTF8.
            let string = convertToLowercasedASCII(_uncheckedAssumingValidUTF8: span)
            return .string(string)
        case .mightChangeAfterIDNAConversion:
            break
        }

        var errors = MappingErrors(domainNameSpan: span)

        // 1.
        let result = TinyBuffer.withInlineAllocation { convertedBytes -> ConversionResult in
            TinyBuffer.withInlineAllocation { processedBytes -> ConversionResult in

                /// Main `Processing` IDNA implementation.
                /// https://www.unicode.org/reports/tr46/#Processing
                /// 1. Map
                self.mapToIDNAMappings_Scalar(
                    span: span,
                    into: &convertedBytes,
                    errors: &errors
                )

                /// Notice no `span` (direct user input) is passed to this function.
                self._mainProcessing(
                    reuseBuffer: &convertedBytes,
                    output: &processedBytes,
                    errors: &errors
                )

                /// Notice no `span` (direct user input) is passed to this function.
                return self._toASCII(
                    convertedBytes: &convertedBytes,
                    processedBytes: &processedBytes,
                    errors: &errors
                )
            }
        }

        if let errors = errors.collect() {
            throw errors
        }

        return result
    }

    /// `ToUnicode` IDNA implementation.
    /// https://www.unicode.org/reports/tr46/#ToUnicode
    @inlinable
    func _toUnicode(span: Span<UInt8>) throws(CollectedMappingErrors) -> ConversionResult {
        switch IDNA.performByteCheck(on: span) {
        case .containsOnlyIDNANoOpCharacters:
            if !span.containsIDNADomainNameMarkerLabelPrefix {
                return .noChangesNeeded
            }
        case .onlyNeedsLowercasingOfUppercasedASCIILetters:
            if !span.containsIDNADomainNameMarkerLabelPrefix {
                /// At this point we know the bytes are ASCII, so we know they are valid UTF8.
                let string = convertToLowercasedASCII(_uncheckedAssumingValidUTF8: span)
                return .string(string)
            }
        case .mightChangeAfterIDNAConversion:
            break
        }

        var errors = MappingErrors(domainNameSpan: span)

        // 1.
        let result = TinyBuffer.withInlineAllocation { reuseBuffer -> ConversionResult in
            TinyBuffer.withInlineAllocation { utf8Bytes -> ConversionResult in

                /// Main `Processing` IDNA implementation.
                /// https://www.unicode.org/reports/tr46/#Processing
                /// 1. Map
                self.mapToIDNAMappings_SIMD(
                    span: span,
                    into: &reuseBuffer,
                    errors: &errors
                )

                self._mainProcessing(
                    reuseBuffer: &reuseBuffer,
                    output: &utf8Bytes,
                    errors: &errors
                )

                return utf8Bytes.takeAsConversionResult()
            }
        }

        // 2.
        if let errors = errors.collect() {
            throw errors
        }

        return result
    }

    @inlinable
    @inline(__always)
    func mapToIDNAMappings_Scalar(
        span: Span<UInt8>,
        into newBytes: inout TinyBuffer,
        errors: inout MappingErrors
    ) {
        var requiredCapacity = 0

        var unicodeScalarsIterator = UnicodeScalarIterator()

        while let (uncheckedScalar, range) = unicodeScalarsIterator.nextWithRange(in: span) {
            guard let scalar = Unicode.Scalar(uncheckedScalar) else {
                errors.append(
                    .labelContainsInvalidUnicode(
                        uncheckedScalar,
                        label: String(span: span)
                    )
                )
                continue
            }

            let mapping = IDNAMapping.for(scalar: scalar)
            switch mapping.tag {
            case .validNone, .validNV8, .validXV8, .disallowed, .deviation:
                requiredCapacity &+= range.count
            case .mapped:
                requiredCapacity &+= mapping.mappedScalars.utf8BytesSpan.count
            case .ignored:
                ()
            }
        }

        /// I'm expecting this to be empty at this point, nothing special.
        /// Tests will immediately crash if this is not the case.
        assert(newBytes.isEmpty)

        unicodeScalarsIterator = UnicodeScalarIterator()

        /// Reserve the exact required capacity up front so we can skip further capacity checks
        /// because we're guaranteed to have enough capacity.
        newBytes.append(extraRequiredCapacity: requiredCapacity) { output in
            while let (uncheckedScalar, range) = unicodeScalarsIterator.nextWithRange(in: span) {
                guard let scalar = Unicode.Scalar(uncheckedScalar) else {
                    /// Error already appended
                    continue
                }

                let mapping = IDNAMapping.for(scalar: scalar)
                switch mapping.tag {
                case .validNone, .validNV8, .validXV8, .disallowed, .deviation:
                    let scalarBytesSpan = unsafe span.extracting(unchecked: range)
                    output.swift_idna_append(copying: scalarBytesSpan)
                case .mapped:
                    output.swift_idna_append(copying: mapping.mappedScalars.utf8BytesSpan)
                case .ignored:
                    ()
                }
            }
        }
    }

    @inlinable
    @inline(__always)
    func mapToIDNAMappings_SIMD(
        span: Span<UInt8>,
        into newBytes: inout TinyBuffer,
        errors: inout MappingErrors
    ) {
        let count = span.count

        assert(newBytes.isEmpty)

        SIMDUnicodeScalarDecoder.withTemporaryDecoder { decoder in
            /// Process windows of size `SIMDUnicodeScalarDecoder.windowSize`, one by one.
            var startIdx = 0
            while startIdx < count {
                let windowEnd = decoder.decodeNextWindow(of: span, startIdx: startIdx)

                var requiredCapacity = 0
                var i = startIdx
                while i < windowEnd {
                    let idx = i &- startIdx
                    let scalarUTF8Length = Int(unsafe decoder.scalarUTF8Lengths[unchecked: idx])
                    let uncheckedScalar = unsafe decoder.uncheckedScalarValues[unchecked: idx]

                    guard let scalar = Unicode.Scalar(uncheckedScalar) else {
                        errors.append(
                            .labelContainsInvalidUnicode(
                                uncheckedScalar,
                                label: String(span: span)
                            )
                        )
                        i &+= scalarUTF8Length
                        continue
                    }

                    let mapping = IDNAMapping.for(scalar: scalar)
                    switch mapping.tag {
                    case .validNone, .validNV8, .validXV8, .disallowed, .deviation:
                        requiredCapacity &+= scalarUTF8Length
                    case .mapped:
                        requiredCapacity &+= mapping.mappedScalars.utf8BytesSpan.count
                    case .ignored:
                        ()
                    }

                    i &+= scalarUTF8Length
                }

                let approxRequiredCapacity = IDNA.approximateCapacity(
                    totalCount: count,
                    originalFormCount: windowEnd,
                    postProcessCount: newBytes.count &+ requiredCapacity
                )
                assert(approxRequiredCapacity >= requiredCapacity)
                let approxToReserve = approxRequiredCapacity &- newBytes.count
                let extraToReserve =
                    requiredCapacity <= TinyBuffer.InlineElements.maximumCapacity
                    ? requiredCapacity : approxToReserve

                i = startIdx
                newBytes.append(extraRequiredCapacity: extraToReserve) { output in
                    while i < windowEnd {
                        let idx = i &- startIdx
                        let scalarUTF8Length = Int(unsafe decoder.scalarUTF8Lengths[unchecked: idx])
                        let uncheckedScalar = unsafe decoder.uncheckedScalarValues[unchecked: idx]
                        guard let scalar = Unicode.Scalar(uncheckedScalar) else {
                            /// Error already appended
                            i &+= scalarUTF8Length
                            return
                        }

                        let mapping = IDNAMapping.for(scalar: scalar)
                        switch mapping.tag {
                        case .validNone, .validNV8, .validXV8, .disallowed, .deviation:
                            let scalarRange = unsafe Range<Int>(
                                uncheckedBounds: (i, i &+ scalarUTF8Length)
                            )
                            let scalarBytesSpan = unsafe span.extracting(unchecked: scalarRange)
                            output.swift_idna_append(copying: scalarBytesSpan)
                        case .mapped:
                            output.swift_idna_append(copying: mapping.mappedScalars.utf8BytesSpan)
                        case .ignored:
                            ()
                        }

                        i &+= scalarUTF8Length
                    }
                }
                startIdx = i
            }
        }
    }

    /// Generic over the Integer type, so we can test via Int8 in tests to easily check boundaries.
    ///
    /// ~= (totalCount * postProcessCount) / originalFormCount
    @inlinable
    @_specialize(where IntegerType == Int)
    package static func approximateCapacity<IntegerType: BinaryInteger & FixedWidthInteger>(
        totalCount: IntegerType,
        originalFormCount: IntegerType,
        postProcessCount: IntegerType
    ) -> IntegerType {
        assert(totalCount >= originalFormCount && originalFormCount != .zero)

        let originalFormCountLeadingZeroBitCount = originalFormCount.leadingZeroBitCount
        let totalCountLeadingZeroBitCount = totalCount.leadingZeroBitCount
        let diff = originalFormCountLeadingZeroBitCount &- totalCountLeadingZeroBitCount

        let _approx = postProcessCount.multipliedReportingOverflow(by: 1 &<< diff)
        let approx = _approx.overflow ? .max : _approx.partialValue

        let _doubled = postProcessCount.multipliedReportingOverflow(by: 2)
        let doubled = _doubled.overflow ? .max : _doubled.partialValue

        let isEqual = totalCount == originalFormCount
        let isSameOrderOfMagnitude =
            totalCountLeadingZeroBitCount == originalFormCountLeadingZeroBitCount

        let finalCount = isEqual ? postProcessCount : (isSameOrderOfMagnitude ? doubled : approx)

        return finalCount
    }

    /// Converts the given span to lowercase ASCII.
    @usableFromInline
    func convertToLowercasedASCII(_uncheckedAssumingValidUTF8 span: Span<UInt8>) -> String {
        let count = span.count
        return unsafe String(unsafeUninitializedCapacity_Compatibility: count) { buffer in
            var idx = 0
            while idx < count {
                unsafe buffer[idx] = span[unchecked: idx].toLowercasedASCIILetter()
                idx &+= 1
            }
            return count
        }
    }
}

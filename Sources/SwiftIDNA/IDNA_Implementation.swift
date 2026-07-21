@available(SwiftStdlib 5.1, *)
extension IDNA {
    /// `ToASCII` IDNA implementation.
    /// https://www.unicode.org/reports/tr46/#ToASCII
    @inlinable
    func _toASCII(
        _uncheckedAssumingValidUTF8 span: Span<UInt8>
    ) throws(CollectedMappingErrors) -> ConversionResult {
        switch IDNA.performByteCheck(on: span) {
        case .containsOnlyIDNANoOpCharacters:
            return .noChangesNeeded
        case .onlyNeedsLowercasingOfUppercasedASCIILetters:
            let string = convertToLowercasedASCII(_uncheckedAssumingValidUTF8: span)
            return .string(string)
        case .mightChangeAfterIDNAConversion:
            break
        }

        var errors = MappingErrors(domainNameSpan: span)

        // 1.
        let result = TinyBuffer.withInlineAllocation { convertedBytes -> ConversionResult in
            TinyBuffer.withInlineAllocation { processedBytes -> ConversionResult in

                self.mainProcessing(
                    _uncheckedAssumingValidUTF8: span,
                    reuseBuffer: &convertedBytes,
                    output: &processedBytes,
                    errors: &errors,
                    /// The SIMD decoder regresses this larger toASCII path; use the per-scalar one.
                    useSIMDDecoder: false
                )

                // 2., 3.
                let outputReuseCapacityHint = convertedBytes.count
                convertedBytes.removeAll(keepingCapacity: true)

                return TinyBuffer.withInlineAllocation(preferredCapacity: outputReuseCapacityHint) {
                    (outputBufferForReuse) -> ConversionResult in

                    processedBytes.withSpan { processedBytesSpan in
                        var baseDecodedUnicodeScalars = DecodedUnicodeScalars(
                            utf8Bytes: processedBytesSpan
                        )
                        var decodedUnicodeScalars = DecodedUnicodeScalars.Subsequence(
                            base: &baseDecodedUnicodeScalars
                        )

                        var startIndex = 0

                        for idx in processedBytesSpan.indices {
                            /// If this is not a label separator, then continue
                            var endIndex = idx
                            let countBehindX = idx
                            switch countBehindX {
                            case 0, 1, 2:
                                guard processedBytesSpan[idx] == .asciiDot else {
                                    continue
                                }
                            case 3...:
                                let third = processedBytesSpan[idx]
                                let second = unsafe processedBytesSpan[unchecked: idx &- 1]
                                let first = unsafe processedBytesSpan[unchecked: idx &- 2]
                                if !Span<UInt8>.isIDNALabelSeparator(first, second, third),
                                    third != .asciiDot
                                {
                                    continue
                                }
                                if third != .asciiDot {
                                    /// Set last index to bytes before e.g. `U+3002 ( 。 ) IDEOGRAPHIC FULL STOP`
                                    /// which is 3 bytes, not 1, like `U+002E ( . ) FULL STOP` (asciiDot) is.
                                    endIndex = idx &- 2
                                }
                            default:
                                fatalError("Invalid count behind X: \(countBehindX)")
                            }

                            appendLabel(
                                domainNameSpan: processedBytesSpan,
                                startIndex: startIndex,
                                endIndex: endIndex,
                                appendDot: true,
                                convertedBytes: &convertedBytes,
                                outputBufferForReuse: &outputBufferForReuse,
                                decodedUnicodeScalars: &decodedUnicodeScalars,
                                errors: &errors
                            )

                            startIndex = idx &+ 1
                        }

                        /// Last label
                        appendLabel(
                            domainNameSpan: processedBytesSpan,
                            startIndex: startIndex,
                            endIndex: processedBytesSpan.count,
                            appendDot: false,
                            convertedBytes: &convertedBytes,
                            outputBufferForReuse: &outputBufferForReuse,
                            decodedUnicodeScalars: &decodedUnicodeScalars,
                            errors: &errors
                        )

                        if configuration.verifyDNSLength {
                            if convertedBytes.count >= 254 {
                                errors.append(
                                    .trueVerifyDNSLengthArgumentRequiresDomainNameToBe254BytesOrLess(
                                        length: convertedBytes.count,
                                        labels: [UInt8](copying: convertedBytes)
                                    )
                                )
                            }
                            if convertedBytes.isEmpty {
                                /// FIXME: this line is never triggered in tests. Why?
                                /// It doesn't affect the conversion result at all, but I should still investigate.
                                errors.append(
                                    .trueVerifyDNSLengthArgumentDisallowsEmptyDomainName(
                                        labels: [UInt8](copying: convertedBytes)
                                    )
                                )
                            }
                        }
                    }

                    return convertedBytes.takeAsConversionResult()
                }
            }
        }

        if let errors = errors.collect() {
            throw errors
        }

        return result
    }

    @inlinable
    func appendLabel(
        domainNameSpan bytesSpan: Span<UInt8>,
        startIndex: Int,
        endIndex: Int,
        appendDot: Bool,
        convertedBytes: inout TinyBuffer,
        outputBufferForReuse: inout TinyBuffer,
        decodedUnicodeScalars: inout DecodedUnicodeScalars.Subsequence,
        errors: inout MappingErrors
    ) {
        let range = unsafe Range<Int>(uncheckedBounds: (startIndex, endIndex))
        let labelSpan = unsafe bytesSpan.extracting(unchecked: range)
        var labelByteLength = 0
        if labelSpan.isASCII {
            labelByteLength = labelSpan.count
            convertedBytes.append(
                exactExtraRequiredCapacity: labelSpan.count &+ 1
            ) { output in
                output.swift_idna_append(copying: labelSpan)
                if appendDot {
                    output.append(.asciiDot)
                }
            }
        } else {
            /// TODO: can we pass convertedBytes to Punycode.encode instead of it returning a new array?
            decodedUnicodeScalars.set(utf8OffsetRange: range)

            Punycode.encode(
                _uncheckedAssumingValidUTF8: labelSpan,
                outputBufferForReuse: &outputBufferForReuse,
                decodedUnicodeScalars: decodedUnicodeScalars
            )

            labelByteLength = 4 &+ outputBufferForReuse.count
            convertedBytes.append(
                exactExtraRequiredCapacity: 4 &+ outputBufferForReuse.count &+ 1
            ) { output in
                output.append(.asciiLowercasedX)
                output.append(.asciiLowercasedN)
                output.append(.asciiHyphenMinus)
                output.append(.asciiHyphenMinus)
                outputBufferForReuse.withSpan { output.swift_idna_append(copying: $0) }
                if appendDot {
                    output.append(.asciiDot)
                }
            }
        }

        if configuration.verifyDNSLength {
            if labelByteLength > 63 {
                errors.append(
                    .trueVerifyDNSLengthArgumentRequiresLabelToBe63BytesOrLess(
                        length: labelByteLength,
                        labels: [UInt8](copying: convertedBytes)
                    )
                )
            }

            if labelByteLength == 0 {
                errors.append(
                    .trueVerifyDNSLengthArgumentDisallowsEmptyLabel(
                        labels: [UInt8](copying: convertedBytes)
                    )
                )
            }
        }
    }

    /// `ToUnicode` IDNA implementation.
    /// https://www.unicode.org/reports/tr46/#ToUnicode
    @inlinable
    func _toUnicode(
        _uncheckedAssumingValidUTF8 span: Span<UInt8>
    ) throws(CollectedMappingErrors) -> ConversionResult {
        switch IDNA.performByteCheck(on: span) {
        case .containsOnlyIDNANoOpCharacters:
            if !span.containsIDNADomainNameMarkerLabelPrefix {
                return .noChangesNeeded
            }
        case .onlyNeedsLowercasingOfUppercasedASCIILetters:
            if !span.containsIDNADomainNameMarkerLabelPrefix {
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

                self.mainProcessing(
                    _uncheckedAssumingValidUTF8: span,
                    reuseBuffer: &reuseBuffer,
                    output: &utf8Bytes,
                    errors: &errors,
                    /// The SIMD decoder wins on this smaller toUnicode path.
                    useSIMDDecoder: true
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

    /// Main `Processing` IDNA implementation.
    /// https://www.unicode.org/reports/tr46/#Processing
    @inlinable
    @inline(__always)
    func mainProcessing(
        _uncheckedAssumingValidUTF8 span: Span<UInt8>,
        reuseBuffer newBytes: inout TinyBuffer,
        output newerBytes: inout TinyBuffer,
        errors: inout MappingErrors,
        useSIMDDecoder: Bool
    ) {
        /// 1. Map
        self.mapToIDNAMappings(
            _uncheckedAssumingValidUTF8: span,
            into: &newBytes,
            useSIMDDecoder: useSIMDDecoder
        )

        /// 2. Normalize

        /// Make `newBytes` NFC, if not already NFC
        newBytes._uncheckedAssumingValidUTF8_ensureNFC()
        newerBytes.reserveCapacity(newBytes.count)

        newBytes.withSpan { newBytesSpan in
            let maxRequiredCapacityForAllLabels = self.maxLabelLength(span: newBytesSpan)
            var scalarsIndexToUTF8IndexForReuse = LazyRigidArray<Int>(
                capacity: maxRequiredCapacityForAllLabels
            )

            var startIndex = 0
            for idx in newBytesSpan.indices {
                /// Unchecked because idx comes right from `newBytesSpan.indices`
                guard newBytesSpan[idx] == .asciiDot else {
                    continue
                }

                let range = unsafe Range<Int>(uncheckedBounds: (startIndex, idx))
                let chunk = unsafe newBytesSpan.extracting(unchecked: range)

                if convertAndValidateLabel(
                    chunk,
                    scalarsIndexToUTF8IndexForReuse: &scalarsIndexToUTF8IndexForReuse,
                    newerBytes: &newerBytes,
                    errors: &errors
                ) {
                    newerBytes.append(unchecked: .asciiDot)
                }

                startIndex = idx &+ 1
            }

            let range = unsafe Range<Int>(uncheckedBounds: (startIndex, newBytesSpan.count))
            let chunk = unsafe newBytesSpan.extracting(unchecked: range)
            _ = convertAndValidateLabel(
                chunk,
                scalarsIndexToUTF8IndexForReuse: &scalarsIndexToUTF8IndexForReuse,
                newerBytes: &newerBytes,
                errors: &errors
            )
        }
    }

    /// Maps the given span to IDNA mappings.
    @inlinable
    @inline(__always)
    func mapToIDNAMappings(
        _uncheckedAssumingValidUTF8 span: Span<UInt8>,
        into newBytes: inout TinyBuffer,
        useSIMDDecoder: Bool
    ) {
        if useSIMDDecoder {
            self.mapToIDNAMappings_SIMD(_uncheckedAssumingValidUTF8: span, into: &newBytes)
        } else {
            self.mapToIDNAMappings_Scalar(_uncheckedAssumingValidUTF8: span, into: &newBytes)
        }
    }

    @inlinable
    @inline(__always)
    func mapToIDNAMappings_Scalar(
        _uncheckedAssumingValidUTF8 span: Span<UInt8>,
        into newBytes: inout TinyBuffer
    ) {
        var requiredCapacity = 0

        var unicodeScalarsIterator = UnicodeScalarIterator()

        while let (scalar, range) = unicodeScalarsIterator.nextWithRange(in: span) {
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
        newBytes.append(exactExtraRequiredCapacity: requiredCapacity) { output in
            while let (scalar, range) = unicodeScalarsIterator.nextWithRange(in: span) {
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
        _uncheckedAssumingValidUTF8 span: Span<UInt8>,
        into newBytes: inout TinyBuffer
    ) {
        let count = span.count
        var requiredCapacity = 0

        SIMDUnicodeScalarDecoder.withDecoder { decoder in
            var windowStart = 0
            while windowStart < count {
                let realCount = Swift.min(
                    SIMDUnicodeScalarDecoder.windowSize,
                    count &- windowStart
                )
                let windowEnd = windowStart &+ realCount

                // let spanWindowRange = unsafe Range<Int>(uncheckedBounds: (windowStart, windowEnd))
                // let spanWindow = unsafe span.extracting(unchecked: spanWindowRange)
                // if spanWindow.isASCII {
                //     requiredCapacity &+= realCount
                //     windowStart = windowEnd
                //     continue
                // }

                let decodeRange = unsafe Range<Int>(
                    uncheckedBounds: (windowStart, windowStart &+ count)
                )
                decoder.decodeWindow(of: span, range: decodeRange)

                var i = windowStart
                while i < windowEnd {
                    let localIndex = i &- windowStart
                    let scalarUTF8Length = Int(
                        unsafe decoder.scalarUTF8Lengths[unchecked: localIndex]
                    )
                    let scalar = unsafe decoder.scalarValues[unchecked: localIndex]

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

                windowStart = i
            }

            /// I'm expecting this to be empty at this point, nothing special.
            /// Tests will immediately crash if this is not the case.
            assert(newBytes.isEmpty)

            /// Reserve the exact required capacity up front so we can skip further capacity
            /// checks because we're guaranteed to have enough capacity.
            newBytes.append(exactExtraRequiredCapacity: requiredCapacity) { output in
                var windowStart = 0
                while windowStart < count {
                    let realCount = Swift.min(
                        SIMDUnicodeScalarDecoder.windowSize,
                        count &- windowStart
                    )
                    let windowEnd = windowStart &+ realCount

                    // let spanWindowRange = unsafe Range<Int>(
                    //     uncheckedBounds: (windowStart, windowEnd)
                    // )
                    // let spanWindow = unsafe span.extracting(unchecked: spanWindowRange)
                    // if spanWindow.isASCII {
                    //     output.swift_idna_appendLowercasingASCII(copying: spanWindow)
                    //     windowStart = windowEnd
                    //     continue
                    // }

                    let decodeRange = unsafe Range<Int>(
                        uncheckedBounds: (windowStart, windowStart &+ count)
                    )
                    decoder.decodeWindow(of: span, range: decodeRange)

                    var i = windowStart
                    while i < windowEnd {
                        let localIndex = i &- windowStart
                        let scalarUTF8Length = Int(
                            unsafe decoder.scalarUTF8Lengths[unchecked: localIndex]
                        )
                        let scalar = unsafe decoder.scalarValues[unchecked: localIndex]

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

                    windowStart = i
                }
            }
        }
    }

    /// Returns the length of the longest label in the given span.
    /// Assumes the span does not contain any label separators other than `.`.
    @inlinable
    func maxLabelLength(span: Span<UInt8>) -> Int {
        var maxLabelLength = 0
        var startIndex = 0

        for idx in span.indices {
            /// Unchecked because idx comes right from `newBytesSpan.indices`
            guard span[idx] == .asciiDot else {
                continue
            }

            maxLabelLength = max(
                maxLabelLength,
                idx &- startIndex
            )
            startIndex = idx &+ 1
        }

        maxLabelLength = max(
            maxLabelLength,
            span.count &- startIndex
        )

        return maxLabelLength
    }

    /// https://www.unicode.org/reports/tr46/#ProcessingStepConvertValidate
    /// Returns true if succeeded.
    @inlinable
    func convertAndValidateLabel(
        _ span: Span<UInt8>,
        scalarsIndexToUTF8IndexForReuse: inout LazyRigidArray<Int>,
        newerBytes: inout TinyBuffer,
        errors: inout MappingErrors
    ) -> Bool {
        /// Checks if the label starts with “xn--”
        guard span.hasIDNADomainNameMarkerPrefix else {
            verifyValidLabel(_uncheckedAssumingValidUTF8: span, errors: &errors)
            newerBytes.append(copying: span)
            return true
        }

        /// 4.1:
        if !configuration.ignoreInvalidPunycode,
            !span.isASCII
        {
            errors.append(
                .labelStartsWithXNHyphenMinusHyphenMinusButContainsNonASCII(
                    label: String(_uncheckedAssumingValidUTF8: span)
                )
            )
            /// continue to next label
            return false
        }

        /// 4.2:
        /// If conversion fails, and we're not ignoring invalid punycode, record an error

        /// Drop the "xn--" prefix
        let noXNRange = unsafe Range<Int>(uncheckedBounds: (4, span.count))
        let currentNewerBytesCount = newerBytes.count

        var outputBuffer = TinyBufferSubsequence(
            base: newerBytes,
            startIndex: currentNewerBytesCount
        )
        if Punycode.decode(
            _uncheckedAssumingValidUTF8: unsafe span.extracting(unchecked: noXNRange),
            scalarsIndexToUTF8IndexForReuse: &scalarsIndexToUTF8IndexForReuse,
            outputBuffer: &outputBuffer
        ) {
            newerBytes = outputBuffer.base

            let range = unsafe Range<Int>(
                uncheckedBounds: (currentNewerBytesCount, newerBytes.count)
            )

            newerBytes.withSpan { newerBytesSpan in
                let conversionSpan = unsafe newerBytesSpan.extracting(unchecked: range)

                /// 4.3:
                checkInvalidPunycode(span: conversionSpan, errors: &errors)

                verifyValidLabel(_uncheckedAssumingValidUTF8: conversionSpan, errors: &errors)
            }

            return true
        } else {
            newerBytes = outputBuffer.base

            switch configuration.ignoreInvalidPunycode {
            case true:
                /// Use the original label

                /// 4.3:
                checkInvalidPunycode(span: span, errors: &errors)

                verifyValidLabel(_uncheckedAssumingValidUTF8: span, errors: &errors)

                newerBytes.append(copying: span)
                return true
            case false:
                errors.append(
                    .labelPunycodeDecodeFailed(
                        label: String(_uncheckedAssumingValidUTF8: span)
                    )
                )
                /// continue to next label
                return false
            }
        }
    }

    @inlinable
    func checkInvalidPunycode(span: Span<UInt8>, errors: inout MappingErrors) {
        if configuration.ignoreInvalidPunycode {
            return
        }

        if span.isEmpty {
            errors.append(
                .labelIsEmptyAfterPunycodeConversion(
                    label: String(_uncheckedAssumingValidUTF8: span)
                )
            )
        }

        if span.isASCII {
            errors.append(
                .labelContainsOnlyASCIIAfterPunycodeDecode(
                    label: String(_uncheckedAssumingValidUTF8: span)
                )
            )
        }
    }

    /// https://www.unicode.org/reports/tr46/#Validity_Criteria
    @inlinable
    func verifyValidLabel(
        _uncheckedAssumingValidUTF8 span: Span<UInt8>,
        errors: inout MappingErrors
    ) {
        if !configuration.ignoreInvalidPunycode,
            !span.isInNFC
        {
            errors.append(
                .labelIsNotInNormalizationFormC(
                    label: String(_uncheckedAssumingValidUTF8: span)
                )
            )
        }

        switch configuration.checkHyphens {
        case true:
            let bytesCount = span.count
            if bytesCount >= 4,
                span[2] == UInt8.asciiHyphenMinus,
                span[3] == UInt8.asciiHyphenMinus
            {
                errors.append(
                    .trueCheckHyphensArgumentRequiresLabelToNotContainHyphenMinusAtPostion3and4(
                        label: String(_uncheckedAssumingValidUTF8: span)
                    )
                )
            }
            if bytesCount >= 1,
                span[0] == UInt8.asciiHyphenMinus
                    || span[bytesCount - 1] == UInt8.asciiHyphenMinus
            {
                errors.append(
                    .trueCheckHyphensArgumentRequiresLabelToNotStartOrEndWithHyphenMinus(
                        label: String(_uncheckedAssumingValidUTF8: span)
                    )
                )
            }
        case false:
            if !configuration.ignoreInvalidPunycode,
                span.hasIDNADomainNameMarkerPrefix
            {
                errors.append(
                    .falseCheckHyphensArgumentRequiresLabelToNotStartWithXNHyphenMinusHyphenMinus(
                        label: String(_uncheckedAssumingValidUTF8: span)
                    )
                )
            }
        }

        var unicodeScalarsIterator = UnicodeScalarIterator()
        if !configuration.ignoreInvalidPunycode,
            let firstScalar = unicodeScalarsIterator.next(in: span),
            firstScalar.properties.generalCategory.isMark == true
        {
            errors.append(
                .labelStartsWithCombiningMark(
                    label: String(_uncheckedAssumingValidUTF8: span)
                )
            )
        }

        if !configuration.ignoreInvalidPunycode || configuration.useSTD3ASCIIRules {
            var unicodeScalarsIterator = UnicodeScalarIterator()

            while let codePoint = unicodeScalarsIterator.next(in: span) {
                if !configuration.ignoreInvalidPunycode {
                    let mapping = IDNAMapping.for(scalar: codePoint)
                    switch mapping.tag {
                    case .validNone, .validNV8, .validXV8, .deviation:
                        break
                    case .mapped, .disallowed, .ignored:
                        errors.append(
                            .labelContainsInvalidUnicode(
                                codePoint,
                                label: String(_uncheckedAssumingValidUTF8: span)
                            )
                        )
                    }
                }

                if configuration.useSTD3ASCIIRules {
                    if codePoint.isASCII,
                        !codePoint.value.isLowercasedLetterOrDigitOrHyphenMinus
                    {
                        errors.append(
                            .trueUseSTD3ASCIIRulesArgumentRequiresLabelToOnlyContainCertainASCIICharacters(
                                label: String(_uncheckedAssumingValidUTF8: span)
                            )
                        )
                    }
                }
            }
        }

        // if configuration.checkJoiners {
        // TODO: implement
        // }

        // if configuration.checkBidi {
        // TODO: implement
        // }
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

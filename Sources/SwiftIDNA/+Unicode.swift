extension Unicode.Scalar {
    @inlinable
    var isNumberOrLowercasedLetterOrHyphenMinusASCII: Bool {
        (self.value >= 0x30 && self.value <= 0x39)
            || (self.value >= 0x61 && self.value <= 0x7A)
            || self.isHyphenMinus
    }

    @inlinable
    var isNumberOrLowercasedLetterOrDotASCII: Bool {
        (self.value >= 0x30 && self.value <= 0x39)
            || (self.value >= 0x61 && self.value <= 0x7A)
            || self.isASCIIDot
    }

    @inlinable
    var isUppercasedASCII: Bool {
        self.value >= 0x41 && self.value <= 0x5A
    }

    @inlinable
    static var asciiHyphenMinus: Unicode.Scalar {
        Unicode.Scalar(0x2D).unsafelyUnwrapped
    }

    @inlinable
    var isHyphenMinus: Bool {
        self.value == 0x2D
    }

    @inlinable
    static var asciiDot: Unicode.Scalar {
        Unicode.Scalar(0x2E).unsafelyUnwrapped
    }

    @inlinable
    var isASCIIDot: Bool {
        self.value == 0x2E
    }

    @inlinable
    static var asciiLowercasedX: Unicode.Scalar {
        Unicode.Scalar(0x78).unsafelyUnwrapped
    }

    @inlinable
    static var asciiLowercasedN: Unicode.Scalar {
        Unicode.Scalar(0x6E).unsafelyUnwrapped
    }
}

extension Unicode.GeneralCategory {
    @inlinable
    var isMark: Bool {
        switch self {
        case .spacingMark, .enclosingMark, .nonspacingMark:
            return true
        default:
            return false
        }
    }
}

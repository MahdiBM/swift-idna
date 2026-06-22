public import BasicContainers

@available(SwiftStdlib 5.1, *)
extension UniqueArray<UInt8> {
    /// Converts the unique array to Normalization Form C (NFC), if needed.
    @usableFromInline
    mutating func _uncheckedAssumingValidUTF8_ensureNFC() {
        if self.isEmpty || self.span.isASCII { return }

        let string = String(_uncheckedAssumingValidUTF8: self.span)

        self.removeAll(keepingCapacity: true)
        self.edit { output in
            string._withNFCCodeUnits { utf8Byte in
                output.append(utf8Byte)
            }
        }
    }
}

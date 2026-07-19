#!/usr/bin/env swift
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Generation parameters. Variants are produced by changing these two constants:
/// - `useDelta`: encode single-scalar mappings as `code_point + delta` (fewer UTF-8 blob touches),
///   otherwise route every mapping through the UTF-8 blob (simpler `IDNAUnicodeScalarView`).
/// - `blockShift`: log2 of the trie block size. Must match CSWIFT_IDNA_BLOCK_SHIFT.
let useDelta = false
let blockShift = 6

let mappingTableURL = "https://www.unicode.org/Public/idna/latest/IdnaMappingTable.txt"
let outputPath = "Sources/CSwiftIDNA/src/cswift_idna_mapping_table.c"

let maxCodePoint: UInt32 = 0x10FFFF
let blockSize = 1 << blockShift
let blockMask = blockSize - 1

/// Trie value tags. Must match the CSWIFT_IDNA_TAG_* macros in CSwiftIDNA.h.
enum Tag: UInt16 {
    case validNone = 0
    case validNV8 = 1
    case validXV8 = 2
    case ignored = 3
    case disallowed = 4
    case deviation = 5
    case mappedDelta = 6
    case mapped = 7
}

enum Status: Equatable {
    case validNone
    case validNV8
    case validXV8
    case ignored
    case disallowed
    case deviation([UInt32])
    case mapped([UInt32])
}

func fetchWithRetries(url: URL) throws -> Data {
    let maxAttempts = 5
    for attempts in 1...maxAttempts {
        do {
            return try Data(contentsOf: url)
        } catch {
            if attempts == maxAttempts {
                throw error
            } else {
                print("✗ Failed to fetch latest release: \(String(reflecting: error))")
                print("Retrying in 3 seconds...")
                sleep(3)
            }
        }
    }
    fatalError("Unreachable")
}

func parseScalars(_ s: Substring) -> [UInt32] {
    s.split(whereSeparator: { $0 == " " || $0 == "\t" }).map {
        UInt32($0, radix: 16)!
    }
}

func utf8Bytes(_ scalars: [UInt32]) -> [UInt8] {
    var out: [UInt8] = []
    for scalar in scalars {
        out.append(contentsOf: Array(Unicode.Scalar(scalar)!.utf8))
    }
    return out
}

func parse(_ text: String) -> [Status] {
    var perCodePoint = [Status?](repeating: nil, count: Int(maxCodePoint) + 1)

    for rawLine in text.split(separator: "\n") {
        var line = rawLine
        if let hash = line.firstIndex(of: "#") {
            line = line[..<hash]
        }
        line = Substring(line.trimmingCharacters(in: .whitespaces))
        if line.isEmpty { continue }

        let parts = line.split(separator: ";", omittingEmptySubsequences: false).map {
            Substring($0.trimmingCharacters(in: .whitespaces))
        }
        guard parts.count >= 2 else {
            fatalError("Line has less than 2 parts: \(line.debugDescription)")
        }

        let codePoints = parts[0].split(separator: "..")
        let start = UInt32(codePoints[0], radix: 16)!
        let end = codePoints.count == 2 ? UInt32(codePoints[1], radix: 16)! : start

        let status: Status
        switch parts[1] {
        case "valid":
            switch parts.count {
            case 2:
                status = .validNone
            case 4:
                switch parts[3] {
                case "NV8": status = .validNV8
                case "XV8": status = .validXV8
                default: status = .validNone
                }
            default:
                fatalError("Unexpected parts for 'valid': \(line.debugDescription)")
            }
        case "ignored":
            status = .ignored
        case "disallowed":
            status = .disallowed
        case "deviation":
            status = .deviation(
                parts.count > 2 && !parts[2].isEmpty ? parseScalars(parts[2]) : []
            )
        case "mapped":
            status = .mapped(parseScalars(parts[2]))
        default:
            fatalError(
                "Unexpected status \(parts[1].debugDescription), expected only "
                    + "valid/mapped/deviation/disallowed/ignored: \(line.debugDescription)"
            )
        }

        for codePoint in start...end {
            perCodePoint[Int(codePoint)] = status
        }
    }

    let statuses = perCodePoint.enumerated().map { index, status -> Status in
        guard let status = status else {
            fatalError("Uncovered code point U+\(String(index, radix: 16, uppercase: true))")
        }
        return status
    }
    return statuses
}

func findSubsequence(_ haystack: [UInt8], _ needle: [UInt8]) -> Int? {
    if needle.isEmpty { return 0 }
    if needle.count > haystack.count { return nil }
    for start in 0...(haystack.count - needle.count) {
        var matches = true
        for offset in 0..<needle.count where haystack[start + offset] != needle[offset] {
            matches = false
            break
        }
        if matches { return start }
    }
    return nil
}

struct BuiltTables {
    var blockOffsets: [UInt16] = []
    var packedValues: [UInt16] = []
    var mappedDeltas: [Int32] = []
    var mappedSlices: [UInt32] = []
    var mappedUTF8: [UInt8] = []
}

func build(_ statuses: [Status]) -> BuiltTables {
    var tables = BuiltTables()

    var utf8OffsetForOutput: [[UInt8]: Int] = [:]
    var sliceIndexForOutput: [[UInt8]: Int] = [:]
    var deltaIndexForDelta: [Int32: Int] = [:]

    /// Interns a mapping/deviation output into the UTF-8 blob (sharing substrings) and returns the
    /// index into `mappedSlices`.
    func internOutput(_ scalars: [UInt32]) -> Int {
        let bytes = utf8Bytes(scalars)
        if let existing = sliceIndexForOutput[bytes] {
            return existing
        }
        let offset: Int
        if let shared = utf8OffsetForOutput[bytes] ?? findSubsequence(tables.mappedUTF8, bytes) {
            offset = shared
        } else {
            offset = tables.mappedUTF8.count
            tables.mappedUTF8.append(contentsOf: bytes)
        }
        utf8OffsetForOutput[bytes] = offset
        precondition(offset < (1 << 24), "utf8 offset exceeds 24 bits")
        precondition(bytes.count < (1 << 8), "mapping length exceeds 8 bits")
        let sliceIndex = tables.mappedSlices.count
        tables.mappedSlices.append(UInt32(offset << 8) | UInt32(bytes.count))
        sliceIndexForOutput[bytes] = sliceIndex
        return sliceIndex
    }

    func internDelta(_ delta: Int32) -> Int {
        if let existing = deltaIndexForDelta[delta] {
            return existing
        }
        let index = tables.mappedDeltas.count
        tables.mappedDeltas.append(delta)
        deltaIndexForDelta[delta] = index
        return index
    }

    /// Assign every mapping/deviation output an interned slot first, so hot outputs (encountered
    /// first, e.g. ASCII foldings) get the lowest, most cache-friendly indices, and longer outputs
    /// can still reuse a previously-stored shorter suffix via `findSubsequence`.
    func value(for status: Status, codePoint: Int) -> UInt16 {
        switch status {
        case .validNone: return Tag.validNone.rawValue << 13
        case .validNV8: return Tag.validNV8.rawValue << 13
        case .validXV8: return Tag.validXV8.rawValue << 13
        case .ignored: return Tag.ignored.rawValue << 13
        case .disallowed: return Tag.disallowed.rawValue << 13
        case .deviation(let scalars):
            let index = internOutput(scalars)
            precondition(index < (1 << 13), "deviation index exceeds 13 bits")
            return (Tag.deviation.rawValue << 13) | UInt16(index)
        case .mapped(let scalars):
            if useDelta && scalars.count == 1 {
                let delta = Int32(scalars[0]) - Int32(codePoint)
                let index = internDelta(delta)
                precondition(index < (1 << 13), "delta index exceeds 13 bits")
                return (Tag.mappedDelta.rawValue << 13) | UInt16(index)
            }
            let index = internOutput(scalars)
            precondition(index < (1 << 13), "mapped index exceeds 13 bits")
            return (Tag.mapped.rawValue << 13) | UInt16(index)
        }
    }

    var values = [UInt16](repeating: 0, count: statuses.count)
    for codePoint in 0..<statuses.count {
        values[codePoint] = value(for: statuses[codePoint], codePoint: codePoint)
    }

    let numBlocks = (statuses.count + blockSize - 1) / blockSize
    precondition(numBlocks * blockSize == statuses.count, "code point range not a block multiple")

    var offsetForBlock: [ArraySlice<UInt16>: Int] = [:]
    for blockIndex in 0..<numBlocks {
        let lower = blockIndex * blockSize
        let upper = lower + blockSize
        let block = values[lower..<upper]

        if let existing = offsetForBlock[block] {
            tables.blockOffsets.append(UInt16(existing))
            continue
        }

        var overlap = min(tables.packedValues.count, blockSize - 1)
        while overlap > 0 {
            var matches = true
            let base = tables.packedValues.count - overlap
            for offset in 0..<overlap {
                if tables.packedValues[base + offset] != block[block.startIndex + offset] {
                    matches = false
                    break
                }
            }
            if matches { break }
            overlap -= 1
        }

        let offset = tables.packedValues.count - overlap
        for position in overlap..<blockSize {
            tables.packedValues.append(block[block.startIndex + position])
        }
        precondition(offset < (1 << 16), "packedValues offset exceeds uint16")
        tables.blockOffsets.append(UInt16(offset))
        offsetForBlock[block] = offset
    }

    precondition(tables.packedValues.count < (1 << 16), "packedValues exceeds uint16 index space")
    return tables
}

/// Decodes a single code point straight from the built tables, exactly as the runtime does,
/// and returns the reconstructed semantic status for round-trip verification.
func decode(_ codePoint: Int, _ tables: BuiltTables) -> Status {
    let blockRowIndex = codePoint >> blockShift
    let packedRowIndex = Int(tables.blockOffsets[blockRowIndex]) + (codePoint & blockMask)
    let value = tables.packedValues[packedRowIndex]
    let tag = Tag(rawValue: value >> 13)!
    let payload = Int(value & 0x1FFF)

    func scalarsFromSlice(_ sliceIndex: Int) -> [UInt32] {
        let entry = tables.mappedSlices[sliceIndex]
        let offset = Int(entry >> 8)
        let length = Int(entry & 0xFF)
        let bytes = Array(tables.mappedUTF8[offset..<(offset + length)])
        return Array(String(decoding: bytes, as: UTF8.self).unicodeScalars).map { $0.value }
    }

    switch tag {
    case .validNone: return .validNone
    case .validNV8: return .validNV8
    case .validXV8: return .validXV8
    case .ignored: return .ignored
    case .disallowed: return .disallowed
    case .deviation: return .deviation(scalarsFromSlice(payload))
    case .mappedDelta:
        let delta = tables.mappedDeltas[payload]
        return .mapped([UInt32(Int32(codePoint) + delta)])
    case .mapped: return .mapped(scalarsFromSlice(payload))
    }
}

func verify(_ statuses: [Status], _ tables: BuiltTables) {
    for codePoint in 0..<statuses.count {
        let decoded = decode(codePoint, tables)
        guard decoded == statuses[codePoint] else {
            fatalError(
                "Round-trip mismatch at U+\(String(codePoint, radix: 16, uppercase: true)): "
                    + "expected \(statuses[codePoint]), got \(decoded)"
            )
        }
    }
    print("Round-trip verification passed for \(statuses.count) code points.")
}

/// Emits a `const <cType> <name>[] = { ... }` C array. Integer literals are coerced to the array
/// element type, so no unsigned suffix is needed. An empty array is emitted with a single `0` so
/// the C declaration stays valid (used by `mapped_deltas` in the non-delta build).
func emitArray(
    _ cType: String,
    _ name: String,
    _ values: [some FixedWidthInteger],
    perLine: Int = 16,
    into code: inout String
) {
    let elements = values.isEmpty ? [Int64(0)] : values.map { Int64($0) }
    code += "const \(cType) \(name)[\(elements.count)] = {\n"
    for start in stride(from: 0, to: elements.count, by: perLine) {
        let end = min(start + perLine, elements.count)
        let line = elements[start..<end].map(String.init).joined(separator: ", ")
        code += "    \(line),\n"
    }
    code += "};\n\n"
}

func emit(_ tables: BuiltTables) -> String {
    var code = """
        // This file is generated by the utils/IDNAMappingTableGenerator.swift script.

        #include "../include/CSwiftIDNA.h"
        #include <stdint.h>

        """

    emitArray("uint16_t", "cswift_idna_block_offsets", tables.blockOffsets, into: &code)
    emitArray("uint16_t", "cswift_idna_packed_values", tables.packedValues, into: &code)
    emitArray("int32_t", "cswift_idna_mapped_deltas", tables.mappedDeltas, into: &code)
    emitArray("uint32_t", "cswift_idna_mapped_slices", tables.mappedSlices, into: &code)
    emitArray("uint8_t", "cswift_idna_mapped_utf8", tables.mappedUTF8, perLine: 24, into: &code)

    return code
}

func run() {
    let currentDirectory = FileManager.default.currentDirectoryPath
    guard currentDirectory.hasSuffix("swift-idna") else {
        fatalError(
            "This script must be run from the swift-idna root directory. "
                + "Current directory: \(currentDirectory)."
        )
    }

    print("Downloading \(mappingTableURL) ...")
    let file = try! fetchWithRetries(url: URL(string: mappingTableURL)!)
    print("Downloaded \(file.count) bytes")

    let text = String(decoding: file, as: UTF8.self)
    let statuses = parse(text)
    print("Parsed \(statuses.count) code points")

    let tables = build(statuses)
    print(
        "Built: blockOffsets=\(tables.blockOffsets.count) packedValues=\(tables.packedValues.count) "
            + "mappedDeltas=\(tables.mappedDeltas.count) mappedSlices=\(tables.mappedSlices.count) "
            + "mappedUTF8=\(tables.mappedUTF8.count) (useDelta=\(useDelta), shift=\(blockShift))"
    )
    let totalBytes =
        tables.blockOffsets.count * 2
        + tables.packedValues.count * 2
        + tables.mappedDeltas.count * 4
        + tables.mappedSlices.count * 4
        + tables.mappedUTF8.count
    let totalKB = String(format: "%.1f", Double(totalBytes) / 1024)
    print("Total table bytes: \(totalBytes) (\(totalKB) KB)")

    verify(statuses, tables)

    let generated = emit(tables)
    print("Generated \(generated.split(whereSeparator: \.isNewline).count) lines")

    if FileManager.default.fileExists(atPath: outputPath),
        try! String(contentsOfFile: outputPath, encoding: .utf8) == generated
    {
        print("Generated code matches current contents, no changes needed.")
    } else {
        print("Writing to \(outputPath) ...")
        try! generated.write(toFile: outputPath, atomically: true, encoding: .utf8)
    }

    print("Done!")
}

run()

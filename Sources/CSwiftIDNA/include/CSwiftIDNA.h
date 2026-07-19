#ifndef CSWIFT_DNS_IDNA_H
#define CSWIFT_DNS_IDNA_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// IDNA mapping is stored as a two-stage code-point trie built by
// utils/IDNAMappingTableGenerator.swift.
//
// A code point is split into a block number (high bits) and an offset within
// the block (low bits). `block_offsets` maps the block number to where that
// block's values begin in `packed_values`:
//
//   packed_value = packed_values[block_offsets[cp >> BLOCK_SHIFT] + (cp & BLOCK_MASK)]
//
// The top 3 bits of `packed_value` are the mapping tag; the low 13 bits are the
// payload. For the mapped and deviation tags the payload indexes `mapped_slices`,
// each of which packs a byte offset into `mapped_utf8` (high 24 bits) and a
// length (low 8 bits). The other tags carry no payload. The tag values are
// defined by the `Tag` enum in Sources/SwiftIDNA/IDNAMapping.swift.

#define CSWIFT_IDNA_BLOCK_SHIFT 6
#define CSWIFT_IDNA_BLOCK_MASK 63

extern const uint16_t cswift_idna_block_offsets[];
extern const uint16_t cswift_idna_packed_values[];
extern const uint32_t cswift_idna_mapped_slices[];
extern const uint8_t cswift_idna_mapped_utf8[];

// Returns the packed 16-bit trie value for any given valid Unicode scalar value.
static inline uint16_t cswift_idna_packed_value(uint32_t code_point) {
    return cswift_idna_packed_values[
        (uint32_t)cswift_idna_block_offsets[code_point >> CSWIFT_IDNA_BLOCK_SHIFT]
        + (code_point & CSWIFT_IDNA_BLOCK_MASK)
    ];
}

// Returns the packed mapped/deviation slice (byte offset into mapped_utf8 in the
// high 24 bits, UTF-8 byte length in the low 8 bits) for a mapped/deviation payload.
static inline uint32_t cswift_idna_mapped_slice(uint32_t slice_index) {
    return cswift_idna_mapped_slices[slice_index];
}

// Returns a pointer to the mapped/deviation UTF-8 bytes at the given byte offset.
static inline const uint8_t *cswift_idna_mapped_utf8_at(uint32_t byte_offset) {
    return cswift_idna_mapped_utf8 + byte_offset;
}

#ifdef __cplusplus
} // extern "C"
#endif

#endif // CSWIFT_DNS_IDNA_H

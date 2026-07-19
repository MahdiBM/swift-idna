#ifndef CSWIFT_DNS_IDNA_H
#define CSWIFT_DNS_IDNA_H

#include <stdint.h>
#include <stddef.h>

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
// payload. For the mapped/deviation tags the payload indexes `mapped_slices`,
// each of which packs a byte offset into `mapped_utf8` (high 24 bits) and a
// length (low 8 bits). For the mapped-delta tag (only emitted by the delta
// variant) the payload indexes `mapped_deltas`, and the mapped scalar is
// `code_point + delta`.

#define CSWIFT_IDNA_BLOCK_SHIFT 6
#define CSWIFT_IDNA_BLOCK_MASK 63

#define CSWIFT_IDNA_TAG_VALID_NONE 0
#define CSWIFT_IDNA_TAG_VALID_NV8 1
#define CSWIFT_IDNA_TAG_VALID_XV8 2
#define CSWIFT_IDNA_TAG_IGNORED 3
#define CSWIFT_IDNA_TAG_DISALLOWED 4
#define CSWIFT_IDNA_TAG_DEVIATION 5
#define CSWIFT_IDNA_TAG_MAPPED_DELTA 6
#define CSWIFT_IDNA_TAG_MAPPED 7

extern const uint16_t cswift_idna_block_offsets[];
extern const uint16_t cswift_idna_packed_values[];
extern const int32_t cswift_idna_mapped_deltas[];
extern const uint32_t cswift_idna_mapped_slices[];
extern const uint8_t cswift_idna_mapped_utf8[];

// Returns the packed 16-bit trie value for a Unicode scalar value.
// `code_point` must be a valid Unicode scalar (<= 0x10FFFF, non-surrogate),
// which the Swift `Unicode.Scalar` type guarantees, so no bounds check is done.
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

// Returns the signed scalar delta for a mapped-delta payload (delta variant only).
static inline int32_t cswift_idna_mapped_delta(uint32_t delta_index) {
    return cswift_idna_mapped_deltas[delta_index];
}

#ifdef __cplusplus
} // extern "C"
#endif

#endif // CSWIFT_DNS_IDNA_H

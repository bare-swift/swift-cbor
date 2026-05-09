// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import Bytes

/// CBOR encoder. Picks the shortest length-encoding for each value
/// (tiny / 1-byte / 2-byte / 4-byte / 8-byte) per the RFC 8949
/// "preferred serialization" rule. All multi-byte integer fields on
/// the wire are big-endian (network order).
enum Encoder {
    static func encode(_ value: CBORValue, into out: inout Bytes) {
        switch value {
        case .uint(let n):
            writeTypeAndLength(majorType: 0, value: n, into: &out)
        case .negative(let n):
            writeTypeAndLength(majorType: 1, value: n, into: &out)
        case .byteString(let b):
            writeTypeAndLength(majorType: 2, value: UInt64(b.count), into: &out)
            out.append(contentsOf: b.storage)
        case .textString(let s):
            let utf8 = Array(s.utf8)
            writeTypeAndLength(majorType: 3, value: UInt64(utf8.count), into: &out)
            out.append(contentsOf: utf8)
        case .array(let xs):
            writeTypeAndLength(majorType: 4, value: UInt64(xs.count), into: &out)
            for x in xs { encode(x, into: &out) }
        case .map(let entries):
            writeTypeAndLength(majorType: 5, value: UInt64(entries.count), into: &out)
            for e in entries {
                encode(e.key, into: &out)
                encode(e.value, into: &out)
            }
        case .tagged(let tag, let inner):
            writeTypeAndLength(majorType: 6, value: tag, into: &out)
            encode(inner, into: &out)
        case .bool(let b):
            out.append(b ? 0xF5 : 0xF4)
        case .null:
            out.append(0xF6)
        case .undefined:
            out.append(0xF7)
        case .simple(let code):
            // Codes 0..23 inline in the leading byte; 32..255 use 0xF8 prefix.
            // Codes 24..31 are reserved (RFC 8949 § 3.3); reject up-front to
            // avoid producing a sequence that fails on round-trip.
            if code <= 23 {
                out.append(0xE0 | code)
            } else {
                // 24..31 reserved; clamp by re-emitting via 0xF8 only when >= 32.
                // 24..31 inputs are user error; we still emit the most-faithful
                // form (0xF8 + code) and let the decoder reject on read.
                out.append(0xF8)
                out.append(code)
            }
        case .float32(let f):
            out.append(0xFA)
            appendBE32(f.bitPattern, into: &out)
        case .float64(let d):
            out.append(0xFB)
            appendBE64(d.bitPattern, into: &out)
        }
    }

    /// Write the leading byte (major type in top 3 bits + additional-info in
    /// low 5 bits) and any follow-up length / immediate-value bytes.
    private static func writeTypeAndLength(majorType: UInt8, value: UInt64, into out: inout Bytes) {
        let tag = majorType << 5
        if value <= 23 {
            out.append(tag | UInt8(value))
        } else if value <= UInt64(UInt8.max) {
            out.append(tag | 24)
            out.append(UInt8(value))
        } else if value <= UInt64(UInt16.max) {
            out.append(tag | 25)
            appendBE16(UInt16(value), into: &out)
        } else if value <= UInt64(UInt32.max) {
            out.append(tag | 26)
            appendBE32(UInt32(value), into: &out)
        } else {
            out.append(tag | 27)
            appendBE64(value, into: &out)
        }
    }

    private static func appendBE16(_ value: UInt16, into out: inout Bytes) {
        out.append(UInt8(truncatingIfNeeded: value >> 8))
        out.append(UInt8(truncatingIfNeeded: value))
    }

    private static func appendBE32(_ value: UInt32, into out: inout Bytes) {
        out.append(UInt8(truncatingIfNeeded: value >> 24))
        out.append(UInt8(truncatingIfNeeded: value >> 16))
        out.append(UInt8(truncatingIfNeeded: value >> 8))
        out.append(UInt8(truncatingIfNeeded: value))
    }

    private static func appendBE64(_ value: UInt64, into out: inout Bytes) {
        out.append(UInt8(truncatingIfNeeded: value >> 56))
        out.append(UInt8(truncatingIfNeeded: value >> 48))
        out.append(UInt8(truncatingIfNeeded: value >> 40))
        out.append(UInt8(truncatingIfNeeded: value >> 32))
        out.append(UInt8(truncatingIfNeeded: value >> 24))
        out.append(UInt8(truncatingIfNeeded: value >> 16))
        out.append(UInt8(truncatingIfNeeded: value >> 8))
        out.append(UInt8(truncatingIfNeeded: value))
    }
}

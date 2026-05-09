// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import Bytes

/// CBOR decoder. Recursive descent over the major-type / additional-info
/// schema in RFC 8949 § 3.
enum Decoder {
    static func decode(_ bytes: Bytes, cursor: inout Int) throws(CBORError) -> CBORValue {
        let leading = try readByte(bytes, cursor: &cursor)
        let majorType = leading >> 5
        let info = leading & 0x1F

        // Major type 7 has its own info-handling path; everything else uses
        // readArgument to resolve the integer argument from the info bits.
        if majorType == 7 {
            return try decodeMajor7(info: info, bytes: bytes, cursor: &cursor)
        }

        if info == 31 {
            throw .indefiniteLengthUnsupported
        }

        let argument = try readArgument(info: info, bytes: bytes, cursor: &cursor)

        switch majorType {
        case 0:
            return .uint(argument)
        case 1:
            return .negative(argument)
        case 2:
            return .byteString(try readBytes(bytes, cursor: &cursor, length: Int(argument)))
        case 3:
            let raw = try readBytes(bytes, cursor: &cursor, length: Int(argument))
            guard isValidUTF8(raw.storage) else { throw .invalidUTF8 }
            return .textString(String(decoding: raw.storage, as: UTF8.self))
        case 4:
            return try decodeArray(bytes: bytes, cursor: &cursor, count: Int(argument))
        case 5:
            return try decodeMap(bytes: bytes, cursor: &cursor, count: Int(argument))
        case 6:
            let inner = try decode(bytes, cursor: &cursor)
            return .tagged(argument, inner)
        default:
            // Unreachable — major types 0..6 covered above, 7 handled separately.
            throw .reservedAdditionalInfo(info)
        }
    }

    // MARK: - Major type 7

    private static func decodeMajor7(info: UInt8, bytes: Bytes, cursor: inout Int) throws(CBORError) -> CBORValue {
        switch info {
        case 0...19:
            // Simple values 0..19; only some defined (20=false, 21=true, 22=null, 23=undefined live in the next range).
            return .simple(info)
        case 20:
            return .bool(false)
        case 21:
            return .bool(true)
        case 22:
            return .null
        case 23:
            return .undefined
        case 24:
            // 1-byte simple value follow-on. Codes 0..31 are reserved here.
            let code = try readByte(bytes, cursor: &cursor)
            if code < 32 {
                throw .reservedAdditionalInfo(code)
            }
            return .simple(code)
        case 25:
            // half-precision float
            let raw = try readBE16(bytes, cursor: &cursor)
            return .float32(float16ToFloat32(raw))
        case 26:
            return .float32(Float(bitPattern: try readBE32(bytes, cursor: &cursor)))
        case 27:
            return .float64(Double(bitPattern: try readBE64(bytes, cursor: &cursor)))
        case 28, 29, 30:
            throw .reservedAdditionalInfo(info)
        case 31:
            throw .unexpectedBreak
        default:
            throw .reservedAdditionalInfo(info)
        }
    }

    // MARK: - Argument resolution

    private static func readArgument(info: UInt8, bytes: Bytes, cursor: inout Int) throws(CBORError) -> UInt64 {
        switch info {
        case 0...23:
            return UInt64(info)
        case 24:
            return UInt64(try readByte(bytes, cursor: &cursor))
        case 25:
            return UInt64(try readBE16(bytes, cursor: &cursor))
        case 26:
            return UInt64(try readBE32(bytes, cursor: &cursor))
        case 27:
            return try readBE64(bytes, cursor: &cursor)
        case 28, 29, 30:
            throw .reservedAdditionalInfo(info)
        default:
            // info == 31 (indefinite) is caught by the caller before this is reached.
            throw .reservedAdditionalInfo(info)
        }
    }

    // MARK: - Containers

    private static func decodeArray(bytes: Bytes, cursor: inout Int, count: Int) throws(CBORError) -> CBORValue {
        var items: [CBORValue] = []
        items.reserveCapacity(count)
        for _ in 0..<count {
            items.append(try decode(bytes, cursor: &cursor))
        }
        return .array(items)
    }

    private static func decodeMap(bytes: Bytes, cursor: inout Int, count: Int) throws(CBORError) -> CBORValue {
        var entries: [CBORValue.MapEntry] = []
        entries.reserveCapacity(count)
        for _ in 0..<count {
            let key = try decode(bytes, cursor: &cursor)
            let value = try decode(bytes, cursor: &cursor)
            entries.append(.init(key: key, value: value))
        }
        return .map(entries)
    }

    // MARK: - Half-precision float (IEEE 754 binary16 → binary32)

    /// IEEE 754 half-precision (binary16) → single-precision (binary32).
    /// Lossless because every binary16 value has a binary32 representation.
    private static func float16ToFloat32(_ raw: UInt16) -> Float {
        let sign = UInt32(raw >> 15) & 0x1
        let exp  = UInt32(raw >> 10) & 0x1F
        let mant = UInt32(raw) & 0x3FF

        let bits: UInt32
        if exp == 0 {
            if mant == 0 {
                bits = sign << 31
            } else {
                // Subnormal: normalize.
                var e: UInt32 = 0
                var m = mant
                while (m & 0x400) == 0 {
                    m <<= 1
                    e += 1
                }
                let normalizedExp = (127 - 15 - e + 1)
                let normalizedMant = (m & 0x3FF) << 13
                bits = (sign << 31) | (UInt32(normalizedExp) << 23) | normalizedMant
            }
        } else if exp == 31 {
            // Infinity / NaN.
            bits = (sign << 31) | (0xFF << 23) | (mant << 13)
        } else {
            // Normal.
            let newExp = exp + (127 - 15)
            bits = (sign << 31) | (newExp << 23) | (mant << 13)
        }
        return Float(bitPattern: bits)
    }

    // MARK: - UTF-8 validation (RFC 3629)

    private static func isValidUTF8(_ bytes: ContiguousArray<UInt8>) -> Bool {
        var i = 0
        while i < bytes.count {
            let b = bytes[i]
            if b <= 0x7F {
                i += 1
            } else if b >= 0xC2 && b <= 0xDF {
                guard i + 1 < bytes.count, isCont(bytes[i + 1]) else { return false }
                i += 2
            } else if b == 0xE0 {
                guard i + 2 < bytes.count else { return false }
                let b1 = bytes[i + 1], b2 = bytes[i + 2]
                guard b1 >= 0xA0 && b1 <= 0xBF, isCont(b2) else { return false }
                i += 3
            } else if b >= 0xE1 && b <= 0xEC {
                guard i + 2 < bytes.count, isCont(bytes[i + 1]), isCont(bytes[i + 2]) else { return false }
                i += 3
            } else if b == 0xED {
                guard i + 2 < bytes.count else { return false }
                let b1 = bytes[i + 1], b2 = bytes[i + 2]
                guard b1 >= 0x80 && b1 <= 0x9F, isCont(b2) else { return false }
                i += 3
            } else if b >= 0xEE && b <= 0xEF {
                guard i + 2 < bytes.count, isCont(bytes[i + 1]), isCont(bytes[i + 2]) else { return false }
                i += 3
            } else if b == 0xF0 {
                guard i + 3 < bytes.count else { return false }
                let b1 = bytes[i + 1]
                guard b1 >= 0x90 && b1 <= 0xBF, isCont(bytes[i + 2]), isCont(bytes[i + 3]) else { return false }
                i += 4
            } else if b >= 0xF1 && b <= 0xF3 {
                guard i + 3 < bytes.count, isCont(bytes[i + 1]), isCont(bytes[i + 2]), isCont(bytes[i + 3]) else { return false }
                i += 4
            } else if b == 0xF4 {
                guard i + 3 < bytes.count else { return false }
                let b1 = bytes[i + 1]
                guard b1 >= 0x80 && b1 <= 0x8F, isCont(bytes[i + 2]), isCont(bytes[i + 3]) else { return false }
                i += 4
            } else {
                return false
            }
        }
        return true
    }

    private static func isCont(_ b: UInt8) -> Bool { b >= 0x80 && b <= 0xBF }

    // MARK: - Cursor helpers

    private static func readByte(_ bytes: Bytes, cursor: inout Int) throws(CBORError) -> UInt8 {
        guard cursor < bytes.count else { throw .truncated(needed: 1, available: 0) }
        let b = bytes.storage[cursor]
        cursor += 1
        return b
    }

    private static func readBE16(_ bytes: Bytes, cursor: inout Int) throws(CBORError) -> UInt16 {
        guard cursor + 2 <= bytes.count else { throw .truncated(needed: 2, available: bytes.count - cursor) }
        let hi = UInt16(bytes.storage[cursor])
        let lo = UInt16(bytes.storage[cursor + 1])
        cursor += 2
        return (hi << 8) | lo
    }

    private static func readBE32(_ bytes: Bytes, cursor: inout Int) throws(CBORError) -> UInt32 {
        guard cursor + 4 <= bytes.count else { throw .truncated(needed: 4, available: bytes.count - cursor) }
        var v: UInt32 = 0
        for i in 0..<4 { v = (v << 8) | UInt32(bytes.storage[cursor + i]) }
        cursor += 4
        return v
    }

    private static func readBE64(_ bytes: Bytes, cursor: inout Int) throws(CBORError) -> UInt64 {
        guard cursor + 8 <= bytes.count else { throw .truncated(needed: 8, available: bytes.count - cursor) }
        var v: UInt64 = 0
        for i in 0..<8 { v = (v << 8) | UInt64(bytes.storage[cursor + i]) }
        cursor += 8
        return v
    }

    private static func readBytes(_ bytes: Bytes, cursor: inout Int, length: Int) throws(CBORError) -> Bytes {
        guard cursor + length <= bytes.count else { throw .truncated(needed: length, available: bytes.count - cursor) }
        var out = Bytes(reservingCapacity: length)
        for i in 0..<length { out.append(bytes.storage[cursor + i]) }
        cursor += length
        return out
    }
}

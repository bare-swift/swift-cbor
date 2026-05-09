// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

import Testing
@testable import CBOR
import Bytes

private func bytes(_ raw: [UInt8]) -> Bytes {
    var b = Bytes(reservingCapacity: raw.count)
    for x in raw { b.append(x) }
    return b
}

private func raw(_ b: Bytes) -> [UInt8] { Array(b.storage) }

/// RFC 8949 Appendix A — canonical encoding test vectors.
@Suite("Encoder — RFC 8949 Appendix A")
struct EncoderAppendixATests {
    @Test("0 → 0x00")
    func zero() {
        #expect(raw(CBOR.encode(.uint(0))) == [0x00])
    }

    @Test("1 → 0x01")
    func one() {
        #expect(raw(CBOR.encode(.uint(1))) == [0x01])
    }

    @Test("23 → 0x17 (boundary of tiny uint)")
    func twentyThree() {
        #expect(raw(CBOR.encode(.uint(23))) == [0x17])
    }

    @Test("24 → 0x18 0x18 (uint8 follow-on)")
    func twentyFour() {
        #expect(raw(CBOR.encode(.uint(24))) == [0x18, 0x18])
    }

    @Test("100 → 0x18 0x64")
    func oneHundred() {
        #expect(raw(CBOR.encode(.uint(100))) == [0x18, 0x64])
    }

    @Test("1000 → 0x19 0x03 0xE8")
    func oneThousand() {
        #expect(raw(CBOR.encode(.uint(1000))) == [0x19, 0x03, 0xE8])
    }

    @Test("1_000_000 → 0x1A 0x00 0x0F 0x42 0x40")
    func oneMillion() {
        #expect(raw(CBOR.encode(.uint(1_000_000))) == [0x1A, 0x00, 0x0F, 0x42, 0x40])
    }

    @Test("1e12 → 0x1B 0x00 0x00 0x00 0xE8 0xD4 0xA5 0x10 0x00")
    func oneTrillion() {
        #expect(raw(CBOR.encode(.uint(1_000_000_000_000))) ==
                [0x1B, 0x00, 0x00, 0x00, 0xE8, 0xD4, 0xA5, 0x10, 0x00])
    }

    @Test("UInt64.max → 0x1B FF FF FF FF FF FF FF FF")
    func uintMax() {
        #expect(raw(CBOR.encode(.uint(UInt64.max))) ==
                [0x1B, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])
    }

    @Test("-1 (negative.0) → 0x20")
    func minusOne() {
        #expect(raw(CBOR.encode(.negative(0))) == [0x20])
    }

    @Test("-100 (negative.99) → 0x38 0x63")
    func minusOneHundred() {
        #expect(raw(CBOR.encode(.negative(99))) == [0x38, 0x63])
    }

    @Test("-2^64 (negative.UInt64.max) round-trips through extreme")
    func minusTwoToTheSixtyFour() {
        // Stored value is 2^64 - 1 = UInt64.max, representing -2^64.
        #expect(raw(CBOR.encode(.negative(UInt64.max))) ==
                [0x3B, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])
    }

    @Test("false → 0xF4")
    func boolFalse() {
        #expect(raw(CBOR.encode(.bool(false))) == [0xF4])
    }

    @Test("true → 0xF5")
    func boolTrue() {
        #expect(raw(CBOR.encode(.bool(true))) == [0xF5])
    }

    @Test("null → 0xF6")
    func null() {
        #expect(raw(CBOR.encode(.null)) == [0xF6])
    }

    @Test("undefined → 0xF7")
    func undefined() {
        #expect(raw(CBOR.encode(.undefined)) == [0xF7])
    }

    @Test("simple(16) → 0xF0")
    func simple16() {
        #expect(raw(CBOR.encode(.simple(16))) == [0xF0])
    }

    @Test("simple(255) → 0xF8 0xFF")
    func simple255() {
        #expect(raw(CBOR.encode(.simple(255))) == [0xF8, 0xFF])
    }

    @Test("float32 100000.0 → 0xFA 0x47 0xC3 0x50 0x00")
    func float32Value() {
        #expect(raw(CBOR.encode(.float32(100000.0))) == [0xFA, 0x47, 0xC3, 0x50, 0x00])
    }

    @Test("float64 1.1 → 0xFB 0x3F 0xF1 0x99 0x99 0x99 0x99 0x99 0x9A")
    func float64Value() {
        #expect(raw(CBOR.encode(.float64(1.1))) ==
                [0xFB, 0x3F, 0xF1, 0x99, 0x99, 0x99, 0x99, 0x99, 0x9A])
    }
}

@Suite("Encoder — strings, byte strings, containers")
struct EncoderCompositesTests {
    @Test("empty byte string → 0x40")
    func emptyByteString() {
        #expect(raw(CBOR.encode(.byteString(Bytes()))) == [0x40])
    }

    @Test("4-byte byte string → 0x44 + payload")
    func fourByteString() {
        #expect(raw(CBOR.encode(.byteString(bytes([0x01, 0x02, 0x03, 0x04])))) ==
                [0x44, 0x01, 0x02, 0x03, 0x04])
    }

    @Test("empty text string → 0x60")
    func emptyText() {
        #expect(raw(CBOR.encode(.textString(""))) == [0x60])
    }

    @Test("'a' text string → 0x61 0x61")
    func textA() {
        #expect(raw(CBOR.encode(.textString("a"))) == [0x61, 0x61])
    }

    @Test("'IETF' text string → 0x64 + payload")
    func textIETF() {
        #expect(raw(CBOR.encode(.textString("IETF"))) ==
                [0x64, 0x49, 0x45, 0x54, 0x46])
    }

    @Test("empty array → 0x80")
    func emptyArray() {
        #expect(raw(CBOR.encode(.array([]))) == [0x80])
    }

    @Test("[1, 2, 3] → 0x83 0x01 0x02 0x03")
    func array123() {
        let v = CBORValue.array([.uint(1), .uint(2), .uint(3)])
        #expect(raw(CBOR.encode(v)) == [0x83, 0x01, 0x02, 0x03])
    }

    @Test("empty map → 0xA0")
    func emptyMap() {
        #expect(raw(CBOR.encode(.map([]))) == [0xA0])
    }

    @Test("{1: 2, 3: 4} → 0xA2 0x01 0x02 0x03 0x04")
    func map12() {
        let v = CBORValue.map([
            .init(key: .uint(1), value: .uint(2)),
            .init(key: .uint(3), value: .uint(4)),
        ])
        #expect(raw(CBOR.encode(v)) == [0xA2, 0x01, 0x02, 0x03, 0x04])
    }

    @Test("tagged 0 (date string) → 0xC0 + inner")
    func tagged0() {
        let v = CBORValue.tagged(0, .textString("2013-03-21T20:04:00Z"))
        let bs = CBOR.encode(v)
        #expect(bs.storage[0] == 0xC0)
    }

    @Test("tag with 16-bit number → 0xD9 prefix")
    func tagBig() {
        let v = CBORValue.tagged(1000, .uint(0))
        let bs = CBOR.encode(v)
        #expect(bs.storage[0] == 0xD9)
        #expect(bs.storage[1] == 0x03)
        #expect(bs.storage[2] == 0xE8)
    }
}

@Suite("Decoder — primitives")
struct DecoderPrimitivesTests {
    @Test("tiny uints")
    func tinyUInts() throws {
        #expect(try CBOR.decode(bytes([0x00])) == .uint(0))
        #expect(try CBOR.decode(bytes([0x17])) == .uint(23))
    }

    @Test("uint8 / uint16 / uint32 / uint64 follow-ons")
    func uintLadder() throws {
        #expect(try CBOR.decode(bytes([0x18, 0x18])) == .uint(24))
        #expect(try CBOR.decode(bytes([0x19, 0x03, 0xE8])) == .uint(1000))
        #expect(try CBOR.decode(bytes([0x1A, 0x00, 0x0F, 0x42, 0x40])) == .uint(1_000_000))
        #expect(try CBOR.decode(bytes([0x1B, 0x00, 0x00, 0x00, 0xE8, 0xD4, 0xA5, 0x10, 0x00])) == .uint(1_000_000_000_000))
    }

    @Test("negative integers")
    func negatives() throws {
        #expect(try CBOR.decode(bytes([0x20])) == .negative(0))
        #expect(try CBOR.decode(bytes([0x38, 0x63])) == .negative(99))
    }

    @Test("simple values: false / true / null / undefined")
    func simpleValues() throws {
        #expect(try CBOR.decode(bytes([0xF4])) == .bool(false))
        #expect(try CBOR.decode(bytes([0xF5])) == .bool(true))
        #expect(try CBOR.decode(bytes([0xF6])) == .null)
        #expect(try CBOR.decode(bytes([0xF7])) == .undefined)
    }

    @Test("simple value extension (0xF8 0xFF)")
    func simple255() throws {
        #expect(try CBOR.decode(bytes([0xF8, 0xFF])) == .simple(255))
    }

    @Test("simple values 0..19 inline")
    func simpleInline() throws {
        // 0xE0 = 0b111_00000 = major 7, info 0 → simple(0)
        #expect(try CBOR.decode(bytes([0xE0])) == .simple(0))
        // 0xF0 = info 16 → simple(16)
        #expect(try CBOR.decode(bytes([0xF0])) == .simple(16))
    }

    @Test("float32 / float64")
    func floats() throws {
        #expect(try CBOR.decode(bytes([0xFA, 0x47, 0xC3, 0x50, 0x00])) == .float32(100000.0))
        #expect(try CBOR.decode(bytes([0xFB, 0x3F, 0xF1, 0x99, 0x99, 0x99, 0x99, 0x99, 0x9A])) == .float64(1.1))
    }

    @Test("float16 → float32 (lossless)")
    func float16() throws {
        // 0xF9 0x3C 0x00 is +1.0 in binary16.
        let decoded = try CBOR.decode(bytes([0xF9, 0x3C, 0x00]))
        #expect(decoded == .float32(1.0))
    }

    @Test("float16 zero")
    func float16Zero() throws {
        #expect(try CBOR.decode(bytes([0xF9, 0x00, 0x00])) == .float32(0.0))
    }

    @Test("float16 +Inf")
    func float16Inf() throws {
        let decoded = try CBOR.decode(bytes([0xF9, 0x7C, 0x00]))
        if case .float32(let f) = decoded {
            #expect(f.isInfinite && f > 0)
        } else {
            Issue.record("expected float32 infinity")
        }
    }
}

@Suite("Decoder — strings, byte strings, containers")
struct DecoderCompositesTests {
    @Test("byte string round-trip")
    func byteString() throws {
        #expect(try CBOR.decode(bytes([0x44, 0x01, 0x02, 0x03, 0x04])) ==
                .byteString(bytes([0x01, 0x02, 0x03, 0x04])))
    }

    @Test("text string 'IETF'")
    func textIETF() throws {
        #expect(try CBOR.decode(bytes([0x64, 0x49, 0x45, 0x54, 0x46])) == .textString("IETF"))
    }

    @Test("array [1, 2, 3]")
    func array123() throws {
        #expect(try CBOR.decode(bytes([0x83, 0x01, 0x02, 0x03])) ==
                .array([.uint(1), .uint(2), .uint(3)]))
    }

    @Test("nested array")
    func nestedArray() throws {
        // [1, [2, 3], [4, 5]] → 0x83 0x01 0x82 0x02 0x03 0x82 0x04 0x05
        let decoded = try CBOR.decode(bytes([0x83, 0x01, 0x82, 0x02, 0x03, 0x82, 0x04, 0x05]))
        #expect(decoded == .array([
            .uint(1),
            .array([.uint(2), .uint(3)]),
            .array([.uint(4), .uint(5)]),
        ]))
    }

    @Test("map {1:2, 3:4}")
    func mapEntries() throws {
        let decoded = try CBOR.decode(bytes([0xA2, 0x01, 0x02, 0x03, 0x04]))
        #expect(decoded == .map([
            .init(key: .uint(1), value: .uint(2)),
            .init(key: .uint(3), value: .uint(4)),
        ]))
    }

    @Test("tagged 0 + RFC 3339 text")
    func tagged0() throws {
        // 0xC0 + 0x74 + "2013-03-21T20:04:00Z" (20 chars)
        var v: [UInt8] = [0xC0, 0x74]
        v.append(contentsOf: Array("2013-03-21T20:04:00Z".utf8))
        let decoded = try CBOR.decode(bytes(v))
        #expect(decoded == .tagged(0, .textString("2013-03-21T20:04:00Z")))
    }
}

@Suite("Decoder — error paths")
struct DecoderErrorTests {
    @Test("indefinite-length byte string → unsupported")
    func indefiniteByteString() {
        #expect(throws: CBORError.indefiniteLengthUnsupported) {
            try CBOR.decode(bytes([0x5F, 0xFF]))
        }
    }

    @Test("indefinite-length array → unsupported")
    func indefiniteArray() {
        #expect(throws: CBORError.indefiniteLengthUnsupported) {
            try CBOR.decode(bytes([0x9F, 0xFF]))
        }
    }

    @Test("0xFF break outside indefinite → unexpectedBreak")
    func breakAlone() {
        #expect(throws: CBORError.unexpectedBreak) {
            try CBOR.decode(bytes([0xFF]))
        }
    }

    @Test("simple value 24 (with 0xF8 prefix) → reservedAdditionalInfo")
    func reservedSimple() {
        #expect(throws: CBORError.reservedAdditionalInfo(24)) {
            try CBOR.decode(bytes([0xF8, 0x18]))
        }
    }

    @Test("major-type-0 with reserved info=28 → reservedAdditionalInfo")
    func reservedInfo28() {
        // 0x00 | 0x1C = 0x1C; major type 0, info 28 reserved.
        #expect(throws: CBORError.reservedAdditionalInfo(28)) {
            try CBOR.decode(bytes([0x1C]))
        }
    }

    @Test("truncated uint16 → truncated")
    func truncated() {
        #expect(throws: (any Error).self) {
            try CBOR.decode(bytes([0x19, 0x03]))
        }
    }

    @Test("trailing bytes after valid value → trailingBytes")
    func trailingBytes() {
        #expect(throws: (any Error).self) {
            try CBOR.decode(bytes([0x00, 0x00]))
        }
    }

    @Test("invalid UTF-8 in text string → invalidUTF8")
    func invalidUTF8() {
        // 0x62 (text len 2) 0xC0 0x28 — 0xC0 is not a valid UTF-8 lead.
        #expect(throws: CBORError.invalidUTF8) {
            try CBOR.decode(bytes([0x62, 0xC0, 0x28]))
        }
    }
}

@Suite("Round-trip")
struct RoundTripTests {
    @Test("nested mixed-types map")
    func mixed() throws {
        let original = CBORValue.map([
            .init(key: .textString("name"), value: .textString("alice")),
            .init(key: .textString("age"), value: .uint(30)),
            .init(key: .textString("tags"), value: .array([.textString("a"), .textString("b")])),
            .init(key: .textString("score"), value: .float64(95.5)),
            .init(key: .textString("blob"), value: .byteString(bytes([0xDE, 0xAD]))),
            .init(key: .textString("null"), value: .null),
            .init(key: .textString("flag"), value: .bool(true)),
        ])
        let decoded = try CBOR.decode(CBOR.encode(original))
        #expect(decoded == original)
    }

    @Test("non-string map keys preserve")
    func nonStringKeys() throws {
        let original = CBORValue.map([
            .init(key: .uint(1), value: .textString("one")),
            .init(key: .uint(2), value: .textString("two")),
        ])
        let decoded = try CBOR.decode(CBOR.encode(original))
        #expect(decoded == original)
    }

    @Test("Unicode text string")
    func unicode() throws {
        let s = "héllo, 世界 🎉"
        #expect(try CBOR.decode(CBOR.encode(.textString(s))) == .textString(s))
    }

    @Test("tagged value (URI tag = 32)")
    func taggedURI() throws {
        let original = CBORValue.tagged(32, .textString("https://example.com"))
        #expect(try CBOR.decode(CBOR.encode(original)) == original)
    }

    @Test("extreme negative -2^64 round-trip")
    func extremeNegative() throws {
        let original = CBORValue.negative(UInt64.max)
        #expect(try CBOR.decode(CBOR.encode(original)) == original)
    }

    @Test("large array (>23 → uint8 follow-on)")
    func largeArray() throws {
        let xs: [CBORValue] = (0..<50).map { .uint(UInt64($0)) }
        let original = CBORValue.array(xs)
        let encoded = CBOR.encode(original)
        // Major type 4 (0x80) + info 24 (0x18) = 0x98 leading byte, then count.
        #expect(encoded.storage.first == 0x98)
        #expect(encoded.storage[1] == 50)
        #expect(try CBOR.decode(encoded) == original)
    }
}

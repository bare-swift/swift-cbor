// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

import Testing
@testable import CBOR
import Time

@Suite("Date integration with swift-time")
struct DateTests {
    @Test("dateString emits tag 0 + RFC 3339 text")
    func tag0Shape() throws {
        let i = try Time.RFC3339.parse("2026-05-10T07:30:00Z").toInstant()
        let v = CBORValue.dateString(i)
        guard case .tagged(let tag, let inner) = v else { Issue.record(); return }
        #expect(tag == 0)
        #expect(inner == .textString("2026-05-10T07:30:00Z"))
    }

    @Test("dateEpoch emits tag 1 + uint for whole-second positive")
    func tag1Uint() throws {
        let i = try Time.RFC3339.parse("2026-05-10T07:30:00Z").toInstant()
        let v = CBORValue.dateEpoch(i)
        guard case .tagged(let tag, let inner) = v else { Issue.record(); return }
        #expect(tag == 1)
        if case .uint(let n) = inner {
            #expect(Int64(n) == i.nanosecondsSinceEpoch / 1_000_000_000)
        } else {
            Issue.record("expected uint")
        }
    }

    @Test("dateEpoch emits tag 1 + negative for pre-epoch whole-second")
    func tag1Negative() {
        // 1969-12-31T23:59:59Z = -1 second.
        let i = Time.Instant(nanosecondsSinceEpoch: -1_000_000_000)
        let v = CBORValue.dateEpoch(i)
        if case .tagged(1, .negative(let mag)) = v {
            #expect(mag == 0)  // wire-form magnitude for -1 is 0
        } else {
            Issue.record("expected tag 1 negative")
        }
    }

    @Test("dateEpoch emits tag 1 + float64 for sub-second")
    func tag1Float() {
        let i = Time.Instant(nanosecondsSinceEpoch: 1_500_000_000)  // 1.5 sec
        let v = CBORValue.dateEpoch(i)
        if case .tagged(1, .float64(let d)) = v {
            #expect(d == 1.5)
        } else {
            Issue.record("expected tag 1 float64")
        }
    }

    @Test("asDate parses tag 0 RFC 3339")
    func asDateTag0() throws {
        let i = try Time.RFC3339.parse("2026-05-10T07:30:00Z").toInstant()
        let v = CBORValue.dateString(i)
        #expect(v.asDate == i)
    }

    @Test("asDate parses tag 1 uint")
    func asDateTag1Uint() {
        let i = Time.Instant(nanosecondsSinceEpoch: 1_700_000_000_000_000_000)
        let v = CBORValue.dateEpoch(i)
        #expect(v.asDate == i)
    }

    @Test("asDate parses tag 1 negative")
    func asDateTag1Negative() {
        let i = Time.Instant(nanosecondsSinceEpoch: -1_000_000_000)
        let v = CBORValue.dateEpoch(i)
        #expect(v.asDate == i)
    }

    @Test("asDate parses tag 1 float64")
    func asDateTag1Float() {
        let i = Time.Instant(nanosecondsSinceEpoch: 1_500_000_000)
        let v = CBORValue.dateEpoch(i)
        #expect(v.asDate == i)
    }

    @Test("asDate returns nil for non-date tags")
    func asDateNonDate() {
        let v = CBORValue.tagged(32, .textString("https://example.com"))  // tag 32 = URI
        #expect(v.asDate == nil)
    }

    @Test("asDate returns nil for non-tagged values")
    func asDateNonTagged() {
        #expect(CBORValue.uint(42).asDate == nil)
        #expect(CBORValue.textString("hello").asDate == nil)
    }

    @Test("CBOR.encode + decode preserves tag-0 date round-trip")
    func wireRoundTripTag0() throws {
        let i = try Time.RFC3339.parse("2026-05-10T07:30:00Z").toInstant()
        let original = CBORValue.dateString(i)
        let bytes = CBOR.encode(original)
        let decoded = try CBOR.decode(bytes)
        #expect(decoded.asDate == i)
    }

    @Test("CBOR.encode + decode preserves tag-1 epoch round-trip")
    func wireRoundTripTag1() {
        let i = Time.Instant(nanosecondsSinceEpoch: 1_700_000_000_000_000_000)
        let original = CBORValue.dateEpoch(i)
        let bytes = CBOR.encode(original)
        if let decoded = (try? CBOR.decode(bytes)) {
            #expect(decoded.asDate == i)
        } else {
            Issue.record("decode failed")
        }
    }
}

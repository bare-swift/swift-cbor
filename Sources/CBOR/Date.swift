// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import Bytes
import Time

/// CBOR date/time integration with swift-time. Per RFC 8949 § 3.4:
///
/// - **Tag 0** wraps a text-form RFC 3339 datetime string.
/// - **Tag 1** wraps a numeric epoch — integer seconds, or a floating-point
///   value with sub-second precision.
extension CBORValue {
    /// Build a CBOR tag-0 (RFC 3339 string) value from a `Time.Instant`.
    /// Sub-nanosecond precision is preserved in the serialized text.
    public static func dateString(_ instant: Time.Instant) -> CBORValue {
        let cal = Time.Calendar.from(instant, offsetSeconds: 0)
        let text = Time.RFC3339.serialize(cal)
        return .tagged(0, .textString(text))
    }

    /// Build a CBOR tag-1 (epoch) value from a `Time.Instant`. Emits an
    /// integer if the instant is whole-seconds; otherwise emits a double
    /// with the sub-second component encoded as a fraction. (Sub-nanosecond
    /// precision is lost on the float path; use ``dateString(_:)`` if you
    /// need exactness.)
    public static func dateEpoch(_ instant: Time.Instant) -> CBORValue {
        var seconds = instant.nanosecondsSinceEpoch / 1_000_000_000
        var nanos = instant.nanosecondsSinceEpoch - seconds * 1_000_000_000
        if nanos < 0 {
            nanos += 1_000_000_000
            seconds -= 1
        }
        if nanos == 0 {
            // Whole-second integer encoding.
            if seconds >= 0 {
                return .tagged(1, .uint(UInt64(seconds)))
            } else {
                // CBOR negative integers store `-1 - n` as the wire magnitude.
                let mag = UInt64(bitPattern: -seconds - 1)
                return .tagged(1, .negative(mag))
            }
        }
        // Sub-second; use float64 with seconds.fractional.
        let asDouble = Double(seconds) + Double(nanos) / 1_000_000_000.0
        return .tagged(1, .float64(asDouble))
    }

    /// If this value is a CBOR date — tag 0 (RFC 3339 text) or tag 1
    /// (epoch number) — return the equivalent `Time.Instant`. Returns
    /// `nil` for non-date values or for tag-0 strings that don't parse
    /// as RFC 3339.
    public var asDate: Time.Instant? {
        guard case .tagged(let tag, let inner) = self else { return nil }
        switch tag {
        case 0:
            guard case .textString(let s) = inner else { return nil }
            return try? Time.RFC3339.parse(s).toInstant()
        case 1:
            switch inner {
            case .uint(let s):
                return Time.Instant(nanosecondsSinceEpoch: Int64(s) * 1_000_000_000)
            case .negative(let mag):
                let seconds = -1 - Int64(mag)
                return Time.Instant(nanosecondsSinceEpoch: seconds * 1_000_000_000)
            case .float64(let d):
                let totalNanos = d * 1_000_000_000
                return Time.Instant(nanosecondsSinceEpoch: Int64(totalNanos))
            case .float32(let f):
                let totalNanos = Double(f) * 1_000_000_000
                return Time.Instant(nanosecondsSinceEpoch: Int64(totalNanos))
            default:
                return nil
            }
        default:
            return nil
        }
    }
}

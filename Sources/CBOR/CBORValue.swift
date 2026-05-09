// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import Bytes

/// A parsed CBOR value. Mirrors RFC 8949 § 3's major-type taxonomy.
///
/// - ``negative(_:)`` stores the wire-form magnitude. CBOR encodes a
///   negative integer `n < 0` as the unsigned wire value `-1 - n`. So
///   `-1` is stored as `0`, `-2` as `1`, `-2^64` as `UInt64.max`. To
///   reconstruct: `let n = -1 - Int128(storedValue)` (or recognize the
///   value can exceed `Int64.min` and handle accordingly).
/// - ``map(_:)`` is an ordered list of ``MapEntry`` values; CBOR keys
///   may be any value type, so a `[CBORValue: CBORValue]` would lose
///   information.
/// - ``simple(_:)`` carries simple-value codes that are not standard
///   booleans / null / undefined / floats. Codes 24..31 are reserved
///   per RFC 8949 § 3.3.
public indirect enum CBORValue: Sendable, Equatable {
    case uint(UInt64)
    case negative(UInt64)
    case byteString(Bytes)
    case textString(String)
    case array([CBORValue])
    case map([MapEntry])
    case tagged(UInt64, CBORValue)
    case bool(Bool)
    case null
    case undefined
    case simple(UInt8)
    case float32(Float)
    case float64(Double)

    public struct MapEntry: Sendable, Equatable {
        public var key: CBORValue
        public var value: CBORValue

        public init(key: CBORValue, value: CBORValue) {
            self.key = key
            self.value = value
        }
    }
}

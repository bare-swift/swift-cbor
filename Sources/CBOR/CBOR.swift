// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import Bytes

/// Sendable, Foundation-free CBOR encoder + decoder per
/// [RFC 8949](https://www.rfc-editor.org/rfc/rfc8949.html).
///
/// `CBOR.encode(_:)` round-trips a ``CBORValue`` to `Bytes`;
/// `CBOR.decode(_:)` parses `Bytes` back into a ``CBORValue``.
///
/// Negative-integer fidelity is preserved by storing the wire-form
/// magnitude in ``CBORValue/negative(_:)`` (the actual integer is
/// `-1 - storedValue`); CBOR can express negative integers down to
/// `-2^64`, exceeding `Int64.min`.
public enum CBOR: Sendable {
    /// Encode a ``CBORValue`` to its CBOR wire form.
    public static func encode(_ value: CBORValue) -> Bytes {
        var out = Bytes(reservingCapacity: 32)
        Encoder.encode(value, into: &out)
        return out
    }

    /// Decode CBOR-encoded `Bytes` into a ``CBORValue``.
    public static func decode(_ bytes: Bytes) throws(CBORError) -> CBORValue {
        var cursor = 0
        let value = try Decoder.decode(bytes, cursor: &cursor)
        if cursor != bytes.count {
            throw .trailingBytes(consumed: cursor, total: bytes.count)
        }
        return value
    }
}

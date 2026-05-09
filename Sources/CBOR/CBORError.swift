// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

/// Errors thrown by ``CBOR/decode(_:)``.
public enum CBORError: Error, Equatable, Sendable {
    /// Decoder ran out of bytes mid-message.
    case truncated(needed: Int, available: Int)

    /// The leading byte's "additional info" was 28..30 (reserved per
    /// RFC 8949 § 3) or — for major type 7 — was 24 with a value < 32
    /// (which RFC 8949 § 3.3 reserves for the standard simple values).
    case reservedAdditionalInfo(UInt8)

    /// Indefinite-length encoding (additional info = 31). Recognised on
    /// the wire but not supported in v0.1; defer to a later release.
    case indefiniteLengthUnsupported

    /// `0xFF` "break" stop code encountered outside an indefinite-length
    /// container.
    case unexpectedBreak

    /// A `textString` payload was not valid UTF-8.
    case invalidUTF8

    /// Decoder finished a value but the input had more bytes after it.
    case trailingBytes(consumed: Int, total: Int)
}

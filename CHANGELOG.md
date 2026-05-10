# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.2.0] - 2026-05-10

### Added
- `CBORValue.dateString(_ instant: Time.Instant) -> CBORValue` — build a CBOR tag-0 (RFC 3339 string) value from a `Time.Instant`. Sub-nanosecond precision preserved via the serialized text.
- `CBORValue.dateEpoch(_ instant: Time.Instant) -> CBORValue` — build a CBOR tag-1 (epoch number) value. Whole seconds emit as `uint` / `negative` integers; sub-second emit as `float64`.
- `CBORValue.asDate: Time.Instant?` — decode tag-0 / tag-1 values into a `Time.Instant`. Handles all four inner forms (uint, negative, float32, float64) for tag 1; round-trips RFC 3339 text via `swift-time` for tag 0.
- 12 new tests covering encode shapes, all four tag-1 inner-value forms, asDate getters, full `CBOR.encode → decode` round-trips, and rejection of non-date tags.

### Dependencies
- New: `swift-time` 0.1.0 — for the `Time.Instant` type used by the date helpers.

### Migration
- Additive only. v0.1 consumers continue to work unchanged. `CBORValue.tagged(0, .textString(...))` and `CBORValue.tagged(1, ...)` still round-trip raw; the new helpers and `asDate` getter are available alongside for opt-in adoption.

## [0.1.0] - 2026-05-09

### Added
- `CBORValue` value type (Sendable, Equatable) covering RFC 8949's 8 major types and standard major-7 simple values: `uint`, `negative`, `byteString`, `textString`, `array`, `map` (ordered, any-keyed entries via `MapEntry`), `tagged`, `bool`, `null`, `undefined`, `simple`, `float32`, `float64`.
- `CBOR.encode(_:) -> Bytes` — encoder that picks the shortest length-encoding for each value per RFC 8949's "preferred serialization" rule.
- `CBOR.decode(_:) throws(CBORError) -> CBORValue` — recursive-descent decoder over the major-type / additional-info schema; strict RFC 3629 UTF-8 validation; lossless half-precision float (`float16` → `Float`) decoding; rejects reserved additional-info bits, indefinite-length forms, and unexpected break stop codes.
- `CBORError` typed-throws enum (`truncated`, `reservedAdditionalInfo`, `indefiniteLengthUnsupported`, `unexpectedBreak`, `invalidUTF8`, `trailingBytes`).
- Negative-integer fidelity preserved across the full CBOR range (`-2^64..-1`) by storing the wire magnitude in `.negative(_:)`.

### Dependencies
- `swift-bytes` 0.1.0 — input/output buffer.

### Limitations (out of scope for v0.1)
- `Codable` bridging — deliberately excluded; Foundation-free + non-Codable is the differentiator.
- Indefinite-length encodings (byte strings, text strings, arrays, maps). Recognized at decode time but rejected. Defer to v0.2.
- Canonical / deterministic encoding (RFC 8949 § 4.2). Encoder produces *valid* CBOR; canonical-form output (sorted map keys, etc.) is v0.2.
- CBOR Sequences (RFC 8742). Single-payload only in v0.1.
- Tag *semantics* (interpreting tag-0 as RFC 3339, tag-1 as epoch, tag-32 as URI, etc.). Tags pass through with raw inner value; consumers wire to a date type when one lands (RFC-0010).
- COSE (RFC 9052). Its own package.

# swift-cbor

RFC 8949 CBOR encoder + decoder — Sendable, Foundation-free; outputs `Bytes` for wire use.

Part of the [bare-swift](https://github.com/bare-swift) ecosystem.

## Install

Add to your `Package.swift`:

```swift
.package(url: "https://github.com/bare-swift/swift-cbor.git", from: "0.1.0")
```

Then depend on the `CBOR` product:

```swift
.product(name: "CBOR", package: "swift-cbor")
```

## Usage

```swift
import CBOR
import Bytes

let value = CBORValue.map([
    .init(key: .textString("name"), value: .textString("alice")),
    .init(key: .textString("age"),  value: .uint(30)),
    .init(key: .textString("uri"),  value: .tagged(32, .textString("https://example.com"))),
])

let bytes: Bytes = CBOR.encode(value)
let parsed = try CBOR.decode(bytes)
// parsed == value
```

## Scope

`swift-cbor` ships v0.1 with:

- `CBORValue` value type covering RFC 8949's 8 major types plus the standard major-7 simple values: `uint`, `negative`, `byteString`, `textString`, `array`, `map` (ordered, any-keyed entries), `tagged`, `bool`, `null`, `undefined`, `simple`, `float32`, `float64`.
- `CBOR.encode(_:) -> Bytes` — picks the shortest length-encoding for each value (RFC 8949 "preferred serialization").
- `CBOR.decode(_:) throws(CBORError) -> CBORValue` — recursive-descent decoder; strict UTF-8 validation; lossless float16 → `float32` decoding; reserved additional-info bits and unexpected break stop codes are reported via `CBORError`.
- `CBORError` typed-throws enum (`truncated`, `reservedAdditionalInfo`, `indefiniteLengthUnsupported`, `unexpectedBreak`, `invalidUTF8`, `trailingBytes`).
- Negative-integer fidelity preserved across the full CBOR range (`-2^64..-1`) by storing the wire magnitude in `.negative(_:)`.

Out of scope for v0.1:

- `Codable` bridging — deliberately excluded; Foundation-free + non-Codable is the differentiator.
- Indefinite-length encodings (byte strings, text strings, arrays, maps). Recognized at decode time but rejected with `.indefiniteLengthUnsupported`. Defer to v0.2.
- Canonical / deterministic encoding (RFC 8949 § 4.2). Encoder produces *valid* CBOR; canonical-form output (sorted map keys, etc.) is v0.2.
- CBOR Sequences (RFC 8742). Single-payload only in v0.1.
- COSE (RFC 9052). Its own package.
- Tag *semantics* (e.g. interpreting tag-0 as RFC 3339 datetime, tag-1 as epoch, tag-32 as URI). Tags pass through with their raw inner value; consumers wire to a date type when one lands (RFC-0010).

## Documentation

Full DocC documentation: <https://bare-swift.github.io/swift-cbor/>

## Source

No upstream Rust crate; this is a native bare-swift package implementing RFC 8949 directly.

## License

Apache 2.0 with LLVM exception. See [LICENSE](./LICENSE) and [NOTICE](./NOTICE).

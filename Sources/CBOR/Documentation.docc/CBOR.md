# ``CBOR``

RFC 8949 CBOR encoder + decoder — Sendable, Foundation-free.

## Overview

`CBOR` parses and serializes the Concise Binary Object Representation
([RFC 8949](https://www.rfc-editor.org/rfc/rfc8949.html)) without
relying on Foundation or `Codable`. Input and output are `Bytes`.

The encoder picks the shortest length-encoding for each value (tiny /
1-byte / 2-byte / 4-byte / 8-byte) per the RFC's "preferred
serialization" rule. The decoder accepts every defined major type +
additional-info combination, decodes half-precision floats losslessly
to `Float`, validates UTF-8 strictly on text strings, and rejects
indefinite-length forms (deferred to v0.2).

Negative-integer fidelity is preserved by storing the wire-form
magnitude in ``CBORValue/negative(_:)`` — CBOR can express integers
down to `-2^64`, which exceeds `Int64.min`.

```swift
import CBOR
import Bytes

let value = CBORValue.map([
    .init(key: .textString("name"), value: .textString("alice")),
    .init(key: .textString("age"),  value: .uint(30)),
])

let bytes: Bytes = CBOR.encode(value)
let parsed = try CBOR.decode(bytes)        // round-trips
```

## Topics

### Essentials

- ``CBORValue``
- ``CBORError``

# peptide_kit (Dart)

A port of `App/Sources/PeptideKit` — the Swift domain core — to pure Dart, for the
Android build.

**SwiftUI/Swift is the source of truth.** This package TRANSLATES the Swift core and
must never lead it. When the Swift changes, port the change; do not invent behaviour
here. Every value and rule below was read out of the Swift, and the tests are ports of
`App/Tests/PeptideKitTests`, not fresh inventions — that is what makes the two provably
equivalent rather than merely similar.

## Why this layer first

It is the one Android investment that cannot go stale: no UI, no platform APIs, and it
is where a silent error is a dosing-safety problem rather than a cosmetic one.

## Verify

```sh
cd AndroidApp/peptide_kit
dart pub get
dart test          # ports of the Swift swift-testing suites
dart run tool/pk_verify.dart   # port of `swift run pk-verify`
```

## Canonical invariant

Everything internal is stored in **micrograms**. Peptide doses span mcg (research
peptides) to mg (GLP-1s); one base unit keeps conversion and comparison unambiguous.

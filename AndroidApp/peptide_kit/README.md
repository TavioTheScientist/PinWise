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
dart analyze --fatal-infos                        # must be clean
dart format --output=none --set-exit-if-changed . # must be idempotent
dart run tool/pk_verify.dart                      # port of `swift run pk-verify`
dart test                                         # ports of the swift-testing suites
```

CI runs exactly that sequence as the **"Domain core (Dart port)"** job — ubuntu, 1× minutes, no
simulator, which is the whole reason this layer was ported before any UI.

### The harness check count is a tracked number

`swift run pk-verify` reports **241/241**. `tool/pk_verify.dart` is its port and prints its own
count, so a section quietly going missing is visible rather than invisible. Two rules:

- **Never adjust an assertion to make it pass.** If Dart disagrees with Swift, that is a finding
  about the port, not a number to edit.
- When you add a ported module, add its harness section too. The trailing comment in
  `tool/pk_verify.dart` lists what is still outstanding and what it should total.

## Dependencies

`intl` only, and it earns its place: `DoseDuePhrase` must format a weekday and a month/day the way
the LOCALE wants, because Swift builds those from a locale-agnostic template. Without it the port is
en-US-only and silently wrong elsewhere — "Aug 12" renders backwards in most of the world. `intl` is
pure Dart, so the package still verifies on a bare VM in CI.

## Canonical invariant

Everything internal is stored in **micrograms**. Peptide doses span mcg (research
peptides) to mg (GLP-1s); one base unit keeps conversion and comparison unambiguous.

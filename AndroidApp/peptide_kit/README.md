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
is where a silent error is a dosing-safety problem rather than a cosmetic one. Screen
translation is on hold until SwiftUI stops moving; this layer isn't, because UI churn
cannot invalidate it.

**It lives here, under version control, and not inside a Flutter scaffold.** The old `FlutterApp/`
directory was untracked, and the Dart source that once sat in it was lost and unrecoverable before
being deleted outright; keeping this package in `AndroidApp/` with 62 tracked files is the reason
the same thing cannot happen twice. Tracked source must never sit somewhere that may be `rm -rf`'d.
When a Flutter app is eventually built, it depends on this package — it does not absorb it.

## Verify

```sh
cd AndroidApp/peptide_kit
dart pub get
dart analyze --fatal-infos                        # must be clean
dart format --output=none --set-exit-if-changed . # must be idempotent
dart run tool/pk_verify.dart                      # 273 checks, 0 failure(s)
dart test                                         # 192 tests, ports of the swift-testing suites
```

CI runs exactly that sequence, in that order, as the **"Domain core (Dart port)"** job — ubuntu,
1× minutes, no simulator, which is the whole reason this layer was ported before any UI. The SDK
is pinned to the `stable` channel rather than a patch version: the package declares `sdk: ^3.9.0`
and an exact pin breaks whenever that build is retired.

## What's ported

Everything: `Units`, all 11 `Models/`, `Safety/`, `TrialWindow`/`Entitlement`, `Citation`, all 10
calculators, `CompoundCatalog` (57 entries) + `CompoundProfiles` (57 profiles), `BlendPresets`,
`TitrationTemplates`, `NewsFeed`, `ReviewPrompt`.

### The property to preserve is label-for-label parity, not a matching total

Both harnesses currently emit **273 checks**. That number is the visible symptom; the actual
guarantee is stronger. `swift run pk-verify` and `dart run tool/pk_verify.dart` emit the **same
check labels, in the same order, across the same sections** — extracting the label from each check
line of both and diffing them yields zero differences in either direction. The only textual
difference between the two outputs is the summary line's wording:

```
✅ PASS — 273/273 checks passed     # Swift
273 checks, 0 failure(s)            # Dart
```

Matching counts alone would prove only that both sides assert 273 *things*. Matching labels in
matching order proves they assert **the same** things. That is what makes the two provably
equivalent rather than merely similarly sized, and it is the property to protect.

Three rules follow:

- **Never adjust an assertion to make it pass.** If Dart disagrees with Swift, that is a finding
  about the port, not a number to edit.
- **A new check on one side needs the identically-labelled check on the other**, in the same
  position. Otherwise the diff stops being meaningful and the count becomes the only signal again.
- When you port a module, port its harness section too. The trailing comment in
  `tool/pk_verify.dart` lists what is outstanding and what it should total.

Verify parity directly rather than trusting the totals:

```sh
# from the repo root
swift run --package-path App pk-verify | grep -E '^\s+[✓✗]' | sed 's/^[[:space:]]*[✓✗] //' > /tmp/swift.txt
(cd AndroidApp/peptide_kit && dart run tool/pk_verify.dart) | grep -E '^\s+[✓✗]' | sed 's/^[[:space:]]*[✓✗] //' > /tmp/dart.txt
diff /tmp/swift.txt /tmp/dart.txt   # must be empty
```

## Dependencies

Two runtime dependencies, both pure Dart — no Flutter, so the package still verifies on a bare VM
in CI.

**`intl`** — `DoseDuePhrase` must format a weekday and a month/day the way the **locale** wants,
because Swift builds those from a locale-agnostic template
(`setLocalizedDateFormatFromTemplate`). Dart's core libraries cannot do that, so without `intl` the
port is en-US-only and silently wrong everywhere else: "Aug 12" renders backwards in most of the
world.

**`decimal`** — **money is never a `double`.** The Swift core is explicit about it: `Vial.cost` and
`InventoryProjection.costPerDose` are `Decimal`, and `SDModels.swift` states the rule outright.
Binary floating point cannot represent 0.10, so a cost-per-dose built from doubles drifts and
compares unequal to the value the user typed. It serializes as a **string** — a JSON number would
launder it straight back into a `double`.

One residue worth knowing: `costPerDose` inherits imprecision from `exactDoses`, which is a mass
**ratio** and a `double` on *both* platforms (Swift does `Decimal(exactDoses)` from the same
value). So `100 / 3.333…` is `29.9999999999999985`, not 30, on both sides. `Decimal` fixes the
money, not the ratio — and the two platforms agree, which is what matters here.

## Canonical invariant

Everything internal is stored in **micrograms**. Peptide doses span mcg (research
peptides) to mg (GLP-1s); one base unit keeps conversion and comparison unambiguous.

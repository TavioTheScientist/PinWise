/// Small helpers the ported *models* need and that Swift got from the language or
/// Foundation for free. Not part of the public surface.
///
/// - [newUuid] stands in for Swift's `UUID()`, which every model uses as an `id`
///   default. Dart has no built-in UUID and this port may not add a dependency, so the
///   generator lives here.
/// - [listEquals] stands in for the synthesized `Hashable`/`Equatable` conformance Swift
///   gives a struct with `Array` properties. Dart's `==` on `List` is identity, so a
///   hand-written `operator ==` must compare element-wise or two equal-valued models
///   would compare unequal.
library;

import 'dart:math';

final Random _random = Random.secure();

/// A random RFC 4122 version-4 UUID in Swift's exact textual form: 8-4-4-4-12 hex,
/// **uppercase**.
///
/// Uppercase is deliberate, not cosmetic: Foundation encodes a `UUID` through `Codable`
/// as `uuidString`, which is uppercase, so this is the form that round-trips byte-for-byte
/// with the iOS build. (`UUID(uuidString:)` accepts either case on the way back in, so
/// decoding lowercase ids written elsewhere still works.)
String newUuid() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0F) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3F) | 0x80; // variant 10xx
  final hex = bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Element-wise list equality, for models whose Swift counterpart is `Hashable`.
bool listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

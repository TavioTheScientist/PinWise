// Port of the "News feed" section of App/Sources/pk-verify/main.swift — 19 checks, and the
// ONLY spec that exists for this file (there is no swift-testing suite for NewsFeed). Every
// assertion in the first group is one-for-one with a Swift `check(...)`, same inputs and same
// expected values. The second group is additive: it pins the JSON WIRE CONTRACT, because the
// app fetches `feed.json` from a public repo at runtime, so a key name or an optionality that
// drifts from the Swift breaks the News tab against a document neither side controls.
import 'dart:convert';
import 'dart:math';

import 'package:peptide_kit/peptide_kit.dart';
import 'package:test/test.dart';

/// Swift: `ISO8601DateFormatter().date(from: "2026-07-11T00:00:00Z")!` — the fixed `asOf` the
/// pk-verify ranking checks use so the order is deterministic.
final DateTime rankAsOf = DateTime.utc(2026, 7, 11);

/// The minimal item the pk-verify `listText` checks build in Swift.
NewsItem plainItem({
  required String id,
  String summary = 'Full summary body.',
  String? teaser,
}) => NewsItem(
  id: id,
  headline: 'H',
  summary: summary,
  category: NewsCategory.general,
  compounds: const [],
  sources: const [],
  publishedAt: '2026-07-08T00:00:00Z',
  popularity: 0,
  isMajorUpdate: false,
  disclaimer: 'd',
  teaser: teaser,
);

void main() {
  group('News feed contract (pk-verify)', () {
    // The Swift wraps the whole section in `do { … } catch { check(false, "news feed failed to
    // decode") }` — the 19th check. A throwing fixture is the single worst failure here, so it
    // is asserted first and on its own.
    test('the bundled sample feed decodes at all', () {
      expect(NewsFeed.decodeSample, returnsNormally);
    });

    final feed = NewsFeed.decodeSample();

    test('sample feed decodes 37 items', () {
      expect(feed.items.length, 37);
    });

    test('trending sorted by popularity', () {
      expect(
        feed.trending.first.popularity,
        feed.items.map((i) => i.popularity).reduce(max),
      );
    });

    test('ranked returns every item, newest+popular first', () {
      // Default feed order = blended recency + popularity (fixed asOf for determinism).
      final ranked = feed.ranked(asOf: rankAsOf);
      expect(ranked.length, feed.items.length);
      expect(ranked.first.id, 'fda-bpc157-pcac-2026-07');
    });

    test('recency lifts a newer story above an older, more-popular one', () {
      final ranked = feed.ranked(asOf: rankAsOf);
      // pop 70, 2026-05 vs pop 96, 2023-06.
      final recentIdx = ranked.indexWhere(
        (i) => i.id == 'bpc157-evidence-review-2026',
      );
      final oldPopularIdx = ranked.indexWhere(
        (i) => i.id == 'reta-phase2-obesity-2023',
      );
      expect(recentIdx, greaterThanOrEqualTo(0));
      expect(oldPopularIdx, greaterThanOrEqualTo(0));
      expect(recentIdx, lessThan(oldPopularIdx));
    });

    test('can filter items by compound', () {
      expect(feed.itemsMentioning('Retatrutide'), isNotEmpty);
    });

    test('5 items flagged as major updates', () {
      expect(feed.majorUpdates.length, 5);
    });

    // Editorial contract — the transparency guarantees, enforced in code.
    test('EVERY item carries >=1 source citation, and every source a URL', () {
      expect(feed.items.every((i) => i.sources.isNotEmpty), isTrue);
      expect(
        feed.items.every((i) => i.sources.every((s) => s.url.isNotEmpty)),
        isTrue,
      );
    });

    test('EVERY item carries a disclaimer', () {
      expect(feed.items.every((i) => i.disclaimer.isNotEmpty), isTrue);
    });

    test('every item has a stable id, and ids are unique', () {
      expect(feed.items.every((i) => i.id.isNotEmpty), isTrue);
      expect(feed.items.map((i) => i.id).toSet().length, feed.items.length);
    });

    test('EVERY item carries a teaser, <=180 chars', () {
      // Editorial: every item ships a crafted, scannable teaser (drives list/card copy),
      // a complete sentence that is never cropped.
      expect(feed.items.every((i) => i.teaser != null), isTrue);
      expect(feed.items.every((i) => (i.teaser?.length ?? 0) <= 180), isTrue);
    });

    test('sample omits imageURL (uses gradient fallback)', () {
      // The bundled sample omits imageURL app-wide — the branded-gradient fallback is the
      // premium look.
      expect(feed.items.every((i) => i.imageURL == null), isTrue);
    });

    test('optional imageURL decodes when present', () {
      // Optional imageURL still round-trips when a live feed DOES provide one.
      const imgJSON =
          '{"id":"i1","headline":"H","summary":"S","category":"General",'
          '"compounds":[],"sources":[{"name":"n","url":"https://example.com",'
          '"kind":"news"}],"publishedAt":"2026-07-08T00:00:00Z","popularity":0,'
          '"isMajorUpdate":false,"disclaimer":"d",'
          '"imageURL":"https://example.com/x.jpg"}';
      final withImg = NewsItem.fromJson(
        jsonDecode(imgJSON) as Map<String, dynamic>,
      );
      expect(withImg.imageURL, 'https://example.com/x.jpg');
    });

    test('listText == teaser when teaser present', () {
      // teaser / listText — additive optional; teaser-less items fall back to summary.
      final withTeaser = plainItem(id: 't1', teaser: 'Short teaser.');
      expect(withTeaser.listText, withTeaser.teaser ?? withTeaser.summary);
      expect(withTeaser.listText, 'Short teaser.');
    });

    test('listText == summary when teaser nil (backward-compatible)', () {
      final noTeaser = plainItem(id: 't2');
      expect(noTeaser.teaser, isNull);
      expect(noTeaser.listText, noTeaser.summary);
    });
  });

  group('News feed wire contract', () {
    final feed = NewsFeed.decodeSample();

    test('the document envelope decodes', () {
      expect(feed.version, 1);
      expect(feed.generatedAt, '2026-07-09T12:00:00Z');
    });

    test('publishedAt/generatedAt stay STRINGS on the wire', () {
      // The Swift keeps both as `String` so no JSONDecoder date strategy is involved. A port
      // that "helpfully" decoded them into DateTime would re-encode a different shape and the
      // published feed would stop matching the model.
      final json = feed.toJson();
      expect(json['generatedAt'], isA<String>());
      final first =
          (json['items']! as List<dynamic>).first as Map<String, dynamic>;
      expect(first['publishedAt'], '2026-07-23T00:00:00Z');
    });

    test('decode -> encode -> decode round-trips the whole feed', () {
      final again = NewsFeed.fromJson(
        jsonDecode(jsonEncode(feed.toJson())) as Map<String, dynamic>,
      );
      expect(again, feed);
      expect(again.hashCode, feed.hashCode);
    });

    test('nil optionals are OMITTED, never emitted as null', () {
      // Swift's synthesized Codable uses `encodeIfPresent`, so `"imageURL": null` is not a
      // shape the iOS build ever writes.
      final json = plainItem(id: 'x').toJson();
      expect(json.containsKey('imageURL'), isFalse);
      expect(json.containsKey('teaser'), isFalse);
      expect(
        plainItem(id: 'x', teaser: 't').toJson().containsKey('teaser'),
        isTrue,
      );
    });

    test('every key the model writes is a key the model reads', () {
      const item = NewsItem(
        id: 'i',
        headline: 'H',
        summary: 'S',
        category: NewsCategory.safety,
        compounds: ['BPC-157', 'TB-500'],
        sources: [
          NewsSource(
            name: 'n',
            url: 'https://example.com',
            kind: NewsSourceKind.regulatory,
          ),
        ],
        publishedAt: '2026-07-08T00:00:00Z',
        popularity: 7,
        isMajorUpdate: true,
        disclaimer: 'd',
        imageURL: 'https://example.com/x.jpg',
        teaser: 'T',
      );
      expect(
        NewsItem.fromJson(
          jsonDecode(jsonEncode(item.toJson())) as Map<String, dynamic>,
        ),
        item,
      );
      expect(item.toJson().keys.toSet(), {
        'id',
        'headline',
        'summary',
        'category',
        'compounds',
        'sources',
        'publishedAt',
        'popularity',
        'isMajorUpdate',
        'disclaimer',
        'imageURL',
        'teaser',
      });
    });

    test('a source is identified by its URL', () {
      const source = NewsSource(
        name: 'STAT',
        url: 'https://example.com/a',
        kind: NewsSourceKind.news,
      );
      expect(source.id, 'https://example.com/a');
      expect(NewsSource.fromJson(source.toJson()), source);
    });

    test('every category label survives a round-trip', () {
      for (final category in NewsCategory.values) {
        expect(NewsCategory.fromLabel(category.label), category);
      }
      // The exact wire tokens, spelled out — these are what a published feed carries.
      expect(NewsCategory.values.map((c) => c.label).toList(), [
        'Trial results',
        'Regulatory',
        'Safety',
        'Early research',
        'Guidance',
        'General',
      ]);
    });

    test('an UNKNOWN category falls back to General instead of throwing', () {
      // The taxonomy is allowed to grow server-side; a category the app has never heard of
      // must never fail the decode of the whole document.
      expect(NewsCategory.fromLabel('Quantum peptides'), NewsCategory.general);
      expect(NewsCategory.fromLabel(''), NewsCategory.general);
      expect(
        NewsItem.fromJson({
          'id': 'i',
          'headline': 'H',
          'summary': 'S',
          'category': 'Something new',
          'compounds': <String>[],
          'sources': <Map<String, dynamic>>[],
          'publishedAt': '2026-07-08T00:00:00Z',
          'popularity': 0,
          'isMajorUpdate': false,
          'disclaimer': 'd',
        }).category,
        NewsCategory.general,
      );
    });

    test('the legacy "New compound" token still maps to Early research', () {
      expect(
        NewsCategory.fromLabel(NewsCategory.legacyEarlyResearchLabel),
        NewsCategory.earlyResearch,
      );
      // The bundled sample still carries the legacy token on three items, so the sample is
      // itself the regression test for it.
      final legacy = feed.items
          .where((i) => i.category == NewsCategory.earlyResearch)
          .map((i) => i.id)
          .toList();
      expect(legacy, [
        'aod9604-failed-program',
        'motsc-preclinical',
        'motsc-exercise-2021',
      ]);
      // Re-encoding NORMALISES the token to the current spelling — same as Swift, whose
      // encode side always writes `rawValue`.
      expect(
        (jsonDecode(jsonEncode(feed.toJson())) as Map<String, dynamic>)['items']
            as List<dynamic>,
        contains(
          predicate<dynamic>(
            (i) =>
                (i as Map<String, dynamic>)['id'] == 'aod9604-failed-program' &&
                i['category'] == 'Early research',
          ),
        ),
      );
    });

    test('an unknown source kind THROWS, exactly as the Swift does', () {
      // Not an oversight: `NewsSource.Kind` keeps Swift's SYNTHESIZED Codable, which throws
      // `DecodingError.dataCorrupted` on an unknown raw value and takes the whole document
      // with it. Reproduced rather than improved — the fix belongs in the Swift first.
      expect(() => NewsSourceKind.fromRawValue('podcast'), throwsStateError);
      for (final kind in NewsSourceKind.values) {
        expect(NewsSourceKind.fromRawValue(kind.rawValue), kind);
      }
      expect(NewsSourceKind.values.map((k) => k.rawValue).toList(), [
        'trial',
        'journal',
        'preprint',
        'regulatory',
        'news',
      ]);
    });
  });

  group('News feed ranking', () {
    test('parseDate reads the leading yyyy-MM-dd, in UTC', () {
      expect(
        NewsFeed.parseDate('2026-07-23T00:00:00Z'),
        DateTime.utc(2026, 7, 23),
      );
      // Day granularity: the time-of-day in the string is discarded.
      expect(
        NewsFeed.parseDate('2026-07-23T18:45:12Z'),
        DateTime.utc(2026, 7, 23),
      );
      expect(NewsFeed.parseDate('2026-07-23')?.isUtc, isTrue);
    });

    test('parseDate returns null for anything it cannot read', () {
      expect(NewsFeed.parseDate(''), isNull);
      expect(NewsFeed.parseDate('2026-07'), isNull);
      expect(NewsFeed.parseDate('yesterday'), isNull);
      expect(NewsFeed.parseDate('2026/07/23'), isNull);
      expect(NewsFeed.parseDate('xxxx-07-23'), isNull);
      // Only the first 10 characters are considered, so a 4-digit year is required for the
      // day to land inside the window.
      expect(NewsFeed.parseDate('26-7-3T00:00:00Z'), isNull);
      // Whitespace is rejected, because Swift's `Int(String)` rejects it. Dart's
      // `int.tryParse` does NOT, so this would silently parse without the guard in the port —
      // and then disagree with the iOS build about the same feed.
      expect(NewsFeed.parseDate(' 2026-07-23'), isNull);
      expect(NewsFeed.parseDate('2026-07- 3T00:00:00Z'), isNull);
    });

    test('rankScore = decayed recency + popularity', () {
      final item = plainItem(id: 'r');
      // A fresh story scores the full 100 recency; a FUTURE date is clamped to age 0 rather
      // than scoring above 100.
      const fresh = NewsItem(
        id: 'fresh',
        headline: 'H',
        summary: 'S',
        category: NewsCategory.general,
        compounds: [],
        sources: [],
        publishedAt: '2026-07-11T00:00:00Z',
        popularity: 10,
        isMajorUpdate: false,
        disclaimer: 'd',
      );
      final feed = NewsFeed(version: 1, generatedAt: 'g', items: [item, fresh]);
      expect(feed.rankScore(fresh, asOf: rankAsOf), closeTo(110, 1e-9));
      expect(
        feed.rankScore(fresh, asOf: DateTime.utc(2026, 7, 1)),
        closeTo(110, 1e-9),
      );
      // 180 days is the half-life, so recency halves to 50.
      const old = NewsItem(
        id: 'old',
        headline: 'H',
        summary: 'S',
        category: NewsCategory.general,
        compounds: [],
        sources: [],
        publishedAt: '2026-01-12T00:00:00Z', // 180 days before 2026-07-11
        popularity: 10,
        isMajorUpdate: false,
        disclaimer: 'd',
      );
      expect(feed.rankScore(old, asOf: rankAsOf), closeTo(60, 1e-9));
    });

    test('an unparseable date scores recency 0, not a crash', () {
      const undated = NewsItem(
        id: 'undated',
        headline: 'H',
        summary: 'S',
        category: NewsCategory.general,
        compounds: [],
        sources: [],
        publishedAt: 'sometime',
        popularity: 42,
        isMajorUpdate: false,
        disclaimer: 'd',
      );
      final feed = NewsFeed(version: 1, generatedAt: 'g', items: [undated]);
      expect(feed.rankScore(undated, asOf: rankAsOf), 42);
      expect(feed.ranked(asOf: rankAsOf).single.id, 'undated');
    });

    test('equal scores break on the raw publishedAt string, descending', () {
      // Both dates are unparseable, so both score recency 0 and the tie-break is the only
      // thing ordering them — which is what makes the order deterministic at all.
      const a = NewsItem(
        id: 'a',
        headline: 'H',
        summary: 'S',
        category: NewsCategory.general,
        compounds: [],
        sources: [],
        publishedAt: 'aaa',
        popularity: 5,
        isMajorUpdate: false,
        disclaimer: 'd',
      );
      const z = NewsItem(
        id: 'z',
        headline: 'H',
        summary: 'S',
        category: NewsCategory.general,
        compounds: [],
        sources: [],
        publishedAt: 'zzz',
        popularity: 5,
        isMajorUpdate: false,
        disclaimer: 'd',
      );
      expect(
        NewsFeed(
          version: 1,
          generatedAt: 'g',
          items: [a, z],
        ).ranked(asOf: rankAsOf).map((i) => i.id).toList(),
        ['z', 'a'],
      );
      expect(
        NewsFeed(
          version: 1,
          generatedAt: 'g',
          items: [z, a],
        ).ranked(asOf: rankAsOf).map((i) => i.id).toList(),
        ['z', 'a'],
      );
    });

    test('trending, majorUpdates and itemsMentioning do not mutate items', () {
      final feed = NewsFeed.decodeSample();
      final order = feed.items.map((i) => i.id).toList();
      feed.trending;
      feed.ranked(asOf: rankAsOf);
      feed.majorUpdates;
      feed.itemsMentioning('Semaglutide');
      expect(feed.items.map((i) => i.id).toList(), order);
    });

    test('itemsMentioning matches a compound name exactly', () {
      final feed = NewsFeed.decodeSample();
      expect(feed.itemsMentioning('Semaglutide'), isNotEmpty);
      expect(feed.itemsMentioning('semaglutide'), isEmpty); // case-sensitive
      expect(feed.itemsMentioning('Sema'), isEmpty); // no substring matching
      expect(
        feed.itemsMentioning('Retatrutide').map((i) => i.id).toList(),
        containsAll([
          'reta-phase2-obesity-2023',
          'reta-masld-liver-fat-2024',
          'reta-triumph-phase3-2025',
          'reta-prediabetes-reversion-2023',
        ]),
      );
    });
  });
}

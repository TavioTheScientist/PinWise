import SwiftUI
import SwiftData
import SafariServices
import PeptideKit

/// A source link tapped in an article — drives the in-app browser sheet (Identifiable for .sheet(item:)).
private struct WebLink: Identifiable { let url: URL; var id: String { url.absoluteString } }

/// In-app browser (SFSafariViewController) presented as a bottom sheet, so reading a source never
/// kicks the user out to Safari. Keeps Staxyz's reading flow intact.
private struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredControlTintColor = UIColor(BrandColor.accent)
        vc.dismissButtonStyle = .close
        return vc
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

// The News tab — Staxyz as the hub for sources of truth on peptides and performance medicine.
// Editorial layout (Apple-News style): a masthead, search + category filters, a popular lead
// story, then the latest. Neutral, cited summaries linked to the original sources.

/// Legible tint per category (uses the lighter/brighter hues so text stays readable on dark).
private extension NewsCategory {
    var tint: Color {
        switch self {
        case .safety: return BrandColor.warning
        case .regulatory: return BrandColor.accentText
        case .trialResults: return BrandColor.success
        case .earlyResearch: return BrandColor.data       // distinct from trial results (has data)
        case .guidance, .general: return BrandColor.textSecondary
        }
    }

    /// A category ribbon is TAXONOMY — what the story is about — so it reads neutral. The one
    /// exception is `.safety`, which flags something a reader may need to act on, and keeps a
    /// solid warning fill. (`tint` still colors the `FeedImage` placeholder, where hue is the
    /// only signal available.)
    var chipStyle: TagChip.Style {
        self == .safety ? .warning : .neutral
    }
}

/// The category to DISPLAY as a ribbon. Guards against a mis-tag: an FDA-approved compound is never
/// "Early research", so a loose/stale tag (e.g. a Tirzepatide article tagged early-research) is shown
/// as Trial results instead. Once the feed is rebuilt with the tightened classifier this rarely fires.
func displayCategory(_ item: NewsItem) -> NewsCategory {
    guard item.category == .earlyResearch else { return item.category }
    let approved = Set(CompoundCatalog.all.filter { $0.regulatoryStatus == .fdaApproved }.map { $0.name.lowercased() })
    return item.compounds.contains { approved.contains($0.lowercased()) } ? .trialResults : .earlyResearch
}

/// Parses a feed item's `publishedAt` into a Date. Delegates to `NewsFeed.parseDate`, which
/// reads `yyyy-MM-dd` directly — NEVER allocate an `ISO8601DateFormatter` here: this runs per
/// row, per render, and on every scroll-visibility change, and formatter allocation froze the tab.
func newsDate(_ iso: String) -> Date? { NewsFeed.parseDate(iso) }

/// Formats a feed item's `publishedAt` as a friendly abbreviated date (falls back to the raw
/// date substring if parsing ever fails).
func newsDisplayDate(_ iso: String) -> String {
    newsDate(iso).map { $0.formatted(date: .abbreviated, time: .omitted) } ?? String(iso.prefix(10))
}

/// Conversational relative date for scannable list rows/cards ("yesterday", "3 days ago"). The
/// article detail keeps the absolute date, so the exact timestamp is always one tap away.
func newsRelativeDate(_ iso: String) -> String {
    newsDate(iso).map { $0.relativeLabel() } ?? String(iso.prefix(10))
}

/// True when an article was published within the last `days` — the eligibility window for the
/// "New" tag (keeps old/evergreen items from ever being flagged, and avoids a wall of "New" on
/// first launch). Whether it *actually* shows also depends on the reader's seen state.
func isRecentNews(_ iso: String, within days: Int = 7) -> Bool {
    guard let d = newsDate(iso) else { return false }
    let age = Date().timeIntervalSince(d)
    return age >= 0 && age <= Double(days) * 86_400
}

/// Tracks which News articles the reader has scrolled into view, by first-seen calendar day, so
/// the "New" tag behaves like an unread badge: a recent article stays flagged until it's scrolled
/// past, an article seen today stays flagged for the rest of that day, and it clears the next day.
/// Local-only (UserDefaults), self-pruning past 30 days so it can't grow without bound.
@MainActor @Observable
final class NewsSeenStore {
    private static let key = "newsSeenDays"      // [articleID: "yyyy-MM-dd" first-seen day]
    private var seen: [String: String]

    private static func dayString(_ date: Date = Date()) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.calendar = Calendar(identifier: .gregorian)
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: date)
    }

    init() {
        let raw = (UserDefaults.standard.dictionary(forKey: Self.key) as? [String: String]) ?? [:]
        let cutoff = Self.dayString(Date().addingTimeInterval(-30 * 86_400))
        seen = raw.filter { $0.value >= cutoff }   // lexical == chronological for yyyy-MM-dd
        if seen.count != raw.count { UserDefaults.standard.set(seen, forKey: Self.key) }
    }

    /// Record that an article was scrolled into view (first sighting only).
    func markSeen(_ id: String) {
        guard seen[id] == nil else { return }
        seen[id] = Self.dayString()
        UserDefaults.standard.set(seen, forKey: Self.key)
    }

    /// Still eligible to show "New": never seen, or first seen today (clears the next day).
    func isUnreadToday(_ id: String) -> Bool {
        guard let day = seen[id] else { return true }
        return day == Self.dayString()
    }
}

struct NewsView: View {
    @State private var loader = NewsFeedLoader()
    @State private var seenStore = NewsSeenStore()
    @State private var searchText = ""
    @State private var category: NewsCategory?
    @State private var myStack = false
    @State private var newOnly = false
    @State private var searchActive = false
    @State private var path = NavigationPath()
    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(TabScrollCoordinator.self) private var scrollCoordinator
    @Query private var protocols: [SavedProtocol]
    @Query private var vials: [StoredVial]
    @Query(sort: \LoggedDose.timestamp, order: .reverse) private var logs: [LoggedDose]
    private var feed: NewsFeed { loader.feed }

    /// Every compound the user is currently on — from active protocols, inventory, and recent logs.
    private var userCompounds: Set<String> {
        var s = Set<String>()
        for p in protocols where p.isActive { for n in p.compoundNames { s.insert(n.lowercased()) } }
        for v in vials { for n in v.apiNames { s.insert(n.lowercased()) } }
        for l in logs.prefix(80) { s.insert(l.compoundName.lowercased()) }
        return s
    }
    private func matchesStack(_ item: NewsItem) -> Bool {
        guard !userCompounds.isEmpty else { return false }
        // Substring match both ways so catalog aliases line up (e.g. "GHK-Cu" ⟷ "GHK-Cu (injectable)").
        return item.compounds.contains { ic in
            let icl = ic.lowercased()
            return userCompounds.contains { uc in uc == icl || uc.contains(icl) || icl.contains(uc) }
        }
    }

    // Blended recency + popularity order (see NewsFeed.rankScore): the top stories are the ones
    // that are both recently published and popular; everything flows newest-leaning from there.
    private var items: [NewsItem] { feed.ranked() }
    private var isFiltering: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty || category != nil || myStack || newOnly
    }

    /// Featured lead — personalized. If the user is on compounds and any story mentions one of
    /// them, the highest-ranked matching story leads; otherwise the top editorial story. New
    /// users (empty stack) always see the editorial Top story.
    private var featured: NewsItem? {
        if !userCompounds.isEmpty, let mine = items.first(where: { matchesStack($0) }) { return mine }
        return items.first
    }
    /// True when the lead was chosen because it matches the user's stack (drives the header copy).
    private var featuredIsPersonalized: Bool {
        guard let featured, !userCompounds.isEmpty else { return false }
        return matchesStack(featured)
    }
    /// "Latest" = everything else, kept in the feed's blended recency+popularity order.
    private var latest: [NewsItem] {
        items.filter { $0.id != featured?.id }
    }
    private var results: [NewsItem] {
        items.filter { item in
            (category == nil || item.category == category) &&
            (searchText.isEmpty || matches(item, searchText)) &&
            (!myStack || matchesStack(item)) &&
            (!newOnly || isRecentNews(item.publishedAt))
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    masthead

                    // "Your compounds" stays a one-tap, always-visible feed toggle (not tucked in the
                    // search reveal) — it's the primary personal filter: news about what you're taking.
                    myCompoundsBar

                    if searchActive {
                        VStack(alignment: .leading, spacing: Space.md) {
                            SearchField(placeholder: "Search peptides, topics, or sources",
                                        text: $searchText, focus: $searchFocused)
                            categoryFilter
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    content
                }
                .padding(Space.lg)
            }
            .heroScreen()
            .scrollsToTopOnReselect(.news)
            .toolbar(.hidden, for: .navigationBar)
            .task { await loader.load() }
            .navigationDestination(for: NewsItem.self) { NewsDetailView(item: $0) }
        }
        // Re-tapping the News tab pops back to the feed (in addition to the top-left back arrow).
        .onChange(of: scrollCoordinator.token) {
            if scrollCoordinator.target == .news, !path.isEmpty { path.removeLast(path.count) }
        }
    }

    private var masthead: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(alignment: .center) {
                Text("News")
                    .font(Typo.screenTitle)
                    .foregroundStyle(BrandColor.textPrimary)
                Spacer()
                SearchToggleButton(isActive: searchActive) {
                    let willActivate = !searchActive
                    // The panel reveal keeps its slide — it IS a disclosure, opening directly below
                    // the button that opened it — but it now honors Reduce Motion like the rest of
                    // the app's animation, which it was silently skipping.
                    withAnimation(reduceMotion ? nil : .snappy) {
                        searchActive = willActivate
                        if !willActivate { clearPanelFilters() }   // closing clears search/category/new (NOT My compounds)
                    }
                    searchFocused = willActivate
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Always-visible personal feed filter. Independent of the search reveal so users can filter to
    /// what they're taking in one tap.
    ///
    /// **The state lives on the CONTROL, and the control is the only thing that moves.** This row
    /// used to spring a caption ("Showing news on what you're taking") in beside the chip on a
    /// `.snappy` spring — so the act of filtering shoved the entire feed down the screen, and the
    /// thing that visibly changed was the chrome rather than the switch you just flipped. A filter is
    /// a boolean on a control and should read like one: an empty circle fills into a checkmark and
    /// the chip takes the accent selection fill, animated inside the chip's OWN subtree so no
    /// surrounding layout is animated at all. The results themselves swap without a transition,
    /// which is correct — a query returns a different list, it doesn't slide one in.
    ///
    /// Nothing is lost with the caption gone: `AppliedFilterHeader` above the results already
    /// reports that a filter is applied (count + Clear), which is how every other filtered list in
    /// the app reports it, and the empty-stack guidance it carried is already the results list's
    /// own empty state.
    private var myCompoundsBar: some View {
        HStack(spacing: Space.sm) {
            SelectableChip(title: "Your compounds", isSelected: myStack,
                           systemImage: myStack ? "checkmark.circle.fill" : "circle") {
                myStack.toggle()
            }
            // Two symbols with identical metrics, so the glyph swap can't jitter the chip's width.
            // Scoped here rather than around the toggle: an `.animation` on the chip animates the
            // chip, where a `withAnimation` would animate every layout the flag feeds — the feed
            // included, which is exactly the jump being fixed.
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: myStack)
            Spacer(minLength: 0)
        }
        .sensoryFeedback(.selection, trigger: myStack)
    }

    /// Closing the search panel clears only the panel's own filters (search / category / New); the
    /// always-visible "Your compounds" toggle is independent and stays as the user set it.
    private func clearPanelFilters() {
        searchText = ""; category = nil; newOnly = false
    }

    /// Full reset — used by the results header's "Clear" (clears the panel filters AND My compounds).
    private func clearAll() {
        clearPanelFilters(); myStack = false
    }

    @ViewBuilder private var content: some View {
        if isFiltering {
            resultsList
        } else if items.isEmpty {
            // No content yet — distinguish "still loading" from "load failed / nothing there" so a
            // cold start never renders a bare "Latest" header with nothing beneath it.
            if loader.isLoading {
                VStack(spacing: Space.md) {
                    ProgressView()
                    Text("Loading the latest…")
                        .font(.callout).foregroundStyle(BrandColor.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.xxl)
            } else {
                Card {
                    VStack(spacing: Space.md) {
                        ThemedEmptyState(icon: "newspaper",
                                         title: "News couldn't load",
                                         message: "Check your connection and try again.")
                        Button { Task { await loader.load() } } label: {
                            Text("Try again")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(BrandColor.accentText)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } else {
            if let featured {
                SectionHeader(title: featuredIsPersonalized ? "Top story for you" : "Top story")
                newsLink(featured) { FeaturedNewsCard(item: featured, seenStore: seenStore) }
            }
            SectionHeader(title: "Latest")
            ForEach(latest) { item in rowLink(item) }
        }
    }

    private var categoryFilter: some View {
        FilterChipRail {
            SelectableChip(title: "New", isSelected: newOnly) { newOnly.toggle() }
            SelectableChip(title: "All", isSelected: category == nil) { category = nil }
            ForEach(NewsCategory.allCases, id: \.self) { c in
                SelectableChip(title: c.rawValue, isSelected: category == c) {
                    category = (category == c ? nil : c)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: category)
        .sensoryFeedback(.selection, trigger: newOnly)
    }

    @ViewBuilder private var resultsList: some View {
        AppliedFilterHeader(count: results.count, onClear: clearAll)
        if results.isEmpty {
            Card {
                Text(myStack && userCompounds.isEmpty
                     ? "Add a protocol or log a dose to see news about what you're taking."
                     : "No stories match. Try a different word or category.")
                    .font(Typo.body).foregroundStyle(BrandColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            ForEach(results) { item in rowLink(item) }
        }
    }

    private func newsLink<Label: View>(_ item: NewsItem, @ViewBuilder label: () -> Label) -> some View {
        NavigationLink(value: item) { label() }.buttonStyle(PressableStyle())
    }

    /// A list-row link with the shared scroll-edge treatment (rows only — the featured card
    /// stays static). Scale is ternaried out under Reduce Motion; the fade stays.
    private func rowLink(_ item: NewsItem) -> some View {
        newsLink(item) { NewsRow(item: item, seenStore: seenStore) }
            .scrollTransition(axis: .vertical) { content, phase in
                content
                    .opacity(phase.isIdentity ? 1 : 0.8)
                    .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.98))
            }
    }

    private func matches(_ item: NewsItem, _ query: String) -> Bool {
        let q = query.lowercased()
        return item.headline.lowercased().contains(q)
            || item.summary.lowercased().contains(q)
            || item.category.rawValue.lowercased().contains(q)
            || item.compounds.contains { $0.lowercased().contains(q) }
            || item.sources.contains { $0.name.lowercased().contains(q) }
    }
}

/// A small "New" tag (red dot + label) flagging a recently-published article.
private struct NewBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(BrandColor.danger).frame(width: 6, height: 6)
            Text("New")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(BrandColor.danger)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("New")
    }
}

/// The lead story: a prominent, text-forward card (chips → headline → summary → sources).
/// Uses theme tokens so it reads correctly in both light and dark mode.
struct FeaturedNewsCard: View {
    let item: NewsItem
    var seenStore: NewsSeenStore

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Space.md) {
                HStack(spacing: Space.sm) {
                    TagChip(text: displayCategory(item).rawValue, style: displayCategory(item).chipStyle)
                    if item.isMajorUpdate { TagChip(text: "Major", systemImage: "bolt.fill") }
                    Spacer()
                    if isRecentNews(item.publishedAt) && seenStore.isUnreadToday(item.id) { NewBadge() }
                    Text(newsRelativeDate(item.publishedAt))
                        .font(.caption).foregroundStyle(BrandColor.textSecondary)
                }
                Text(item.headline)
                    .font(Typo.title)
                    .foregroundStyle(BrandColor.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.listText)
                    .font(Typo.body)
                    .foregroundStyle(BrandColor.textSecondary)
                    .lineLimit(3)
                HStack(spacing: Space.xs) {
                    Image(systemName: "checkmark.seal.fill").font(.caption2)
                    Text("\(item.sources.count) source\(item.sources.count == 1 ? "" : "s")")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(BrandColor.textSecondary)
                }
                .foregroundStyle(BrandColor.success)
            }
        }
        .onScrollVisibilityChange(threshold: 0.6) { visible in
            if visible, isRecentNews(item.publishedAt) { seenStore.markSeen(item.id) }
        }
    }
}

/// A list row: square thumbnail + headline + meta.
struct NewsRow: View {
    let item: NewsItem
    var seenStore: NewsSeenStore

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: Space.md) {
                FeedImage(urlString: item.imageURL, tint: displayCategory(item).tint)
                    .frame(width: 66, height: 66)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))

                VStack(alignment: .leading, spacing: Space.xs) {
                    HStack {
                        TagChip(text: displayCategory(item).rawValue, style: displayCategory(item).chipStyle)
                        Spacer()
                        if isRecentNews(item.publishedAt) && seenStore.isUnreadToday(item.id) { NewBadge() }
                        Text(newsRelativeDate(item.publishedAt))
                            .font(.caption)
                            .foregroundStyle(BrandColor.textSecondary)
                    }
                    Text(item.headline)
                        .font(Typo.headline)
                        .foregroundStyle(BrandColor.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(item.listText)
                        .font(.caption)
                        .foregroundStyle(BrandColor.textSecondary)
                        .lineLimit(3)
                    Text("\(item.sources.count) source\(item.sources.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(BrandColor.success)
                }
            }
        }
        .onScrollVisibilityChange(threshold: 0.6) { visible in
            if visible, isRecentNews(item.publishedAt) { seenStore.markSeen(item.id) }
        }
    }
}

/// Article detail, top-to-bottom: title → compounds mentioned → plain-language key finding →
/// fuller summary → tappable sources → per-item disclaimer.
struct NewsDetailView: View {
    let item: NewsItem
    @State private var webLink: WebLink?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                FeedImage(urlString: item.imageURL, tint: displayCategory(item).tint)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    // The one sanctioned on-image badge — frosted, over real photo pixels.
                    .overlay(alignment: .topLeading) {
                        FrostedTagChip(text: displayCategory(item).rawValue)
                            .padding(Space.md)
                    }

                // 1 — Title
                VStack(alignment: .leading, spacing: Space.sm) {
                    Text(newsDisplayDate(item.publishedAt))
                        .font(.caption)
                        .foregroundStyle(BrandColor.textSecondary)
                    Text(item.headline)
                        .font(Typo.title)
                        .foregroundStyle(BrandColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // 2 — Compounds mentioned, right under the title
                if !item.compounds.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Space.sm) {
                            ForEach(item.compounds, id: \.self) { c in
                                TagChip(text: c)
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }

                // 3 — Key finding / call to action, plain language, emphasized
                if let key = item.teaser, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(key)
                        .font(Typo.headline)
                        .foregroundStyle(BrandColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // 4 — Fuller summary of the findings
                Text(item.summary)
                    .font(Typo.body)
                    .foregroundStyle(BrandColor.textSecondary)

                // 5 — Sources at the bottom
                SectionHeader(title: "Sources")
                VStack(alignment: .leading, spacing: Space.sm) {
                    ForEach(item.sources) { source in
                        if let url = URL(string: source.url) {
                            Button { webLink = WebLink(url: url) } label: {
                                HStack(spacing: Space.sm) {
                                    Image(systemName: "link").foregroundStyle(BrandColor.accentText)
                                    Text(source.name).foregroundStyle(BrandColor.accentText)
                                    Spacer()
                                    Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(BrandColor.textSecondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !item.disclaimer.isEmpty {
                    Text(item.disclaimer)
                        .font(.caption2)
                        .foregroundStyle(BrandColor.textSecondary)
                }
            }
            .padding(Space.lg)
        }
        .screenBackground()
        // Sources open in an in-app browser sheet — the user stays inside Staxyz.
        .sheet(item: $webLink) { SafariView(url: $0.url).ignoresSafeArea() }
        .navigationTitle("Article")
        .navigationBarTitleDisplayMode(.inline)
    }
}

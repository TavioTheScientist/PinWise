import SwiftUI
import SwiftData
import PeptideKit

// The compound library (reached from Your vials): the verified catalog with evidence tiers,
// plus the user's own added compounds.

struct CompoundsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CustomCompound.name) private var custom: [CustomCompound]
    @State private var search = ""
    /// Optional goal filter. nil = the whole library. Set from the reveal panel's chip rail.
    @State private var selectedGoal: CompoundGoal?
    /// Whether the reveal-on-demand filter panel (search + goal chips) is open. Standard app-wide
    /// pattern (see FilterChipRail/AppliedFilterHeader): opens from the toolbar magnifier; closing it
    /// clears the filters so the library returns to its full, unfiltered state.
    @State private var filterActive = false
    @FocusState private var searchFocused: Bool
    @State private var showLegend = false
    @State private var showAdd = false

    private var query: String { search.trimmingCharacters(in: .whitespaces).lowercased() }

    /// Every matching compound in one flat A–Z list (CompoundCatalog.allSorted is already
    /// alphabetical, and filtering preserves that order). No class grouping.
    private var results: [Compound] {
        CompoundCatalog.allSorted.filter { matchesQuery($0) && matchesGoal($0) }
    }

    private func matchesQuery(_ c: Compound) -> Bool {
        guard !query.isEmpty else { return true }
        return c.name.lowercased().contains(query)
            || c.aliases.contains { $0.lowercased().contains(query) }
            || c.category.rawValue.lowercased().contains(query)
            || (CompoundProfiles.profile(for: c)?.tagline.lowercased().contains(query) ?? false)
    }
    private func matchesGoal(_ c: Compound) -> Bool {
        guard let goal = selectedGoal else { return true }
        return CompoundProfiles.goals(for: c).contains(goal)
    }

    private var customResults: [CustomCompound] {
        // Custom compounds carry no authored goals — hide them when a goal filter is active.
        guard selectedGoal == nil else { return [] }
        guard !query.isEmpty else { return custom }
        return custom.filter { $0.name.lowercased().contains(query) || $0.categoryRaw.lowercased().contains(query) }
    }

    private var isFiltering: Bool { selectedGoal != nil || !query.isEmpty }
    private var resultCount: Int { results.count + customResults.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                if filterActive {
                    VStack(alignment: .leading, spacing: Space.md) {
                        SearchField(placeholder: "Search by name or alias (e.g. “sema”)",
                                    text: $search, focus: $searchFocused)
                        goalFilterRail
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                if isFiltering { AppliedFilterHeader(count: resultCount, onClear: clearFilters) }

                if resultCount == 0 {
                    Card {
                        Text(emptyMessage)
                            .font(Typo.body).foregroundStyle(BrandColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    if !customResults.isEmpty {
                        SectionHeader(title: "Your compounds")
                        ForEach(customResults, id: \.id) { cc in
                            NavigationLink { CompoundDetailView(compound: cc.asCompound, isCustom: true) } label: {
                                CompoundRow(compound: cc.asCompound, isCustom: true)
                            }
                            .buttonStyle(PressableStyle())
                            .contextMenu {
                                Button(role: .destructive) { context.delete(cc); try? context.save() } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    // One flat A–Z list of every compound (no class grouping). A "Library" header
                    // only appears to separate it from the user's own compounds above.
                    if !customResults.isEmpty { SectionHeader(title: "Library") }
                    ForEach(results) { compound in
                        NavigationLink { CompoundDetailView(compound: compound) } label: {
                            CompoundRow(compound: compound)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }

                addYourOwnButton
            }
            .padding(Space.lg)
        }
        .heroScreen()
        .navigationTitle("Compound library")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { toggleFilter() } label: {
                    Image(systemName: filterActive ? "xmark" : "magnifyingglass")
                }
                .tint(BrandColor.accentText)
                .accessibilityLabel(filterActive ? "Close search and filters" : "Search and filter")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showAdd = true } label: { Label("Add your own compound", systemImage: "plus") }
                    Button { showLegend = true } label: { Label("What the grades & labels mean", systemImage: "questionmark.circle") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .tint(BrandColor.accentText)
            }
        }
        .sheet(isPresented: $showLegend) { CompoundLegendView() }
        .sheet(isPresented: $showAdd) { AddCustomCompoundView() }
    }

    /// The goal facets, in the standard reveal panel's chip rail.
    private var goalFilterRail: some View {
        FilterChipRail {
            SelectableChip(title: "All goals", isSelected: selectedGoal == nil) { selectedGoal = nil }
            ForEach(CompoundGoal.allCases) { goal in
                SelectableChip(title: goal.displayName,
                               isSelected: selectedGoal == goal,
                               systemImage: goalIcon(goal)) {
                    selectedGoal = (selectedGoal == goal) ? nil : goal
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selectedGoal)
    }

    private func toggleFilter() {
        withAnimation(.snappy) {
            filterActive.toggle()
            if !filterActive { clearFilters() }   // closing the panel clears the filters
        }
        searchFocused = filterActive
    }

    /// Closing the panel resets to the full library — filters are only live while the panel is open.
    private func clearFilters() { search = ""; selectedGoal = nil }

    private var addYourOwnButton: some View {
        Button { showAdd = true } label: {
            HStack {
                Image(systemName: "plus.circle.fill").foregroundStyle(BrandColor.accentText)
                Text("Add your own compound").font(Typo.headline).foregroundStyle(BrandColor.textPrimary)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(BrandColor.textSecondary)
            }
            .padding(Space.lg)
            .background(BrandColor.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(BrandColor.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var emptyMessage: String {
        "No compounds match. Try a different name, or clear the goal filter to see the whole library."
    }
}

/// Explains the evidence tiers, the WADA label, and half-life — reachable from the "?" button.
struct CompoundLegendView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Card {
                        VStack(alignment: .leading, spacing: Space.md) {
                            SectionHeader(title: "Evidence grades")
                            Text("The grade rates how much you can trust that a compound works and is safe in people — the strength of the research, not how big the effect is or whether you should take it. Strong evidence can back a small effect, and a high grade is never a recommendation.")
                                .font(.caption).foregroundStyle(BrandColor.textSecondary)
                            tierRow(.fdaApproved, "Approved by the FDA for use in people — the strongest evidence.")
                            tierRow(.humanTrialsUnapproved, "Studied in human trials, but not FDA-approved.")
                            tierRow(.preclinicalOrFailed, "Mostly animal or lab data (or trials that didn't pan out) — little human evidence.")
                            tierRow(.precursorOffLabel, "Evidence is for a topical or precursor form; injected use is off-label and unstudied.")
                        }
                    }

                    Card {
                        VStack(alignment: .leading, spacing: Space.md) {
                            SectionHeader(title: "Labels")
                            HStack(alignment: .top, spacing: Space.md) {
                                TagChip(text: "WADA", style: .warning)
                                Text("On the World Anti-Doping Agency prohibited list — banned for drug-tested athletes.")
                                    .font(.caption2).foregroundStyle(BrandColor.textSecondary)
                                Spacer(minLength: 0)
                            }
                        }
                    }

                    Card {
                        VStack(alignment: .leading, spacing: Space.sm) {
                            // Not SectionHeader: it uppercases the whole title, which would turn the
                            // t½ symbol into "T½". Half-life is conventionally lowercase-t, so the
                            // header keeps that while matching the section-header type treatment.
                            Text("HALF-LIFE (t½)")
                                .font(Typo.caption)
                                .fontWeight(.semibold)
                                .tracking(1.2)
                                .foregroundStyle(BrandColor.textSecondary)
                            Text("The time it takes for half of a dose to clear your body. A short t½ (minutes or hours) means it acts and leaves quickly; a long t½ (days) means it lingers and can build up with repeat doses. It's a rough guide to how often something is typically taken — not a dose recommendation.")
                                .font(.caption).foregroundStyle(BrandColor.textSecondary)
                        }
                    }
                }
                .padding(Space.lg)
            }
            .navigationTitle("What these mean")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        // Glass sheet — content passes beneath the presentation; the canvas is the material, cards stay opaque.
        .presentationBackground {
            BrandColor.background.opacity(0.5).background(.ultraThinMaterial)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func tierRow(_ tier: EvidenceTier, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: Space.md) {
            // Fixed-width badge column so every description starts at the same x — the badges
            // vary in width ("A · Strong" vs "B · Moderate"), which otherwise ragged the text.
            EvidenceBadge(tier: tier)
                .frame(width: 104, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(tier.label).font(.caption.weight(.semibold)).foregroundStyle(BrandColor.textPrimary)
                Text(desc).font(.caption2).foregroundStyle(BrandColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }
}

/// A lookup row: name + one standardized "what it is, for what" descriptor + the evidence grade +
/// a chevron. The grade badge lives here (not only on the page) so the whole library is scannable
/// by evidence at a glance. Every row has a descriptor (the authored tagline, else the class name).
struct CompoundRow: View {
    let compound: Compound
    var isCustom: Bool = false

    private var descriptor: String {
        if isCustom { return "Added by you" }
        return CompoundProfiles.profile(for: compound)?.tagline ?? compound.category.displayName
    }

    var body: some View {
        Card {
            HStack(alignment: .center, spacing: Space.sm) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    HStack(spacing: Space.sm) {
                        Text(compound.name).font(Typo.headline).foregroundStyle(BrandColor.textPrimary)
                        if isCustom { TagChip(text: "Custom") }
                    }
                    Text(descriptor).font(.caption).foregroundStyle(BrandColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Space.sm)
                if !isCustom { EvidenceBadge(tier: compound.evidenceTier) }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(BrandColor.textSecondary)
            }
        }
    }
}

/// The deep-dive: an at-a-glance header, then the authored research-backed sections
/// (what it is → what to expect → evidence → doses seen → route → timing → side effects →
/// stacking → storage → misconceptions), then regulatory notes and an educational footer.
/// Sections render only when authored, so not-yet-profiled compounds still show cleanly.
/// The individual compound page. Structured to the community's own task-timeline (r/tirzecompound
/// wiki), front-loaded per NN/g, and mobile-navigable via "accordion = table of contents": the
/// identity, at-a-glance, any safety flag, and the plain "what it does" answer are always visible;
/// everything deeper is a scent-bearing accordion (dosing default-open), so a mostly-collapsed page
/// is scannable and each header answers a quick question on its own.
struct CompoundDetailView: View {
    let compound: Compound
    var isCustom: Bool = false

    /// Which accordions are open. Owned here so it defaults sensibly and persists for the session.
    @State private var expanded: Set<String> = ["dosing"]
    @State private var showCalculator = false
    @State private var showLegend = false
    /// Opens a citation's PubMed / ClinicalTrials.gov record in the browser.
    @Environment(\.openURL) private var openURL

    private var profile: CompoundProfile? { isCustom ? nil : CompoundProfiles.profile(for: compound) }
    private var goals: [CompoundGoal] { isCustom ? [] : CompoundProfiles.goals(for: compound) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                // Zone 1 — identity + summary, held tight so it reads as one cluster.
                VStack(alignment: .leading, spacing: Space.lg) {
                    header
                    if !goals.isEmpty { goalRow }
                    atAGlance
                    if let flag = profile?.safetyFlag { safetyStrip(flag) }
                }

                // Zone 2 — reference sections (a peer stack of Cards at one heading register).
                VStack(alignment: .leading, spacing: Space.md) {
                    if let p = profile { profileSections(p) }
                    notesBlock
                    if !isCustom { relatedSection }
                }

                // Zone 3 — the close.
                if isCustom {
                    DisclaimerBanner(text: Self.customCompoundNote, systemImage: "exclamationmark.triangle")
                } else {
                    footer
                }
            }
            .padding(Space.lg)
        }
        .screenBackground()
        .navigationTitle(compound.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCalculator) {
            NavigationStack {
                ReconstitutionCalculatorView()
                    .navigationTitle("Dose calculator")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(isPresented: $showLegend) { CompoundLegendView() }
    }

    // MARK: Always-visible top

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(compound.name).font(Typo.title).foregroundStyle(BrandColor.textPrimary)
            if !compound.aliases.isEmpty {
                Text(compound.aliases.joined(separator: " · "))
                    .font(Typo.caption).foregroundStyle(BrandColor.textSecondary)
            }
            HStack(spacing: Space.sm) {
                if isCustom {
                    TagChip(text: "Custom")
                } else {
                    EvidenceBadge(tier: compound.evidenceTier)
                    TagChip(text: regulatoryShort)
                }
            }
            if let tagline = profile?.tagline {
                Text(tagline).font(Typo.body).foregroundStyle(BrandColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.xs)
            }
        }
    }

    private var goalRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.sm) {
                ForEach(goals) { GoalPill(goal: $0) }
            }
            .padding(.horizontal, Space.xs)
        }
        .scrollClipDisabled()
    }

    /// Standardized stat grid: the SAME facts on every page, label-over-value (the design system's
    /// MicroLabel register) in two columns — an instrument strip, not a form ledger. Half-life and
    /// anti-doping are always stated (with "Not established" rather than a dropped row).
    private var atAGlance: some View {
        Card {
            LazyVGrid(
                columns: [GridItem(.flexible(), alignment: .topLeading), GridItem(.flexible(), alignment: .topLeading)],
                alignment: .leading, spacing: Space.lg
            ) {
                glanceStat("Class", compound.category.displayName)
                if isCustom {
                    glanceStat("Source", "Added by you")
                } else {
                    glanceStat("Anti-doping", compound.wadaProhibited ? "Prohibited (WADA)" : "Not listed")
                }
                glanceStat("Half-life", compound.halfLifeHours.map(halfLifeLong) ?? "Not established")
                glanceStat("Dosed in", compound.preferredDoseUnit.rawValue)
            }
        }
    }

    private func glanceStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            MicroLabel(label)
            Text(value).font(Typo.body.weight(.semibold)).foregroundStyle(BrandColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func safetyStrip(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Space.sm) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(BrandColor.warning)
            Text(text).font(Typo.caption).foregroundStyle(BrandColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.md)
        .background(BrandColor.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
    }

    // MARK: Authored sections — one heading register (DisclosureSection) for every section.

    @ViewBuilder private func profileSections(_ p: CompoundProfile) -> some View {
        if let what = p.whatItIs, !what.isEmpty {
            // The primary answer: a peer section, always open, in the same register as the rest.
            staticSection("What it does") { proseText(what) }
        }
        if let m = p.howItWorks, !m.isEmpty {
            disclosure("mechanism", "How it works", scent: "How it works in the body") { proseText(m) }
        }
        if p.dosingStudied != nil || p.dosingCommunity != nil {
            disclosure("dosing", "Reported dosing", scent: "Studied and community-reported ranges") { dosingBody(p) }
        }
        if hasSideEffects(p) {
            disclosure("sides", "Side effects", scent: "Common effects and when to seek care") { sideEffectsBody(p) }
        }
        if let e = p.whatToExpect, !e.isEmpty {
            disclosure("expect", "What to expect", scent: "Effects and typical timeline") { proseText(e) }
        }
        if let ev = p.evidenceSummary, !ev.isEmpty {
            disclosure("evidence", "Evidence & research", scent: "How much research supports it") { evidenceBody(ev) }
        }
        // Sources sit directly under Evidence, because they are what backs that section's claim.
        // Absent when unauthored rather than showing an empty shell — a "Sources" heading with
        // nothing under it reads as a broken app, and worse, implies none exist.
        if !p.citations.isEmpty {
            disclosure("sources", "Sources", scent: "\(p.citations.count) reference\(p.citations.count == 1 ? "" : "s") you can open") { citationsBody(p) }
        }
        if let r = p.route, !r.isEmpty {
            disclosure("route", "Route & injection site", scent: "How and where it is given") { proseText(r) }
        }
        if let t = p.timing, !t.isEmpty {
            disclosure("timing", "Timing", scent: "Half-life and dosing frequency") { proseText(t) }
        }
        if let st = p.storageHandling, !st.isEmpty {
            disclosure("storage", "Storage & handling", scent: "Refrigeration and beyond-use date") { proseText(st) }
        }
        // Vendor-neutral sourcing literacy — shown for every catalog compound.
        disclosure("legit", "Assessing quality", scent: "How to read a certificate of analysis") { proseText(Self.coaLiteracy) }
        if let stk = p.stacking, !stk.isEmpty {
            disclosure("stack", "Stacking", scent: "Compounds it is commonly combined with") { proseText(stk) }
        }
        if !p.misconceptions.isEmpty {
            disclosure("myths", "Common misconceptions", scent: "Claims the evidence does not support") { misconceptionsBody(p) }
        }
    }

    @ViewBuilder private var notesBlock: some View {
        if !compound.notes.isEmpty {
            if profile == nil || isCustom {
                staticSection(isCustom ? "Notes" : "Regulatory & notes") { proseText(compound.notes) }
            } else {
                disclosure("notes", "Regulatory & notes", scent: "Status, corrections, and caveats") { proseText(compound.notes) }
            }
        }
    }

    /// A citation row: kind badge, title, source · year, the identifier, and what it actually found.
    /// Tapping opens the record. The `finding` line is the point of the whole section — a bare
    /// reference list lets a reader assume every citation SUPPORTS the compound, when several here
    /// are negative or are animal-only.
    private func citationsBody(_ p: CompoundProfile) -> some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            ForEach(p.citations) { c in
                VStack(alignment: .leading, spacing: Space.xs) {
                    HStack(spacing: Space.sm) {
                        TagChip(text: c.kind.label)
                        if !c.kind.isPeerReviewed {
                            // Stated, not implied. A registry entry is a PLAN and a preprint is
                            // unreviewed; neither should read like a published result.
                            Text(c.kind == .trial ? "registry entry" : "not peer reviewed")
                                .font(Typo.caption2)
                                .foregroundStyle(BrandColor.textSecondary)
                        }
                        Spacer(minLength: 0)
                        if c.url != nil {
                            Image(systemName: "arrow.up.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(BrandColor.textSecondary)
                        }
                    }
                    Text(c.title)
                        .font(Typo.body)
                        .foregroundStyle(BrandColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(c.source) · \(String(c.year)) · \(c.identifier)")
                        .font(Typo.caption2)
                        .foregroundStyle(BrandColor.textSecondary)
                    if let f = c.finding {
                        Text(f)
                            .font(Typo.caption)
                            .foregroundStyle(BrandColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { if let u = c.url { openURL(u) } }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(c.url != nil ? .isLink : [])
            }
            Text("References are retrieved records, not summaries written from memory. Open one and read it — a citation is only useful if you can check it.")
                .font(Typo.caption2)
                .foregroundStyle(BrandColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func dosingBody(_ p: CompoundProfile) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            if let s = p.dosingStudied { labeledDose("In studies / on the label", s) }
            if let c = p.dosingCommunity { labeledDose("Reported by the community", c) }
            proseText("Units measure volume, not dose — how much you draw depends on the vial's concentration. The calculator converts a target dose into syringe units for a specific vial.", secondary: true)
            Button { showCalculator = true } label: {
                Label("Open dose calculator", systemImage: "syringe.fill")
                    .font(Typo.caption.weight(.semibold)).foregroundStyle(BrandColor.accentText)
            }
            Text("Reported ranges, not a recommendation. Dose decisions belong with a clinician.")
                .font(Typo.caption2).foregroundStyle(BrandColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func evidenceBody(_ text: String) -> some View {
        // Evidence badge deliberately NOT repeated here — it is already in the header and this
        // section is titled "Evidence." Just the rationale + a link to the grade legend.
        VStack(alignment: .leading, spacing: Space.sm) {
            proseText(text)
            Button { showLegend = true } label: {
                Label("What the grades mean", systemImage: "info.circle")
                    .font(Typo.caption.weight(.semibold)).foregroundStyle(BrandColor.accentText)
            }
        }
    }

    private func misconceptionsBody(_ p: CompoundProfile) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            ForEach(Array(p.misconceptions.enumerated()), id: \.offset) { _, m in
                HStack(alignment: .top, spacing: Space.sm) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption).foregroundStyle(BrandColor.mint).padding(.top, Space.xs)
                    Text(m).font(Typo.body).foregroundStyle(BrandColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func hasSideEffects(_ p: CompoundProfile) -> Bool {
        !p.sideEffectsCommon.isEmpty || !p.sideEffectsSerious.isEmpty || !(p.sideEffects?.isEmpty ?? true)
    }

    /// Structured side effects when authored (Common list + a "When to stop or seek care" list with a
    /// warning glyph); otherwise the legacy prose block. The two groups separate "is this normal?" from
    /// the genuine red flags at a glance — icon + label, never color alone.
    @ViewBuilder private func sideEffectsBody(_ p: CompoundProfile) -> some View {
        if !p.sideEffectsCommon.isEmpty || !p.sideEffectsSerious.isEmpty {
            VStack(alignment: .leading, spacing: Space.md) {
                if !p.sideEffectsCommon.isEmpty {
                    sideEffectGroup("Common", p.sideEffectsCommon, icon: "circle.fill", tint: BrandColor.textSecondary)
                }
                if !p.sideEffectsSerious.isEmpty {
                    sideEffectGroup("When to stop or seek care", p.sideEffectsSerious,
                                    icon: "exclamationmark.triangle.fill", tint: BrandColor.warning)
                }
            }
        } else if let s = p.sideEffects {
            proseText(s)
        }
    }

    private func sideEffectGroup(_ label: String, _ items: [String], icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            MicroLabel(label)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: Space.sm) {
                    Image(systemName: icon).font(.caption2).foregroundStyle(tint).padding(.top, 3)
                    Text(item).font(Typo.body).foregroundStyle(BrandColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func labeledDose(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            MicroLabel(label)
            Text(text).font(Typo.body).foregroundStyle(BrandColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Related + footer

    private var relatedCompounds: [Compound] {
        CompoundCatalog.allSorted.filter { $0.category == compound.category && $0.id != compound.id }
    }

    @ViewBuilder private var relatedSection: some View {
        let related = Array(relatedCompounds.prefix(6))
        if !related.isEmpty {
            staticSection("Often compared with") {
                VStack(spacing: 0) {
                    ForEach(Array(related.enumerated()), id: \.element.id) { i, c in
                        NavigationLink { CompoundDetailView(compound: c) } label: {
                            HStack(spacing: Space.sm) {
                                VStack(alignment: .leading, spacing: Space.xs) {
                                    Text(c.name).font(Typo.body.weight(.medium)).foregroundStyle(BrandColor.textPrimary)
                                    if let t = CompoundProfiles.profile(for: c)?.tagline {
                                        Text(t).font(Typo.caption).foregroundStyle(BrandColor.textSecondary).lineLimit(1)
                                    }
                                }
                                Spacer(minLength: Space.sm)
                                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(BrandColor.textSecondary)
                            }
                            .padding(.vertical, Space.sm)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        if i < related.count - 1 { Divider().overlay(BrandColor.stroke) }
                    }
                }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            DisclaimerBanner(text: "Staxyz is a tracking tool, not medical advice. This page is educational reference — it does not tell you whether, or how much, to use anything. Talk to a licensed clinician before you start, change, or stop any compound.")
            if let p = profile {
                Text("Last reviewed \(p.lastReviewed) · Staxyz editorial")
                    .font(Typo.caption2).foregroundStyle(BrandColor.textSecondary)
            }
        }
    }

    // MARK: Helpers

    /// A caller-state accordion for one section. Renders nothing extra when the id isn't in
    /// `expanded`; toggling flips it (multi-open allowed, choice persists for the session).
    private func disclosure<C: View>(_ id: String, _ title: String, scent: String? = nil,
                                     @ViewBuilder content: @escaping () -> C) -> some View {
        DisclosureSection(
            title: title,
            scent: scent,
            isExpanded: expanded.contains(id),
            toggle: { if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) } },
            content: content
        )
    }

    /// An always-open section that shares the exact Card + headline register as the accordions, so
    /// the primary answer and the related list read as peers of every other section.
    private func staticSection<C: View>(_ title: String, @ViewBuilder content: @escaping () -> C) -> some View {
        DisclosureSection(title: title, isExpanded: true, toggle: {}, collapsible: false, content: content)
    }

    private func proseText(_ t: String, secondary: Bool = false) -> some View {
        Text(t)
            .font(secondary ? Typo.caption : Typo.body)
            .foregroundStyle(secondary ? BrandColor.textSecondary : BrandColor.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The one place a strong warning stays by design: compounds the user added themselves.
    static let customCompoundNote = "You're adding this compound yourself, so Staxyz has no verified data on it. Confirm its identity, purity, and handling against your supplier's certificate of analysis. Staxyz makes no assurances for user-added compounds and takes no responsibility for them."

    /// Vendor-neutral certificate-of-analysis literacy — shared across compounds. Deliberately names
    /// no seller (the trust-killer on commercial peptide sites); teaches what a real COA shows.
    static let coaLiteracy = "A certificate of analysis (COA) is a third-party lab report on a specific batch. A trustworthy one names an independent lab (not the seller), lists the batch/lot number, and reports identity and purity — typically by mass spectrometry (confirms it's the right molecule) and HPLC (reports % purity, ideally ≥98%). Match the lot on the COA to the lot on your vial; a COA for a different batch tells you nothing about yours. Be skeptical of a bare \"99% pure\" claim with no lab named, no method, and no date. Staxyz names no vendors and does not verify supply — this is general literacy so you can read a COA yourself."

    private var regulatoryShort: String {
        switch compound.regulatoryStatus {
        case .fdaApproved: return "FDA-approved"
        case .compoundedOnly: return "Compounded"
        case .researchOnly: return "Research only"
        }
    }
    private func detailRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(key).font(.caption).foregroundStyle(BrandColor.textSecondary)
            Spacer()
            Text(value).font(Typo.body).foregroundStyle(BrandColor.textPrimary).multilineTextAlignment(.trailing)
        }
    }
    private func halfLifeLong(_ h: Double) -> String {
        if h >= 24 { return "~\(Int((h / 24).rounded())) days" }
        if h >= 1 { return "~\(Int(h.rounded())) hours" }
        return "under 1 hour"
    }
}

/// A read-only goal pill (Fat loss, Recovery, …) shown on the compound detail header.
struct GoalPill: View {
    let goal: CompoundGoal
    var body: some View {
        Label(goal.displayName, systemImage: goalIcon(goal))
            .font(.caption.weight(.semibold))
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.xs)
            .foregroundStyle(BrandColor.textPrimary)
            .background(BrandColor.surfaceElevated, in: Capsule())
            .overlay(Capsule().strokeBorder(BrandColor.stroke, lineWidth: 1))
    }
}

/// SF Symbol for each browse goal. Kept in the UI layer (domain stays icon-agnostic).
func goalIcon(_ g: CompoundGoal) -> String {
    switch g {
    case .fatLoss: return "flame"
    case .recovery: return "bandage"
    case .muscleAndGH: return "figure.strengthtraining.traditional"
    case .skinAndHair: return "sparkles"
    case .longevity: return "hourglass"
    case .sleep: return "moon.zzz"
    case .sexualHealth: return "heart"
    case .cognitive: return "brain.head.profile"
    case .immune: return "shield.lefthalf.filled"
    }
}

/// Add a compound of your own — for anything the library doesn't carry. Name first, then
/// just enough structure for the rest of the app (category, dose unit) to work with it.
struct AddCustomCompoundView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var existing: [CustomCompound]

    @State private var name = ""
    @State private var category: CompoundCategory = .metabolic
    @State private var doseUnit: MassUnit = .milligram
    @State private var notes = ""
    @State private var showNotes = false

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }
    private var isDuplicate: Bool {
        CompoundCatalog.all.contains { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }
            || existing.contains { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }
    }
    private var canSave: Bool { !trimmed.isEmpty && !isDuplicate }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Card {
                        VStack(alignment: .leading, spacing: Space.lg) {
                            FieldRow("Compound name") {
                                TextField("e.g. KPV", text: $name).staxyzField()
                            }
                            if isDuplicate {
                                Text("Already in the library — search for it instead.")
                                    .font(.caption).foregroundStyle(BrandColor.warning)
                            }
                            FieldRow("Category") {
                                Picker("", selection: $category) {
                                    ForEach(CompoundCategory.allCases.filter { $0 != .blend }, id: \.self) {
                                        Text($0.rawValue).tag($0)
                                    }
                                }
                                .pickerStyle(.menu).tint(BrandColor.accentText)
                            }
                            FieldRow("Usually dosed in") {
                                Picker("", selection: $doseUnit) {
                                    ForEach(MassUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                                }
                                .pickerStyle(.segmented)
                            }
                            CollapsibleNoteField(text: $notes, expanded: $showNotes, title: "Notes",
                                                 hint: "Optional — source, batch, anything worth remembering.")
                        }
                    }

                    DisclaimerBanner(text: CompoundDetailView.customCompoundNote, systemImage: "exclamationmark.triangle")

                    PrimaryButton(title: "Add compound", systemImage: "checkmark") { save() }
                        .disabled(!canSave).opacity(canSave ? 1 : 0.5)
                }
                .padding(Space.lg)
            }
            .heroScreen()
            .navigationTitle("Your compound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func save() {
        guard canSave else { return }
        context.insert(CustomCompound(name: trimmed, categoryRaw: category.rawValue,
                                      doseUnitRaw: doseUnit.rawValue, notes: notes))
        try? context.save()
        dismiss()
    }
}

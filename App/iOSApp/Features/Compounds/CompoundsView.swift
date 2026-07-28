import SwiftUI
import SwiftData
import PeptideKit

// The compound library (reached from Your vials): the verified catalog with evidence tiers,
// plus the user's own added compounds.

struct CompoundsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CustomCompound.name) private var custom: [CustomCompound]
    @State private var search = ""
    /// Goal-based browse is the primary axis ("what am I trying to do?"). nil = all goals.
    @State private var selectedGoal: CompoundGoal?
    /// Evidence-grade facet (the third filter alongside goal + class-grouping). nil = all grades.
    @State private var selectedTier: EvidenceTier?
    @State private var showLegend = false
    @State private var showAdd = false

    private var query: String { search.trimmingCharacters(in: .whitespaces).lowercased() }

    /// Class order for grouping — mirrors the catalog's own ordering so the library reads the same
    /// way every time. Blends never appear here (catalog is single-compound), but kept for totality.
    private let classOrder: [CompoundCategory] = [
        .glp1, .growthHormoneSecretagogue, .healingRecovery, .cosmeticLongevity, .metabolic, .blend,
    ]

    private var results: [Compound] {
        CompoundCatalog.allSorted.filter { matchesQuery($0) && matchesGoal($0) && matchesTier($0) }
    }

    /// Library grouped by class, best-evidence-first within each class (Examine's matrix logic).
    private var grouped: [(category: CompoundCategory, compounds: [Compound])] {
        let items = results
        return classOrder.compactMap { cat in
            let inCat = items.filter { $0.category == cat }.sorted(by: byEvidenceThenName)
            return inCat.isEmpty ? nil : (cat, inCat)
        }
    }

    private func byEvidenceThenName(_ a: Compound, _ b: Compound) -> Bool {
        let ra = tierRank(a.evidenceTier), rb = tierRank(b.evidenceTier)
        if ra != rb { return ra < rb }
        return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
    }
    private func tierRank(_ t: EvidenceTier) -> Int {
        switch t {
        case .fdaApproved: return 0
        case .humanTrialsUnapproved: return 1
        case .preclinicalOrFailed: return 2
        case .precursorOffLabel: return 3
        }
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
    private func matchesTier(_ c: Compound) -> Bool { selectedTier == nil || c.evidenceTier == selectedTier }

    private var customResults: [CustomCompound] {
        // Custom compounds carry no authored goals or evidence grade — hide them when either facet
        // is active (they'd never legitimately match).
        guard selectedGoal == nil, selectedTier == nil else { return [] }
        guard !query.isEmpty else { return custom }
        return custom.filter { $0.name.lowercased().contains(query) || $0.categoryRaw.lowercased().contains(query) }
    }

    private var isFiltering: Bool { selectedGoal != nil || selectedTier != nil || !query.isEmpty }
    private var resultCount: Int { results.count + customResults.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                searchBar
                goalFilterBar
                filterSummary

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
                    ForEach(grouped, id: \.category) { group in
                        SectionHeader(title: group.category.displayName)
                        ForEach(group.compounds) { compound in
                            NavigationLink { CompoundDetailView(compound: compound) } label: {
                                CompoundRow(compound: compound)
                            }
                            .buttonStyle(PressableStyle())
                        }
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
                Button { showAdd = true } label: { Image(systemName: "plus") }
                    .tint(BrandColor.accentText)
                    .accessibilityLabel("Add your own compound")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showLegend = true } label: { Image(systemName: "questionmark.circle") }
                    .tint(BrandColor.accentText)
                    .accessibilityLabel("What the grades and labels mean")
            }
        }
        .sheet(isPresented: $showLegend) { CompoundLegendView() }
        .sheet(isPresented: $showAdd) { AddCustomCompoundView() }
    }

    private var searchBar: some View {
        SearchField(placeholder: "Search by name or alias (e.g. “sema”)", text: $search)
    }

    /// Browse by goal — a horizontal chip rail, "All goals" first. Tapping the active chip clears it.
    private var goalFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.sm) {
                SelectableChip(title: "All goals", isSelected: selectedGoal == nil) { selectedGoal = nil }
                ForEach(CompoundGoal.allCases) { goal in
                    SelectableChip(title: goal.displayName,
                                   isSelected: selectedGoal == goal,
                                   systemImage: goalIcon(goal)) {
                        selectedGoal = (selectedGoal == goal) ? nil : goal
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollClipDisabled()
        .sensoryFeedback(.selection, trigger: selectedGoal)
    }

    /// Result count + active-facet summary + a grade menu + Clear (faceted-filter best practice:
    /// always show how many match and what's applied).
    private var filterSummary: some View {
        HStack(spacing: Space.md) {
            Text("\(resultCount) compound\(resultCount == 1 ? "" : "s")\(activeFilterSuffix)")
                .font(.caption).foregroundStyle(BrandColor.textSecondary)
                .lineLimit(1).minimumScaleFactor(0.85)
            Spacer(minLength: Space.sm)
            gradeMenu
            if isFiltering {
                Button("Clear") { search = ""; selectedGoal = nil; selectedTier = nil }
                    .font(.caption.weight(.semibold))
                    .tint(BrandColor.accentText)
            }
        }
    }

    private var gradeMenu: some View {
        Menu {
            Button { selectedTier = nil } label: {
                Label("All grades", systemImage: selectedTier == nil ? "checkmark" : "")
            }
            ForEach(EvidenceTier.allCases, id: \.self) { tier in
                Button { selectedTier = tier } label: {
                    Label("\(tier.letter) · \(tier.shortLabel)", systemImage: selectedTier == tier ? "checkmark" : "")
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                Text(selectedTier == nil ? "Grade" : "Grade \(selectedTier!.letter)")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(BrandColor.accentText)
        }
    }

    private var activeFilterSuffix: String {
        var parts: [String] = []
        if let g = selectedGoal { parts.append(g.displayName) }
        if let t = selectedTier { parts.append("Grade \(t.letter)") }
        return parts.isEmpty ? "" : " · " + parts.joined(separator: " · ")
    }

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
        "No compounds match your filters. Try a different name, or clear the goal and grade filters to see the full library."
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
                                TagChip(text: "WADA", color: BrandColor.warning)
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
            EvidenceBadge(tier: tier)
            VStack(alignment: .leading, spacing: 2) {
                Text(tier.label).font(.caption.weight(.semibold)).foregroundStyle(BrandColor.textPrimary)
                Text(desc).font(.caption2).foregroundStyle(BrandColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }
}

struct CompoundRow: View {
    let compound: Compound
    var isCustom: Bool = false

    private var tagline: String? { isCustom ? nil : CompoundProfiles.profile(for: compound)?.tagline }

    var body: some View {
        Card {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(compound.name).font(Typo.headline).foregroundStyle(BrandColor.textPrimary)
                    if let tagline {
                        Text(tagline).font(.caption).foregroundStyle(BrandColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(subtitle).font(.caption2).foregroundStyle(BrandColor.textSecondary)
                }
                Spacer(minLength: Space.sm)
                VStack(alignment: .trailing, spacing: Space.xs) {
                    if isCustom {
                        TagChip(text: "Custom", color: BrandColor.accentText)
                    } else {
                        EvidenceBadge(tier: compound.evidenceTier)
                        if compound.wadaProhibited { TagChip(text: "WADA", color: BrandColor.warning) }
                    }
                }
            }
        }
    }

    private var subtitle: String {
        var parts = [compound.category.displayName]
        if let h = compound.halfLifeHours { parts.append(halfLifeShort(h)) }
        return parts.joined(separator: " · ")
    }
    private func halfLifeShort(_ h: Double) -> String {
        if h >= 24 { return "t½ ~\(Int((h / 24).rounded())) d" }
        if h >= 1 { return "t½ ~\(Int(h.rounded())) h" }
        return "t½ <1 h"
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

    private var profile: CompoundProfile? { isCustom ? nil : CompoundProfiles.profile(for: compound) }
    private var goals: [CompoundGoal] { isCustom ? [] : CompoundProfiles.goals(for: compound) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                header
                if !goals.isEmpty { goalRow }
                atAGlance
                if let flag = profile?.safetyFlag { safetyStrip(flag) }

                if let p = profile {
                    profileSections(p)
                }
                notesBlock

                if isCustom {
                    DisclaimerBanner(text: Self.customCompoundNote, systemImage: "exclamationmark.triangle")
                } else {
                    relatedSection
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
                    .font(.caption).foregroundStyle(BrandColor.textSecondary)
            }
            HStack(spacing: Space.sm) {
                if isCustom {
                    TagChip(text: "Custom", color: BrandColor.accentText)
                } else {
                    EvidenceBadge(tier: compound.evidenceTier)
                    TagChip(text: regulatoryShort, color: regulatoryColor)
                    if compound.wadaProhibited { TagChip(text: "WADA", color: BrandColor.warning) }
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
            .padding(.horizontal, 2)
        }
        .scrollClipDisabled()
    }

    private var atAGlance: some View {
        Card {
            VStack(alignment: .leading, spacing: Space.md) {
                detailRow("Class", compound.category.displayName)
                if isCustom {
                    detailRow("Source", "Added by you")
                } else {
                    detailRow("Regulatory status", regulatoryLabel)
                    detailRow("Evidence", "\(compound.evidenceTier.letter) · \(compound.evidenceTier.shortLabel)")
                }
                if let h = compound.halfLifeHours { detailRow("Half-life", halfLifeLong(h)) }
                detailRow("Dosed in", compound.preferredDoseUnit.rawValue)
            }
        }
    }

    private func safetyStrip(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Space.sm) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(BrandColor.warning)
            Text(text).font(.footnote).foregroundStyle(BrandColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.md)
        .background(BrandColor.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
    }

    // MARK: Authored sections (plain answer visible, the rest as accordions)

    @ViewBuilder private func profileSections(_ p: CompoundProfile) -> some View {
        if let what = p.whatItIs, !what.isEmpty {
            VStack(alignment: .leading, spacing: Space.sm) {
                SectionHeader(title: "What it does")
                proseText(what)
            }
        }
        if let m = p.howItWorks, !m.isEmpty {
            disclosure("mechanism", "How it works", scent: "The pharmacology, in brief") { proseText(m) }
        }
        if p.dosingStudied != nil || p.dosingCommunity != nil {
            disclosure("dosing", "Reported dosing", scent: "Studied vs community — not a prescription") { dosingBody(p) }
        }
        if let s = p.sideEffects, !s.isEmpty {
            disclosure("sides", "Side effects & when to stop", scent: "Common vs serious — and the red flags") { proseText(s) }
        }
        if let e = p.whatToExpect, !e.isEmpty {
            disclosure("expect", "What to expect", scent: "Timeline, and expectations vs reality") { proseText(e) }
        }
        if let ev = p.evidenceSummary, !ev.isEmpty {
            disclosure("evidence", "Evidence & research",
                       scent: "Why it's graded \(compound.evidenceTier.letter) · \(compound.evidenceTier.shortLabel)") { evidenceBody(ev) }
        }
        if let r = p.route, !r.isEmpty {
            disclosure("route", "Route & injection site", scent: "How and where it's given") { proseText(r) }
        }
        if let t = p.timing, !t.isEmpty {
            disclosure("timing", "Timing", scent: "Half-life and when it's taken") { proseText(t) }
        }
        if let st = p.storageHandling, !st.isEmpty {
            disclosure("storage", "Storage & beyond-use", scent: "Fridge, light, and the 28-day window") { proseText(st) }
        }
        // Vendor-neutral sourcing literacy — the community's #2 question, and PinWise's differentiator
        // from the vendor-shilling reference sites. Shared content; shown for every catalog compound.
        disclosure("legit", "How to tell it's legit", scent: "Reading a COA — no sellers named") { proseText(Self.coaLiteracy) }
        if let stk = p.stacking, !stk.isEmpty {
            disclosure("stack", "Stacking", scent: "What it's commonly combined with") { proseText(stk) }
        }
        if !p.misconceptions.isEmpty {
            disclosure("myths", "Common misconceptions", scent: "Myths, corrected") { misconceptionsBody(p) }
        }
    }

    @ViewBuilder private var notesBlock: some View {
        if !compound.notes.isEmpty {
            if profile == nil || isCustom {
                VStack(alignment: .leading, spacing: Space.sm) {
                    SectionHeader(title: isCustom ? "Notes" : "Regulatory & notes")
                    proseText(compound.notes)
                }
            } else {
                disclosure("notes", "Regulatory & notes", scent: "Status, corrections, and caveats") { proseText(compound.notes) }
            }
        }
    }

    private func dosingBody(_ p: CompoundProfile) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            if let s = p.dosingStudied { labeledDose("In studies / on the label", s) }
            if let c = p.dosingCommunity { labeledDose("Reported by the community", c) }
            // The community's #1 misconception, taught inline: units are volume, not dose.
            Text("Units are volume, not dose — how much you draw depends on your vial's concentration. The calculator turns a target dose into exact syringe units for your vial.")
                .font(.caption).foregroundStyle(BrandColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button { showCalculator = true } label: {
                Label("Open dose calculator", systemImage: "syringe.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(BrandColor.accentText)
            }
            Text("Reported ranges, not a recommendation. You set your own dose — ideally with a clinician.")
                .font(.caption2).foregroundStyle(BrandColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func evidenceBody(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                EvidenceBadge(tier: compound.evidenceTier)
                Text(compound.evidenceTier.label).font(.caption).foregroundStyle(BrandColor.textSecondary)
            }
            proseText(text)
            Button { showLegend = true } label: {
                Label("What do the grades mean?", systemImage: "info.circle")
                    .font(.caption.weight(.semibold)).foregroundStyle(BrandColor.accentText)
            }
        }
    }

    private func misconceptionsBody(_ p: CompoundProfile) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            ForEach(Array(p.misconceptions.enumerated()), id: \.offset) { _, m in
                HStack(alignment: .top, spacing: Space.sm) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption).foregroundStyle(BrandColor.mint).padding(.top, 2)
                    Text(m).font(Typo.body).foregroundStyle(BrandColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func labeledDose(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(Typo.caption).fontWeight(.semibold).tracking(1)
                .foregroundStyle(BrandColor.textSecondary)
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
            VStack(alignment: .leading, spacing: Space.sm) {
                SectionHeader(title: "Often compared with")
                ForEach(related) { c in
                    NavigationLink { CompoundDetailView(compound: c) } label: {
                        Card {
                            HStack(spacing: Space.sm) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.name).font(Typo.body).foregroundStyle(BrandColor.textPrimary)
                                    if let t = CompoundProfiles.profile(for: c)?.tagline {
                                        Text(t).font(.caption).foregroundStyle(BrandColor.textSecondary).lineLimit(1)
                                    }
                                }
                                Spacer(minLength: Space.sm)
                                EvidenceBadge(tier: c.evidenceTier, compact: true)
                                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(BrandColor.textSecondary)
                            }
                        }
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            DisclaimerBanner(text: "PinWise is a tracking tool, not medical advice. This page is educational reference — it doesn't tell you whether, or how much, to use anything. Talk to a licensed clinician before you start, change, or stop any compound.")
            if let p = profile {
                Text("Last reviewed \(p.lastReviewed) · PinWise editorial")
                    .font(.caption2).foregroundStyle(BrandColor.textSecondary)
            }
        }
    }

    // MARK: Helpers

    /// A caller-state accordion for one section. Renders nothing extra when the id isn't in
    /// `expanded`; toggling flips it (multi-open allowed, choice persists for the session).
    @ViewBuilder private func disclosure(_ id: String, _ title: String, scent: String? = nil,
                                         @ViewBuilder content: () -> some View) -> some View {
        DisclosureSection(title: title, scent: scent, isExpanded: expanded.contains(id)) {
            if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
        } content: {
            content()
        }
    }

    private func proseText(_ t: String) -> some View {
        Text(t).font(Typo.body).foregroundStyle(BrandColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The one place a strong warning stays by design: compounds the user added themselves.
    static let customCompoundNote = "You're adding this compound yourself, so PinWise has no verified data on it. Confirm its identity, purity, and handling against your supplier's certificate of analysis. PinWise makes no assurances for user-added compounds and takes no responsibility for them."

    /// Vendor-neutral certificate-of-analysis literacy — shared across compounds. Deliberately names
    /// no seller (the trust-killer on commercial peptide sites); teaches what a real COA shows.
    static let coaLiteracy = "A certificate of analysis (COA) is a third-party lab report on a specific batch. A trustworthy one names an independent lab (not the seller), lists the batch/lot number, and reports identity and purity — typically by mass spectrometry (confirms it's the right molecule) and HPLC (reports % purity, ideally ≥98%). Match the lot on the COA to the lot on your vial; a COA for a different batch tells you nothing about yours. Be skeptical of a bare \"99% pure\" claim with no lab named, no method, and no date. PinWise names no vendors and does not verify supply — this is general literacy so you can read a COA yourself."

    private var regulatoryLabel: String {
        switch compound.regulatoryStatus {
        case .fdaApproved: return "FDA-approved"
        case .compoundedOnly: return "Compounded only"
        case .researchOnly: return "Research only"
        }
    }
    private var regulatoryShort: String {
        switch compound.regulatoryStatus {
        case .fdaApproved: return "FDA-approved"
        case .compoundedOnly: return "Compounded"
        case .researchOnly: return "Research only"
        }
    }
    private var regulatoryColor: Color {
        switch compound.regulatoryStatus {
        case .fdaApproved: return BrandColor.success
        case .compoundedOnly: return BrandColor.warning
        case .researchOnly: return BrandColor.textSecondary
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
                                TextField("e.g. KPV", text: $name).pinwiseField()
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
                            FieldRow("Notes", hint: "Optional — source, batch, anything worth remembering.") {
                                TextField("Anything worth remembering", text: $notes, axis: .vertical).pinwiseField()
                            }
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

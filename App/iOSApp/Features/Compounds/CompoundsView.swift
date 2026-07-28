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
    @State private var showLegend = false
    @State private var showAdd = false

    private var query: String { search.trimmingCharacters(in: .whitespaces).lowercased() }

    /// Alphabetical, filtered by search text and (optionally) the selected goal.
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                searchBar
                goalFilterBar

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
                    if !results.isEmpty { SectionHeader(title: "Library") }
                }

                if results.isEmpty && customResults.isEmpty {
                    Card {
                        Text(emptyMessage)
                            .font(Typo.body).foregroundStyle(BrandColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    ForEach(results, id: \.id) { compound in
                        NavigationLink { CompoundDetailView(compound: compound) } label: {
                            CompoundRow(compound: compound)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }

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
                    .accessibilityLabel("What the tiers and labels mean")
            }
        }
        .sheet(isPresented: $showLegend) { CompoundLegendView() }
        .sheet(isPresented: $showAdd) { AddCustomCompoundView() }
    }

    private var searchBar: some View {
        SearchField(placeholder: "Search compounds", text: $search)
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

    private var emptyMessage: String {
        if let goal = selectedGoal, query.isEmpty {
            return "No compounds tagged “\(goal.displayName)” yet. Clear the goal filter to see the full library."
        }
        return "No compounds match “\(search)”. Try a different name, clear the goal filter, or add your own below."
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
                            SectionHeader(title: "Evidence tiers")
                            Text("How much human evidence backs a compound. Higher tiers mean stronger proof it works and is safe in people.")
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
struct CompoundDetailView: View {
    let compound: Compound
    var isCustom: Bool = false

    private var profile: CompoundProfile? { isCustom ? nil : CompoundProfiles.profile(for: compound) }
    private var goals: [CompoundGoal] { isCustom ? [] : CompoundProfiles.goals(for: compound) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                header
                if !goals.isEmpty { goalRow }
                atAGlance
                if let p = profile { profileSections(p) }
                if !compound.notes.isEmpty { notesSection }
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
    }

    // MARK: Header

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
                detailRow("Category", compound.category.displayName)
                if isCustom {
                    detailRow("Source", "Added by you")
                } else {
                    detailRow("Regulatory status", regulatoryLabel)
                    detailRow("Evidence", compound.evidenceTier.label)
                }
                if let h = compound.halfLifeHours { detailRow("Half-life", halfLifeLong(h)) }
                detailRow("Dosed in", compound.preferredDoseUnit.rawValue)
            }
        }
    }

    // MARK: Authored sections

    @ViewBuilder private func profileSections(_ p: CompoundProfile) -> some View {
        prose("What it is", [p.whatItIs, p.howItWorks])
        prose("What to expect", [p.whatToExpect])
        prose("Evidence & research", [p.evidenceSummary])
        dosingSection(p)
        prose("Route & injection site", [p.route])
        prose("Timing", [p.timing])
        prose("Side effects & when to stop", [p.sideEffects])
        prose("How it's stacked", [p.stacking])
        prose("Storage & handling", [p.storageHandling])
        misconceptionsSection(p)
    }

    /// A titled block of one or more paragraphs; renders nothing if every paragraph is empty/nil.
    @ViewBuilder private func prose(_ title: String, _ paragraphs: [String?]) -> some View {
        let items = paragraphs.compactMap { $0 }.filter { !$0.isEmpty }
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: Space.sm) {
                SectionHeader(title: title)
                ForEach(Array(items.enumerated()), id: \.offset) { _, text in
                    Text(text).font(Typo.body).foregroundStyle(BrandColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder private func dosingSection(_ p: CompoundProfile) -> some View {
        if p.dosingStudied != nil || p.dosingCommunity != nil {
            VStack(alignment: .leading, spacing: Space.sm) {
                SectionHeader(title: "Typical doses seen")
                if let s = p.dosingStudied { labeledDose("In studies / on the label", s) }
                if let c = p.dosingCommunity { labeledDose("Reported by the community", c) }
                Text("These are ranges reported in research or by users — not a recommendation or a prescription. You always set your own dose, ideally with a clinician. Use the reconstitution calculator to turn a target dose into syringe units.")
                    .font(.caption).foregroundStyle(BrandColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
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

    @ViewBuilder private func misconceptionsSection(_ p: CompoundProfile) -> some View {
        if !p.misconceptions.isEmpty {
            VStack(alignment: .leading, spacing: Space.sm) {
                SectionHeader(title: "Common misconceptions")
                ForEach(Array(p.misconceptions.enumerated()), id: \.offset) { _, m in
                    HStack(alignment: .top, spacing: Space.sm) {
                        Image(systemName: "checkmark.seal")
                            .font(.caption).foregroundStyle(BrandColor.mint).padding(.top, 2)
                        Text(m).font(Typo.body).foregroundStyle(BrandColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(title: profile == nil ? "Notes" : "Regulatory & notes")
            Text(compound.notes).font(Typo.body).foregroundStyle(BrandColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
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

    /// The one place a strong warning stays by design: compounds the user added themselves.
    static let customCompoundNote = "You're adding this compound yourself, so PinWise has no verified data on it. Confirm its identity, purity, and handling against your supplier's certificate of analysis. PinWise makes no assurances for user-added compounds and takes no responsibility for them."

    private var regulatoryLabel: String {
        switch compound.regulatoryStatus {
        case .fdaApproved: return "FDA-approved"
        case .compoundedOnly: return "Compounded only"
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

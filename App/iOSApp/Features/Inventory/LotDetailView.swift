import SwiftUI
import SwiftData
import PeptideKit
import PhotosUI
import UniformTypeIdentifiers

/// One batch: its identity, the vials drawn from it, the COA documents you've attached, and the
/// values those documents report.
///
/// The COA values here are **what a document reported** — deliberately a different fact from
/// `StoredVial.coa*Percent`, which is *the numbers you chose to dose by*. Those legitimately diverge
/// (a typo, a COA that turns out to be for another batch, a decision to dose off the label), and
/// showing both is what makes this a record rather than a form. "Apply to vials on this lot" is the
/// one explicit, consequence-shown way to reconcile them — never a silent write-through.
struct LotDetailView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var context
    let lot: StoredLot

    @Query private var vials: [StoredVial]
    @Query(sort: \COAAttachment.dateAdded, order: .reverse) private var allAttachments: [COAAttachment]
    @Query private var doses: [LoggedDose]

    @State private var showEdit = false
    @State private var showCamera = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var expanded: Set<UUID> = []
    @State private var showTestingRequest = false
    @State private var pendingApply: COAAttachment?

    private var attachments: [COAAttachment] { allAttachments.filter { $0.lotID == lot.id } }
    private var linkedVials: [StoredVial] { vials.filter { $0.lotID == lot.id } }
    private var linkedDoses: [LoggedDose] { doses.filter { $0.lotID == lot.id } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                identityCard
                documentsSection
                linkedSection
                requestTestingCard
                DisclaimerBanner(text: "These are documents and values you entered yourself. Staxyz doesn't verify certificates of analysis and doesn't vet suppliers.")
                literacyCard
            }
            .padding(Space.lg)
        }
        .screenBackground()
        .navigationTitle(lot.lotNumber.isEmpty ? "Lot" : lot.lotNumber)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) { LotBuilderView(editing: lot) }
        .sheet(isPresented: $showTestingRequest) { TestingRequestView(lot: lot) }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(isPresented: $showCamera) { addImage($0) }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) { addImage(image) }
                pickerItem = nil
            }
        }
        .fileImporter(isPresented: $showFileImporter,
                      allowedContentTypes: [.pdf, .image],
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first { addFile(url) }
        }
        .confirmationDialog("Apply these values?",
                            isPresented: Binding(get: { pendingApply != nil },
                                                 set: { if !$0 { pendingApply = nil } }),
                            titleVisibility: .visible) {
            if let doc = pendingApply {
                Button("Apply to \(linkedVials.count) vial\(linkedVials.count == 1 ? "" : "s")") { apply(doc) }
            }
            Button("Cancel", role: .cancel) { pendingApply = nil }
        } message: {
            Text(applyConsequence ?? "")
        }
    }

    // MARK: - Identity

    private var identityCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack(spacing: Space.sm) {
                    if !lot.lotNumber.isEmpty { TagChip(text: lot.lotNumber) }
                    Text(lot.compoundName.isEmpty ? "Unnamed compound" : lot.compoundName)
                        .font(Typo.headline).foregroundStyle(BrandColor.textPrimary)
                    Spacer(minLength: 0)
                }
                if !lot.vendor.isEmpty {
                    Text(lot.vendor).font(Typo.footnote).foregroundStyle(BrandColor.textSecondary)
                }
                Divider().overlay(BrandColor.stroke)
                HStack(alignment: .top, spacing: Space.md) {
                    StatTile(label: "Received", value: dateText(lot.dateReceived), compact: true)
                    StatTile(label: "Opened", value: dateText(lot.dateOpened), compact: true)
                    StatTile(label: "Mixed", value: dateText(lot.dateReconstituted), compact: true)
                }
                if !lot.notes.isEmpty {
                    Text(lot.notes).font(Typo.caption).foregroundStyle(BrandColor.textSecondary)
                }
            }
        }
    }

    private func dateText(_ d: Date?) -> String {
        d?.formatted(.dateTime.month(.abbreviated).day()) ?? "—"
    }

    // MARK: - COA documents

    @ViewBuilder
    private var documentsSection: some View {
        SectionHeader(title: "COA documents")
        if attachments.isEmpty {
            ThemedEmptyState(icon: "doc.text.magnifyingglass",
                             title: "No COA attached",
                             message: "Attach the certificate that came with this batch — a photo or the PDF. You can record what it reports, and match its lot number against the vial's.")
        }
        HStack(spacing: Space.md) {
            Button { showCamera = true } label: {
                Label("Take photo", systemImage: "camera.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, Space.md)
                    .background(BrandColor.ctaFill, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                    .foregroundStyle(BrandColor.onCtaFill)
            }
            .buttonStyle(.plain)
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Library", systemImage: "photo.on.rectangle")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, Space.md)
                    .background(BrandColor.surfaceElevated, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous).strokeBorder(BrandColor.stroke, lineWidth: 1))
                    .foregroundStyle(BrandColor.textPrimary)
            }
            Button { showFileImporter = true } label: {
                Label("File", systemImage: "doc")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, Space.md)
                    .background(BrandColor.surfaceElevated, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous).strokeBorder(BrandColor.stroke, lineWidth: 1))
                    .foregroundStyle(BrandColor.textPrimary)
            }
            .buttonStyle(.plain)
        }
        if !attachments.isEmpty {
            // Truthful, not alarming. The app cannot claim to be a record of what was in the vial and
            // simultaneously leave the user assuming their evidence is backed up — there is no iCloud
            // sync today, and SwiftData+CloudKit would sync the STORE, not files in Application
            // Support. Naming the escape hatch in the same breath keeps it useful rather than scary.
            Text("COA documents are stored on this device only — they aren't backed up or synced. Use Share on a document, or Settings → Export data, to keep a copy elsewhere.")
                .font(Typo.caption).foregroundStyle(BrandColor.textSecondary)
        }
        ForEach(attachments) { doc in
            COADocumentCard(doc: doc,
                            isExpanded: expanded.contains(doc.id),
                            toggle: { toggle(doc.id) },
                            canApply: doc.hasPotencyData && !linkedVials.isEmpty,
                            onApply: { pendingApply = doc },
                            onDelete: { delete(doc) })
        }
    }

    private func toggle(_ id: UUID) {
        withAnimation(Motion.gated(Motion.disclosure, reduceMotion)) {
            if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
        }
    }

    // MARK: - What this lot is linked to

    @ViewBuilder
    private var linkedSection: some View {
        if !linkedVials.isEmpty || !linkedDoses.isEmpty {
            SectionHeader(title: "Used by")
            Card {
                VStack(alignment: .leading, spacing: Space.sm) {
                    HStack(alignment: .top, spacing: Space.md) {
                        StatTile(label: "Vials", value: "\(linkedVials.count)", compact: true)
                        StatTile(label: "Doses logged", value: "\(linkedDoses.count)", compact: true)
                    }
                    if !linkedDoses.isEmpty {
                        Text("Doses keep this lot number even if the vial or the lot is later removed.")
                            .font(Typo.caption).foregroundStyle(BrandColor.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Request testing (demand capture only)

    private var requestTestingCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Space.md) {
                SectionHeader(title: "Independent testing")
                Text("Want this batch tested by a lab rather than trusting the COA that came with it? Register interest and Staxyz will use it to prioritise testing partnerships.")
                    .font(Typo.caption).foregroundStyle(BrandColor.textSecondary)
                SecondaryButton(title: "Request testing", systemImage: "flask") { showTestingRequest = true }
            }
        }
    }

    private var literacyCard: some View {
        DisclosureSection(title: "How to read a COA",
                          scent: "What a strong certificate includes",
                          isExpanded: expanded.contains(Self.literacyKey),
                          toggle: { toggle(Self.literacyKey) }) {
            // Reuses the copy already authored for the compound library rather than writing a second
            // version of the same guidance.
            Text(CompoundDetailView.coaLiteracy)
                .font(Typo.caption).foregroundStyle(BrandColor.textSecondary)
        }
    }
    private static let literacyKey = UUID()

    // MARK: - Mutations

    private func addImage(_ image: UIImage) {
        guard let name = COADocumentStore.save(image) else { return }
        context.insert(COAAttachment(lotID: lot.id, filename: name, fileKindRaw: COADocumentKind.image.rawValue,
                                     originalFilename: "Photo"))
        try? context.save()
    }

    private func addFile(_ url: URL) {
        guard let saved = COADocumentStore.save(fileAt: url) else { return }
        context.insert(COAAttachment(lotID: lot.id, filename: saved.filename,
                                     fileKindRaw: saved.kind.rawValue,
                                     originalFilename: url.lastPathComponent))
        try? context.save()
    }

    private func delete(_ doc: COAAttachment) {
        // File first, then the record — the same order as PhysiqueView, so a failure can't orphan a
        // record pointing at bytes that are already gone.
        COADocumentStore.delete(named: doc.filename)
        context.delete(doc)
        try? context.save()
    }

    /// Spells out the effect in doses-per-vial BEFORE the user commits, so applying a document's
    /// values is an informed choice rather than a silent change to dose math.
    private var applyConsequence: String? {
        guard let doc = pendingApply, let vial = linkedVials.first else { return nil }
        let before = vial.totalDoses
        let after = Int((vial.primaryMass.micrograms * doc.report.netFactor) / Swift.max(vial.perDose.micrograms, 1))
        let pct = String(format: "%.1f%%", doc.report.netFactor * 100)
        return "This COA reports \(pct) of label. Applying it changes \(vial.displayName) from \(before) to \(after) doses per vial."
    }

    private func apply(_ doc: COAAttachment) {
        for vial in linkedVials where !vial.isPremixed {
            vial.assayPercentFromCOA(doc)
        }
        try? context.save()
        pendingApply = nil
    }
}

private extension StoredVial {
    /// Copies a document's reported potency onto the vial's own dosing values.
    ///
    /// Only the percentages the document actually states are copied — a blank field on a COA is not a
    /// claim of 100%, and overwriting a user's existing number with nil would silently change their
    /// dose math in the opposite direction.
    func assayPercentFromCOA(_ doc: COAAttachment) {
        if let a = doc.assayPercent, a > 0 { coaAssayPercent = a }
        if let c = doc.contentPercent, c > 0 { coaContentPercent = c }
        if let p = doc.purityPercent, p > 0 { coaPurityPercent = p }
    }
}

/// One attached document: a thumbnail, what it reports, and the editable structured fields.
private struct COADocumentCard: View {
    @Bindable var doc: COAAttachment
    let isExpanded: Bool
    let toggle: () -> Void
    let canApply: Bool
    let onApply: () -> Void
    let onDelete: () -> Void

    @State private var purity = ""
    @State private var assay = ""
    @State private var content = ""
    @State private var endotoxin = ""

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Space.md) {
                Button(action: toggle) {
                    HStack(spacing: Space.md) {
                        thumbnail
                        VStack(alignment: .leading, spacing: Space.xxs) {
                            Text(doc.originalFilename.isEmpty ? "COA document" : doc.originalFilename)
                                .font(Typo.body).foregroundStyle(BrandColor.textPrimary).lineLimit(1)
                            Text(doc.reportedSummary)
                                .font(Typo.caption).foregroundStyle(BrandColor.textSecondary).lineLimit(2)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(Typo.captionEmphasis).foregroundStyle(BrandColor.textSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: Space.lg) {
                        Text("What this document reports — as printed on it. These are separate from the numbers your vial doses by.")
                            .font(Typo.caption).foregroundStyle(BrandColor.textSecondary)
                        percentRow("Purity %", text: $purity) { doc.purityPercent = $0 }
                        percentRow("Assay %", text: $assay) { doc.assayPercent = $0 }
                        percentRow("Peptide content %", text: $content) { doc.contentPercent = $0 }
                        FieldRow("Endotoxin", hint: "Recorded for safety. Never used in potency math.") {
                            HStack {
                                TextField("e.g. 0.25", text: $endotoxin)
                                    .keyboardType(.decimalPad).staxyzField()
                                    .onChange(of: endotoxin) { _, v in doc.endotoxinValue = v.decimalValue }
                                Picker("", selection: Binding(
                                    get: { doc.endotoxinUnit },
                                    set: { doc.endotoxinUnitRaw = $0.rawValue })) {
                                    ForEach(EndotoxinUnit.allCases, id: \.self) { Text($0.label).tag($0) }
                                }
                                // Was `.frame(width: 150)` with ~3pt of headroom at the default
                                // size. `EU/mg` vs `EU/vial` are different measurements, and this
                                // file records endotoxin "for safety" — a truncated unit makes the
                                // number meaningless. Segmented while it fits, menu when it doesn't.
                                .pickerStyle(.segmented)
                                .fixedSize()
                            }
                        }
                        FieldRow("Lab", hint: "Free text — Staxyz keeps no lab list.") {
                            TextField("Who tested it", text: $doc.labName).staxyzField()
                        }
                        FieldRow("Method notes") {
                            TextField("e.g. HPLC-UV, MS identity", text: $doc.methodNotes).staxyzField()
                        }
                        if canApply {
                            SecondaryButton(title: "Apply to vials on this lot", systemImage: "arrow.down.doc") { onApply() }
                        }
                        // The user's OWN file, leaving on their own initiative — which is why this is
                        // a share sheet and not an upload. It's also the practical answer to "I need
                        // to send this to my doctor", and the per-document half of the backup story.
                        if let url = fileURL {
                            ShareLink(item: url) {
                                Label("Share document", systemImage: "square.and.arrow.up")
                                    .font(Typo.captionEmphasis)
                                    .frame(maxWidth: .infinity).padding(.vertical, Space.md)
                                    .background(BrandColor.surfaceElevated, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous).strokeBorder(BrandColor.stroke, lineWidth: 1))
                                    .foregroundStyle(BrandColor.textPrimary)
                            }
                            .buttonStyle(.plain)
                        }
                        Button(role: .destructive, action: onDelete) {
                            Label("Remove document", systemImage: "trash")
                                .font(Typo.captionEmphasis)
                        }
                    }
                }
            }
        }
        .task {
            purity = doc.purityPercent.map { fmt($0) } ?? ""
            assay = doc.assayPercent.map { fmt($0) } ?? ""
            content = doc.contentPercent.map { fmt($0) } ?? ""
            endotoxin = doc.endotoxinValue.map { fmt($0) } ?? ""
        }
    }

    private func percentRow(_ title: String, text: Binding<String>,
                            set: @escaping (Double?) -> Void) -> some View {
        FieldRow(title) {
            HStack {
                TextField("e.g. 99.5", text: text).keyboardType(.decimalPad).staxyzField()
                    .onChange(of: text.wrappedValue) { _, v in set(v.decimalValue) }
                Text("%").foregroundStyle(BrandColor.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .fill(BrandColor.surfaceElevated)
            if doc.kind == .image, let img = COADocumentStore.image(named: doc.filename) {
                Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: doc.kind == .pdf ? "doc.richtext" : "doc.text")
                    .font(.title3).foregroundStyle(BrandColor.textSecondary)
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
    }

    /// nil when the bytes are missing — a record can outlive its file if the app's container is
    /// rebuilt, so the share affordance hides rather than offering a broken export.
    private var fileURL: URL? {
        COADocumentStore.exists(named: doc.filename) ? COADocumentStore.url(named: doc.filename) : nil
    }

    private func fmt(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.4g", v)
    }
}

import SwiftUI
import SwiftData
import PeptideKit
import PhotosUI

/// The lot ledger — every batch you've recorded, and the COA documents attached to each.
///
/// Reached from a row at the bottom of the vials list rather than a third Stack segment (three
/// segments crowd the picker and complicate its data-backed landing logic) or a Tools tile (which
/// would auto-append to every user's grid and compete with ten established tools).
struct LotsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \StoredLot.dateAdded, order: .reverse) private var lots: [StoredLot]
    @Query private var vials: [StoredVial]
    @Query private var attachments: [COAAttachment]
    @State private var showBuilder = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Text("A lot is the batch a vial came from. Recording it is what lets a certificate of analysis — and every dose you log — point at a specific batch instead of a compound in general.")
                    .font(Typo.body).foregroundStyle(BrandColor.textSecondary)

                PrimaryButton(title: "Add a lot", systemImage: "plus") { showBuilder = true }

                if lots.isEmpty {
                    ThemedEmptyState(icon: "shippingbox",
                                     title: "No lots yet",
                                     message: "Add a lot to track what was actually in the vial — the vendor, the lot number, and the COA that came with it.")
                } else {
                    SectionHeader(title: "Your lots")
                    ForEach(lots) { lot in
                        NavigationLink {
                            LotDetailView(lot: lot)
                        } label: {
                            LotRow(lot: lot,
                                   vialCount: vials.filter { $0.lotID == lot.id }.count,
                                   docCount: attachments.filter { $0.lotID == lot.id }.count)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
            .padding(Space.lg)
        }
        .screenBackground()
        .navigationTitle("Lots & COAs")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showBuilder) { LotBuilderView() }
    }
}

/// Fixed 3-slot layout, mirroring `VialRow`'s discipline so the same fact is always in the same spot.
private struct LotRow: View {
    let lot: StoredLot
    let vialCount: Int
    let docCount: Int

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack(spacing: Space.sm) {
                    if !lot.lotNumber.isEmpty {
                        TagChip(text: lot.lotNumber)
                    }
                    Text(lot.compoundName.isEmpty ? "Unnamed compound" : lot.compoundName)
                        .font(Typo.headline).foregroundStyle(BrandColor.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold)).foregroundStyle(BrandColor.textSecondary)
                }
                if !lot.vendor.isEmpty {
                    Text(lot.vendor).font(Typo.caption2).foregroundStyle(BrandColor.textSecondary)
                }
                Divider().overlay(BrandColor.stroke)
                // `—` placeholders so nothing shifts between rows.
                HStack(alignment: .top, spacing: Space.md) {
                    StatTile(label: "Vials", value: vialCount == 0 ? "—" : "\(vialCount)", compact: true)
                    StatTile(label: "Received",
                             value: lot.dateReceived?.formatted(.dateTime.month(.abbreviated).day()) ?? "—",
                             compact: true)
                    StatTile(label: "COA", value: docCount == 0 ? "—" : "\(docCount)", compact: true)
                }
            }
        }
    }
}

/// Add or amend a lot's identity fields on their own, for users who record provenance before (or
/// without) creating a vial.
struct LotBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \CustomCompound.name) private var customCompounds: [CustomCompound]
    var editing: StoredLot?

    @State private var compound: Compound = CompoundCatalog.semaglutide
    @State private var vendor = ""
    @State private var lotNumber = ""
    @State private var hasReceived = false
    @State private var received = Date()
    @State private var notes = ""
    @State private var showNotes = false

    private var compoundOptions: [Compound] {
        CompoundCatalog.all + customCompounds.map { $0.asCompound }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Card {
                        VStack(alignment: .leading, spacing: Space.lg) {
                            FieldRow("Compound") {
                                CompoundMenu(selection: $compound, options: compoundOptions)
                            }
                            FieldRow("Lot number", hint: "As printed on the vial or the COA.") {
                                TextField("e.g. A24-118", text: $lotNumber)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.characters)
                                    .staxyzField()
                            }
                            FieldRow("Vendor or source", hint: "Free text. Staxyz doesn't vet suppliers or keep a vendor list.") {
                                TextField("Who you got it from", text: $vendor)
                                    .autocorrectionDisabled()
                                    .staxyzField()
                            }
                            Toggle("Record a received date", isOn: $hasReceived)
                                .font(Typo.body).tint(BrandColor.controlOn)
                            if hasReceived {
                                DatePicker("Received", selection: $received, displayedComponents: .date)
                                    .font(Typo.body)
                            }
                            CollapsibleNoteField(text: $notes, expanded: $showNotes)
                        }
                    }
                    PrimaryButton(title: editing == nil ? "Add lot" : "Save changes",
                                  systemImage: editing == nil ? "plus" : "checkmark") { save() }
                }
                .padding(Space.lg)
            }
            .screenBackground()
            .navigationTitle(editing == nil ? "New lot" : "Edit lot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .task {
                guard let lot = editing else { return }
                compound = compoundOptions.first { $0.name == lot.compoundName } ?? compound
                vendor = lot.vendor
                lotNumber = lot.lotNumber
                hasReceived = lot.dateReceived != nil
                received = lot.dateReceived ?? Date()
                notes = lot.notes
                showNotes = !lot.notes.isEmpty
            }
        }
    }

    private func save() {
        let number = lotNumber.trimmingCharacters(in: .whitespaces)
        let source = vendor.trimmingCharacters(in: .whitespaces)
        // A lot with neither a number nor a vendor records nothing — don't create an empty row.
        guard !number.isEmpty || !source.isEmpty else { dismiss(); return }
        let target = editing ?? StoredLot()
        target.compoundName = compound.name
        target.vendor = source
        target.lotNumber = number
        target.dateReceived = hasReceived ? received : nil
        target.notes = notes
        if editing == nil { context.insert(target) }
        try? context.save()
        dismiss()
    }
}

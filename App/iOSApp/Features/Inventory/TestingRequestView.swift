import SwiftUI
import SwiftData

/// Register interest in having a batch independently tested.
///
/// **Demand capture, not commerce.** No payment, no shipping, no lab booking, and no claim that
/// testing will happen — the confirmation says so in plain words. The purpose is to learn which
/// compounds and test types people actually want covered.
struct TestingRequestView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let lot: StoredLot

    @State private var kinds: Set<TestingKind> = [.potency]
    @State private var notes = ""
    @State private var showNotes = false
    @State private var contact = ""
    @State private var submitted = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    if submitted {
                        confirmation
                    } else {
                        form
                    }
                }
                .padding(Space.lg)
            }
            .screenBackground()
            .navigationTitle("Request testing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: submitted ? .confirmationAction : .cancellationAction) {
                    Button(submitted ? "Done" : "Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var form: some View {
        Card {
            VStack(alignment: .leading, spacing: Space.sm) {
                SectionHeader(title: "Batch")
                Text(lot.compoundName.isEmpty ? "Unnamed compound" : lot.compoundName)
                    .font(Typo.headline).foregroundStyle(BrandColor.textPrimary)
                if !lot.displaySummary.isEmpty {
                    Text(lot.displaySummary).font(Typo.caption).foregroundStyle(BrandColor.textSecondary)
                }
            }
        }

        Card {
            VStack(alignment: .leading, spacing: Space.lg) {
                SectionHeader(title: "What would you want tested?")
                ForEach(TestingKind.allCases) { kind in
                    Button {
                        if kinds.contains(kind) { kinds.remove(kind) } else { kinds.insert(kind) }
                    } label: {
                        HStack(alignment: .top, spacing: Space.md) {
                            Image(systemName: kinds.contains(kind) ? "checkmark.circle.fill" : "circle")
                                .contentTransition(.symbolEffect(.replace.offUp))
                                .font(.title3)
                                .foregroundStyle(kinds.contains(kind) ? BrandColor.accent : BrandColor.textSecondary)
                            VStack(alignment: .leading, spacing: Space.xxs) {
                                Text(kind.label).font(.body.weight(.semibold))
                                    .foregroundStyle(BrandColor.textPrimary)
                                Text(kind.blurb).font(Typo.caption2)
                                    .foregroundStyle(BrandColor.textSecondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                CollapsibleNoteField(text: $notes, expanded: $showNotes,
                                     title: "Anything else",
                                     hint: "Optional.",
                                     placeholder: "What you'd want to know about this batch")
                FieldRow("How should we reach you?", hint: "Optional. Stored on your device only.") {
                    TextField("Email or handle", text: $contact)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .staxyzField()
                }
            }
        }

        PrimaryButton(title: "Register interest", systemImage: "flask") { submit() }
            .disabled(kinds.isEmpty)

        Text("This is not an order. Nothing is charged, nothing is shipped, and no test is booked. Staxyz uses these to decide which testing partnerships to pursue first.")
            .font(Typo.caption2).foregroundStyle(BrandColor.textSecondary)
    }

    @ViewBuilder
    private var confirmation: some View {
        Card(style: .hero) {
            VStack(alignment: .leading, spacing: Space.md) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle).foregroundStyle(BrandColor.success)
                Text("Interest registered")
                    .font(Typo.title).displayTracking().foregroundStyle(BrandColor.textPrimary)
                Text("We'll use this to prioritise testing partnerships. It isn't an order yet — nothing has been charged, shipped, or booked.")
                    .font(Typo.body).foregroundStyle(BrandColor.textSecondary)
            }
        }
        Text("Saved on your device. You can see and remove your requests from this lot at any time.")
            .font(Typo.caption2).foregroundStyle(BrandColor.textSecondary)
    }

    private func submit() {
        let request = TestingRequest(lotID: lot.id,
                                     compoundName: lot.compoundName,
                                     lotNumber: lot.lotNumber,
                                     vendor: lot.vendor,
                                     kindsRaw: TestingRequest.encode(kinds),
                                     notes: notes,
                                     contactPreference: contact)
        context.insert(request)
        try? context.save()
        withAnimation(Motion.gated(Motion.emphasis, reduceMotion)) { submitted = true }
    }
}

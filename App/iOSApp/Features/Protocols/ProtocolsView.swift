import SwiftUI
import SwiftData
import PeptideKit

/// The Stack tab: your vials and your protocols (a "Your vials / Your protocols" segmented
/// control), plus a link into the compound library under Your vials. Landing panel is
/// data-backed: vials for onboarding (no protocols yet), protocols once you have one.
struct ProtocolsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedProtocol.startDate, order: .reverse) private var protocols: [SavedProtocol]
    @Query(sort: \StoredVial.dateAcquired, order: .reverse) private var vials: [StoredVial]
    @Query(sort: \LoggedDose.timestamp, order: .reverse) private var logs: [LoggedDose]
    @Query private var skips: [SkippedDose]
    @State private var showBuilder = false
    @State private var editTarget: EditTarget?
    @State private var panel: Panel = .inventory
    @State private var didSetInitialPanel = false
    private enum Panel: Hashable { case inventory, protocols }
    /// Identifiable wrapper so a tapped protocol can drive `.sheet(item:)` without relying on
    /// the model's own identity semantics.
    private struct EditTarget: Identifiable { let id = UUID(); let proto: SavedProtocol }

    private var active: [SavedProtocol] { protocols.filter(\.isActive) }
    private var inactive: [SavedProtocol] { protocols.filter { !$0.isActive } }

    /// Today's doses, narrowed ONCE per render. `ProtocolPresentation` takes the already-filtered
    /// slice rather than the whole (unbounded, ever-growing) log query, so a screenful of
    /// protocols scans the history once instead of once per card.
    private var todaysLogs: [LoggedDose] {
        logs.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    /// The slot a "Skip this dose" action would decline: the most recent unresolved one — an
    /// overdue day if there is one, else today's dose if it is due and unlogged. nil when there is
    /// nothing to decline, which is what hides the menu item rather than offering a no-op.
    private func skippableSlot(for proto: SavedProtocol) -> Date? {
        guard proto.isActive else { return nil }
        if let overdue = proto.lastOverdueDose(in: logs, skips: skips) { return overdue }
        guard let next = proto.nextDose(), Calendar.current.isDateInToday(next),
              !proto.loggedToday(in: todaysLogs) else { return nil }
        return Calendar.current.startOfDay(for: next)
    }

    /// Records the decision. Same shape as the notification path, so a skip declared in-app and one
    /// declared from a banner are indistinguishable downstream.
    private func skip(_ proto: SavedProtocol, slot: Date) {
        context.insert(SkippedDose(scheduledFor: slot, protocolID: proto.id, protocolName: proto.name))
        try? context.save()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    header

                    Picker("", selection: $panel) {
                        Text("Your vials").tag(Panel.inventory)
                        Text("Your protocols").tag(Panel.protocols)
                    }
                    .pickerStyle(.segmented)

                    if panel == .protocols {
                        protocolsPanel
                    } else {
                        InventoryList()
                    }
                }
                .padding(Space.lg)
            }
            .heroScreen()
            .scrollsToTopOnReselect(.protocols)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showBuilder) { ProtocolBuilderView() }
            .sheet(item: $editTarget) { ProtocolBuilderView(editing: $0.proto) }
            // Consume a one-shot deep-link (e.g. Home's "Your protocols" card) targeting a panel, else
            // pick the data-backed default landing: onboarding (no protocols yet) opens on Your vials —
            // the vial→protocol pipeline — but once you have a protocol you're a returning user
            // checking what you're running, so open on Your protocols. Set once, so a manual switch
            // sticks for the session.
            .onAppear {
                if UserDefaults.standard.string(forKey: "stackRequestedPanel") == "protocols" {
                    panel = .protocols
                    UserDefaults.standard.removeObject(forKey: "stackRequestedPanel")
                    didSetInitialPanel = true
                } else if !didSetInitialPanel {
                    panel = active.isEmpty ? .inventory : .protocols
                    didSetInitialPanel = true
                }
            }
        }
    }

    @ViewBuilder private var protocolsPanel: some View {
        if vials.isEmpty {
            // Protocols are built from vials — route vial-less users to the right first step.
            PrimaryButton(title: "Add a vial first", systemImage: "cross.vial") { panel = .inventory }
        } else {
            PrimaryButton(title: "New protocol", systemImage: "plus") { showBuilder = true }
        }

        if active.isEmpty {
            emptyState
        } else {
            SectionHeader(title: "Active protocols")
            let today = todaysLogs
            ForEach(Array(active.enumerated()), id: \.element.id) { i, proto in
                Button { editTarget = EditTarget(proto: proto) } label: {
                    ProtocolCard(presentation: ProtocolPresentation(
                        proto, vials: vials, todaysLogs: today,
                        overdueSince: proto.lastOverdueDose(in: logs, skips: skips)))
                }
                .buttonStyle(PressableStyle())
                .contextMenu {
                    Button { editTarget = EditTarget(proto: proto) } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    // The first IN-APP way to skip. Until now Skip existed only as a notification
                    // action, so a user who dismissed the banner (or never enabled reminders) had no
                    // way to say "I'm deliberately not taking this" — and the dose would harden into
                    // a red OVERDUE. Offered only while there is actually a slot to decline.
                    if let slot = skippableSlot(for: proto) {
                        Button { skip(proto, slot: slot) } label: {
                            Label("Skip this dose", systemImage: "minus.circle")
                        }
                    }
                    Button { proto.isActive.toggle() } label: {
                        Label(proto.isActive ? "Pause" : "Resume",
                              systemImage: proto.isActive ? "pause.circle" : "play.circle")
                    }
                    Button(role: .destructive) { context.delete(proto) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .entrance(i)
            }
        }

        if !inactive.isEmpty {
            SectionHeader(title: "Inactive").padding(.top, Space.sm)
            // Paused dimming lives INSIDE ProtocolCard — no call-site opacity here.
            // Paused protocols get the SAME presentation as active ones (logs included): the
            // presentation is what decides a paused protocol shows no next pin, so withholding
            // the logs here would only make its status word wrong.
            let today = todaysLogs
            ForEach(Array(inactive.enumerated()), id: \.element.id) { i, proto in
                Button { editTarget = EditTarget(proto: proto) } label: {
                    ProtocolCard(presentation: ProtocolPresentation(
                        proto, vials: vials, todaysLogs: today,
                        overdueSince: proto.lastOverdueDose(in: logs, skips: skips)))
                }
                .buttonStyle(PressableStyle())
                .contextMenu {
                    Button { editTarget = EditTarget(proto: proto) } label: {
                        Label("Edit / reactivate", systemImage: "pencil")
                    }
                    Button { proto.isActive.toggle() } label: {
                        Label(proto.isActive ? "Pause" : "Resume",
                              systemImage: proto.isActive ? "pause.circle" : "play.circle")
                    }
                    Button(role: .destructive) { context.delete(proto) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .entrance(active.count + i)
            }
        }
    }

    private var header: some View {
        Text("Stack")
            .font(Typo.screenTitle)
            .foregroundStyle(BrandColor.textPrimary)
            .minimumScaleFactor(0.7)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        Card {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("No protocols yet")
                    .font(Typo.headline)
                    .foregroundStyle(BrandColor.textPrimary)
                Text(vials.isEmpty
                     ? "Protocols are built from your vials — add a vial under Your vials first, then create a protocol from it with a dose and schedule."
                     : "Create one from a vial — set the dose per shot and choose a schedule. You can still log one-time pins without a protocol.")
                    .font(Typo.body)
                    .foregroundStyle(BrandColor.textSecondary)
            }
        }
    }
}

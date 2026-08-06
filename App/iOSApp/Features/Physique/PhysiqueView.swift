import SwiftUI
import SwiftData
import PhotosUI

/// Progress-photo tracker — capture or import physique photos and watch changes over time.
/// Photos are stored on-device only (`PhysiquePhotoStore`); nothing is uploaded.
struct PhysiqueView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var context
    @Query(sort: \PhysiquePhoto.timestamp, order: .reverse) private var photos: [PhysiquePhoto]

    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var viewing: PhysiquePhoto?
    // Multi-select: tap toggles selection instead of opening the viewer; bulk-delete the set.
    @State private var selecting = false
    @State private var selection: Set<PhysiquePhoto.ID> = []
    @State private var showBulkDeleteConfirm = false

    private let columns = [GridItem(.flexible(), spacing: Space.md), GridItem(.flexible(), spacing: Space.md)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Text("Snap a progress photo on the same day you dose, in similar lighting and pose, to see real change over time. Photos stay on this device.")
                    .font(Typo.caption).foregroundStyle(BrandColor.textSecondary)

                if selecting { selectionBar } else { addBar }

                if photos.isEmpty {
                    // Was `ContentUnavailableView` — system typography, not the app's. See DoseHistoryView.
                    ThemedEmptyState(icon: "figure.arms.open",
                                     title: "No progress photos yet",
                                     message: "Take or add a photo to start tracking your physique.")
                } else {
                    LazyVGrid(columns: columns, spacing: Space.md) {
                        ForEach(photos) { photo in
                            thumbnail(photo)
                        }
                    }
                }
            }
            .padding(Space.lg)
        }
        .heroScreen()
        .navigationTitle("Progress photos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !photos.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(selecting ? "Done" : "Select") {
                        // `.snappy` is 500ms despite the name; also ungated.
                        withAnimation(Motion.gated(Motion.emphasis, reduceMotion)) {
                            selecting.toggle()
                            if !selecting { selection.removeAll() }
                        }
                    }
                    .tint(BrandColor.accentText)
                }
            }
        }
        .confirmationDialog("Delete \(selection.count) photo\(selection.count == 1 ? "" : "s")? This can't be undone.",
                            isPresented: $showBulkDeleteConfirm, titleVisibility: .visible) {
            Button("Delete \(selection.count) photo\(selection.count == 1 ? "" : "s")", role: .destructive) { deleteSelected() }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(isPresented: $showCamera) { image in add(image) }
                .ignoresSafeArea()
        }
        .fullScreenCover(item: $viewing) { photo in
            PhysiquePhotoViewer(photo: photo) { delete(photo) }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    add(image)
                }
                pickerItem = nil
            }
        }
    }

    private var addBar: some View {
        HStack(spacing: Space.md) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button { showCamera = true } label: {
                    Label("Take photo", systemImage: "camera.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.md)
                        // Primary of a primary/secondary pair — "Add from library" beside it
                        // already carries the quiet charcoal+rim register, so this becomes the
                        // inverse-ink CTA and the two read as one button family.
                        .background(BrandColor.ctaFill, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                        .foregroundStyle(BrandColor.onCtaFill)
                }
                .buttonStyle(PressableStyle())   // filled CTA-family button
            }
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Add from library", systemImage: "photo.on.rectangle")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.md)
                    .background(BrandColor.surfaceElevated, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous).strokeBorder(BrandColor.stroke, lineWidth: 1))
                    .foregroundStyle(BrandColor.textPrimary)
            }
        }
    }

    /// Selection-mode action bar: select-all toggle, live count, and bulk delete.
    private var selectionBar: some View {
        HStack(spacing: Space.md) {
            Button(selection.count == photos.count ? "Deselect all" : "Select all") {
                selection = selection.count == photos.count ? [] : Set(photos.map(\.id))
            }
            .font(.subheadline.weight(.semibold)).foregroundStyle(BrandColor.accentText)
            Spacer()
            Text("\(selection.count) selected").font(Typo.caption).foregroundStyle(BrandColor.textSecondary)
            Spacer()
            Button(role: .destructive) { showBulkDeleteConfirm = true } label: {
                Label("Delete", systemImage: "trash").font(.subheadline.weight(.semibold))
            }
            .disabled(selection.isEmpty)
            .foregroundStyle(selection.isEmpty ? BrandColor.textSecondary : BrandColor.danger)
        }
    }

    private func thumbnail(_ photo: PhysiquePhoto) -> some View {
        let isSelected = selection.contains(photo.id)
        return Button {
            if selecting { toggleSelection(photo) } else { viewing = photo }
        } label: {
            ZStack(alignment: .bottomLeading) {
                if let image = PhysiquePhotoStore.image(named: photo.filename) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(3.0 / 4.0, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .clipped()
                } else {
                    Rectangle().fill(BrandColor.surfaceElevated)
                        .aspectRatio(3.0 / 4.0, contentMode: .fill)
                        .overlay(Image(systemName: "photo").foregroundStyle(BrandColor.textSecondary))
                }
                Text(photo.timestamp.relativeLabel())
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, Space.sm).padding(.vertical, Space.xs)
                    .background(.black.opacity(0.55), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(Space.sm)
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if selecting {
                    Group {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(BrandColor.onAccent, BrandColor.accent)
                        } else {
                            Image(systemName: "circle").foregroundStyle(.white)
                        }
                    }
                    .font(.title2)
                    .padding(Space.sm)
                    .shadow(radius: 2)
                }
            }
            .overlay {
                if selecting && isSelected {
                    // Stays FULL opacity (unlike the toned-down rims on dark cards): this one
                    // sits over an arbitrary photo and has to read against any image beneath it.
                    // Trimmed 3pt → 2pt so the affordance is unmistakable without being loud.
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .strokeBorder(BrandColor.accent, lineWidth: 2)
                }
            }
        }
        .buttonStyle(PressableStyle())   // photo grid thumbnail — same shape as ToolCard, which presses
        .contextMenu {
            if !selecting {
                Button(role: .destructive) { delete(photo) } label: { Label("Delete", systemImage: "trash") }
            }
        }
    }

    private func add(_ image: UIImage) {
        guard let filename = PhysiquePhotoStore.save(image) else { return }
        context.insert(PhysiquePhoto(filename: filename))
        try? context.save()
    }

    private func delete(_ photo: PhysiquePhoto) {
        PhysiquePhotoStore.delete(named: photo.filename)
        context.delete(photo)
        try? context.save()
        if viewing?.id == photo.id { viewing = nil }
    }

    private func toggleSelection(_ photo: PhysiquePhoto) {
        if selection.contains(photo.id) { selection.remove(photo.id) } else { selection.insert(photo.id) }
    }

    /// Delete every selected photo (file + record) at once, then exit selection mode.
    private func deleteSelected() {
        for photo in photos where selection.contains(photo.id) {
            PhysiquePhotoStore.delete(named: photo.filename)
            context.delete(photo)
        }
        try? context.save()
        selection.removeAll()
        withAnimation(Motion.gated(Motion.emphasis, reduceMotion)) { selecting = false }
    }
}

/// Full-screen viewer for a single progress photo, with a delete action.
private struct PhysiquePhotoViewer: View {
    let photo: PhysiquePhoto
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let image = PhysiquePhotoStore.image(named: photo.filename) {
                    Image(uiImage: image).resizable().scaledToFit()
                } else {
                    Image(systemName: "photo").font(.largeTitle).foregroundStyle(.white.opacity(0.6))
                }
            }
            .navigationTitle(photo.timestamp.formatted(.dateTime.month().day().year()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) { onDelete(); dismiss() } label: { Image(systemName: "trash") }
                }
            }
        }
    }
}

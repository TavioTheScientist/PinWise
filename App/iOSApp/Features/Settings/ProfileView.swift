import SwiftUI
import UIKit
import PhotosUI

/// The user's profile photo, stored as a JPEG in Application Support — never uploaded.
/// All disk I/O and image work runs off the main actor; only the published `image` hops back.
@MainActor
@Observable
final class ProfilePhotoStore {
    static let shared = ProfilePhotoStore()
    private(set) var image: UIImage?

    nonisolated private static let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("profile-photo.jpg")
    }()

    private init() {
        // @MainActor is explicit — with an explicit capture list, some toolchains don't
        // inherit the enclosing actor context, which reads `image` off the main actor.
        Task { @MainActor [weak self] in
            let loaded = await Task.detached(priority: .utility) {
                (try? Data(contentsOf: Self.fileURL)).flatMap(UIImage.init(data:))
            }.value
            // Don't clobber a photo the user picked while the disk load was in flight.
            if let loaded, let self, self.image == nil { self.image = loaded }
        }
    }

    /// Decodes, square-crops to 512px, and saves — all off the main actor.
    /// Returns false when the data isn't a decodable image.
    func set(imageData: Data) async -> Bool {
        let processed = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let raw = UIImage(data: imageData) else { return nil }
            let squared = Self.squareCropDownscale(raw, side: 512)
            if let jpeg = squared.jpegData(compressionQuality: 0.85) {
                try? jpeg.write(to: Self.fileURL, options: .atomic)
            }
            return squared
        }.value
        guard let processed else { return false }
        image = processed
        return true
    }

    func clear() {
        image = nil
        Task.detached(priority: .utility) {
            try? FileManager.default.removeItem(at: Self.fileURL)
        }
    }

    nonisolated private static func squareCropDownscale(_ image: UIImage, side: CGFloat) -> UIImage {
        let source = min(image.size.width, image.size.height)
        guard source > 0 else { return image }
        let target = min(side, source)   // center-crop to square; never upscale
        let scale = target / source
        let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: target, height: target), format: format).image { _ in
            image.draw(in: CGRect(x: (target - drawSize.width) / 2, y: (target - drawSize.height) / 2,
                                  width: drawSize.width, height: drawSize.height))
        }
    }
}

/// Circular avatar with a hairline stroke ring. Shows the profile photo when set; otherwise
/// an initials monogram on a flat accent fill (or a person glyph when there's no name yet).
struct ProfileAvatar: View {
    var name: String
    var size: CGFloat = 96
    var photo: UIImage?

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2).compactMap(\.first)
        return String(parts).uppercased()
    }

    var body: some View {
        ZStack {
            if let photo {
                Image(uiImage: photo).resizable().scaledToFill()
            } else {
                BrandColor.accent
                if initials.isEmpty {
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(BrandColor.onAccent.opacity(0.9))
                } else {
                    Text(initials)
                        .font(.system(size: size * 0.36, weight: .black, design: .rounded))
                        .foregroundStyle(BrandColor.onAccent)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(BrandColor.stroke, lineWidth: max(2, size / 34)))
        .accessibilityHidden(true)
    }
}

/// Shared profile-field definitions so onboarding setup and Your profile stay in lockstep.
/// Sex is stored under the existing "bodyGender" key — it silently drives the body map.
enum ProfileFields {
    /// The height a wheel PRESELECTS when nothing is stored yet.
    ///
    /// One constant, because there used to be two: the imperial wheel defaulted to 5 ft 10 in
    /// (177.8 cm) and the metric wheel to 170 cm, so the same unset field preselected two different
    /// heights depending on the unit toggle. Both wheels now derive from this.
    static let defaultHeightCm: Double = 170

    /// 18+ app: birthdays span 100 years ago through 18 years ago.
    static var birthdayRange: ClosedRange<Date> {
        let cal = Calendar.current
        let now = Date()
        let earliest = cal.date(byAdding: .year, value: -100, to: now) ?? now
        let latest = cal.date(byAdding: .year, value: -18, to: now) ?? now
        return earliest...latest
    }
    /// Neutral starting point for the picker before a birthday is set.
    static var defaultBirthday: Date {
        Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    }
    static func age(fromTimestamp ts: Double) -> Int? {
        guard ts > 0 else { return nil }
        return Calendar.current.dateComponents([.year], from: Date(timeIntervalSince1970: ts), to: Date()).year
    }
    /// Height text fields → centimeters. Imperial reads ft + in ("5 ft 10 in"); metric reads cm.
    static func parseHeightCm(feetText: String, inchesText: String, cmText: String, imperial: Bool) -> Double? {
        if imperial {
            let total = (feetText.decimalValue ?? 0) * 12 + (inchesText.decimalValue ?? 0)
            return total > 0 ? total * 2.54 : nil
        }
        guard let cm = cmText.decimalValue, cm > 0 else { return nil }
        return cm
    }

    /// The height as a person would say it, for the collapsed `DisclosureRow` value — nil when
    /// nothing has been entered yet, so the row can word its own "unset" state.
    ///
    /// Deliberately derived from the live TEXT bindings the wheels drive, not from the stored
    /// `profileHeightCm`: that default is only written on commit, so reading it here would leave the
    /// row reporting the previous height while the wheel beside it already showed the new one.
    static func heightDisplay(feetText: String, inchesText: String, cmText: String, imperial: Bool) -> String? {
        guard let cm = parseHeightCm(feetText: feetText, inchesText: inchesText, cmText: cmText, imperial: imperial) else {
            return nil
        }
        guard imperial else {
            return (cm == cm.rounded() ? String(Int(cm)) : String(format: "%.1f", cm)) + " cm"
        }
        let f = heightFields(fromCm: cm)
        return "\(f.feet) ft \(f.inches) in"
    }

    /// Centimeters → prefilled field strings for both unit systems.
    static func heightFields(fromCm cm: Double) -> (feet: String, inches: String, cm: String) {
        guard cm > 0 else { return ("", "", "") }
        let totalInches = cm / 2.54
        var feet = Int(totalInches / 12)
        var inches = Int((totalInches - Double(feet) * 12).rounded())
        if inches == 12 { feet += 1; inches = 0 }
        let cmDisp = cm == cm.rounded() ? String(Int(cm)) : String(format: "%.1f", cm)
        return (String(feet), String(inches), cmDisp)
    }
}

/// Height entry matching the unit system: "5 ft 10 in" fields when imperial, cm when metric.
/// Disclosed by a `DisclosureRow`, never standing on its own — a bare wheel gives no hint that it
/// scrolls (see `ProfileView.personalizationCard`).
struct HeightField: View {
    @Binding var feetText: String
    @Binding var inchesText: String
    @Binding var cmText: String
    let imperial: Bool

    var body: some View {
        Group {
            if imperial {
                HStack(spacing: 0) {
                    Picker("Feet", selection: feetSel) {
                        ForEach(3...8, id: \.self) { Text("\($0) ft").tag($0) }
                    }
                    .pickerStyle(.wheel).frame(maxWidth: .infinity)
                    Picker("Inches", selection: inchSel) {
                        ForEach(0...11, id: \.self) { Text("\($0) in").tag($0) }
                    }
                    .pickerStyle(.wheel).frame(maxWidth: .infinity)
                }
            } else {
                Picker("Centimeters", selection: cmSel) {
                    ForEach(120...220, id: \.self) { Text("\($0) cm").tag($0) }
                }
                .pickerStyle(.wheel)
            }
        }
        .frame(height: 120)
    }

    // Wheels select whole numbers; bridge to the existing String bindings so ProfileFields'
    // parse/format helpers keep working. Empty text shows a sensible default (5 ft 10 in / 170 cm).
    private var feetSel: Binding<Int> {
        Binding(get: { Int(feetText) ?? Int(ProfileFields.heightFields(fromCm: ProfileFields.defaultHeightCm).feet) ?? 5 },
                set: { feetText = String($0) })
    }
    private var inchSel: Binding<Int> {
        Binding(get: { Int(Double(inchesText) ?? Double(ProfileFields.heightFields(fromCm: ProfileFields.defaultHeightCm).inches) ?? 7) },
                set: { inchesText = String($0) })
    }
    private var cmSel: Binding<Int> {
        Binding(get: { Int(Double(cmText) ?? ProfileFields.defaultHeightCm) }, set: { cmText = String($0) })
    }
}

/// Your profile — the account home. A hero header (photo, name, membership badge) over cards
/// for account details, personalization, and the on-device privacy promise.
struct ProfileView: View {
    @AppStorage("bodyGender") private var bodyGenderRaw = "male"
    @AppStorage("profileBirthday") private var birthdayTS: Double = 0
    @AppStorage("profileHeightCm") private var heightCm: Double = 0
    @AppStorage("weightInPounds") private var weightInPounds = true
    @State private var heightFeetText = ""
    @State private var heightInchesText = ""
    @State private var heightText = ""
    @State private var auth = AuthManager.shared
    @State private var photos = ProfilePhotoStore.shared
    @State private var pickerItem: PhotosPickerItem?
    @State private var photoLoadTask: Task<Void, Never>?
    @State private var photoError: String?
    /// Draft of the name while editing; committed to AuthManager on submit/close.
    @State private var name = AuthManager.shared.displayName ?? ""
    /// Which "About you" row currently has its editor disclosed (nil = all collapsed).
    @State private var openField: AboutYouField?

    /// The disclosable rows of the "About you" card — an enum rather than three Bools so "one open
    /// at a time" is structural instead of something three `onChange`s have to keep agreeing on.
    private enum AboutYouField { case sex, birthday, height }

    var body: some View {
        MenuSheet(title: "Your profile") {
            header
            accountCard
            personalizationCard
        }
        .onAppear {
            let f = ProfileFields.heightFields(fromCm: heightCm)
            heightFeetText = f.feet; heightInchesText = f.inches; heightText = f.cm
        }
        .onDisappear {
            auth.updateDisplayName(name)
            commitHeight()
        }
        // Keep the typed height meaning the same measurement when the unit flips elsewhere.
        // All three About-you fields now commit on interaction, not on close. Height was the odd
        // one out — its wheels write to intermediate String bindings — so mirror them through to
        // storage on every change. Three adjacent rows with three different commit semantics is
        // what made the section feel inconsistent to use.
        .onChange(of: heightFeetText) { commitHeight() }
        .onChange(of: heightInchesText) { commitHeight() }
        .onChange(of: heightText) { commitHeight() }
        .onChange(of: weightInPounds) { old, new in
            guard old != new,
                  let cm = ProfileFields.parseHeightCm(feetText: heightFeetText, inchesText: heightInchesText,
                                                       cmText: heightText, imperial: old) else { return }
            let f = ProfileFields.heightFields(fromCm: cm)
            heightFeetText = f.feet; heightInchesText = f.inches; heightText = f.cm
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            photoLoadTask?.cancel()
            photoLoadTask = Task {
                let data = try? await item.loadTransferable(type: Data.self)
                guard !Task.isCancelled else { return }
                let ok: Bool
                if let data { ok = await photos.set(imageData: data) } else { ok = false }
                guard !Task.isCancelled else { return }
                photoError = ok ? nil : "Couldn't load that photo — try another."
                pickerItem = nil
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: Space.md) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    ProfileAvatar(name: name, size: 108, photo: photos.image)
                    Image(systemName: photos.image == nil ? "plus" : "pencil")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(BrandColor.onAccent)
                        .frame(width: 30, height: 30)
                        .background(BrandColor.accent, in: Circle())
                        .overlay(Circle().strokeBorder(BrandColor.background, lineWidth: 2))
                }
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(photos.image == nil ? "Add profile photo" : "Change profile photo")

            VStack(spacing: Space.sm) {
                Text(name.isEmpty ? "Set up your profile" : name)
                    .font(Typo.title).displayTracking()
                    .foregroundStyle(BrandColor.textPrimary)
                    .multilineTextAlignment(.center)
                // "Guest" is taxonomy (neutral); "Staxyz Member" is the app's ONE sanctioned
                // `.brand` chip — nothing else on this screen competes for the accent.
                TagChip(text: auth.isGuest ? "Guest" : "Staxyz Member",
                        style: auth.isGuest ? .neutral : .brand,
                        systemImage: auth.isGuest ? "person.crop.circle.dashed" : "checkmark.seal.fill")
            }

            if let photoError {
                Text(photoError)
                    .font(.caption)
                    .foregroundStyle(BrandColor.warning)
            }
            if photos.image != nil {
                Button("Remove photo") { photos.clear() }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Space.sm)
    }

    // MARK: Cards

    private var accountCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Space.md) {
                SectionHeader(title: "Account")
                FieldRow("Your name", hint: "Shown on your profile and used to personalize the app.") {
                    TextField("Name", text: $name)
                        .staxyzField()
                        .textContentType(.name)
                        .onSubmit { auth.updateDisplayName(name) }
                }
                if let email = auth.email, !email.isEmpty {
                    detailRow("Email", email)
                }
                detailRow("Sign-in", auth.providerLabel, icon: auth.provider == .apple ? "applelogo" : nil)
                if let since = auth.memberSince {
                    detailRow(auth.isGuest ? "Tracking since" : "Member since",
                              since.formatted(.dateTime.month(.wide).year()))
                }
            }
        }
    }

    private var birthdayBinding: Binding<Date> {
        Binding(
            get: { birthdayTS > 0 ? Date(timeIntervalSince1970: birthdayTS) : ProfileFields.defaultBirthday },
            set: { birthdayTS = $0.timeIntervalSince1970 }
        )
    }

    /// The card's three settings read as a LIST OF VALUES and disclose their editor on tap, rather
    /// than standing three bare scroll wheels 120pt tall in a column. A naked wheel is the wrong
    /// control twice over: it gives no affordance that it scrolls (its unselected rows are dimmed to
    /// near-invisibility on a dark ground, so it reads as static text), and it spends ~360pt of a
    /// sheet on values the user sets once and then only wants to *read*.
    ///
    /// Disclosed INLINE rather than via a sheet for two reasons: `ProfileView` is already presented
    /// inside a `MenuSheet`, so a per-field sheet would be a second modal layer over the first; and
    /// the app already answers "reveal a control on demand" inline everywhere else
    /// (`CollapsibleNoteField`, `DisclosureSection`, the News filter panel).
    ///
    /// Only ONE row is open at a time. With three, the card can otherwise grow past a screen and the
    /// row you are editing scrolls out from under your thumb; with one, the card stays roughly its
    /// collapsed height and the open control is always the thing on screen.
    private var personalizationCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Space.md) {
                SectionHeader(title: "About you")

                // A binary choice is the one case where the disclosed control is NOT a wheel: two
                // chips state both options at once and take one tap, where a 2-row wheel makes the
                // user discover by scrolling that there was nothing else to find.
                DisclosureRow(title: "Sex assigned at birth",
                              value: bodyGenderRaw == "female" ? "Female" : "Male",
                              hint: "Sets which body the injection map draws.",
                              isExpanded: openField == .sex) { toggleField(.sex) } content: {
                    HStack(spacing: Space.sm) {
                        SelectableChip(title: "Male", isSelected: bodyGenderRaw == "male",
                                       fillWidth: true) { bodyGenderRaw = "male" }
                        SelectableChip(title: "Female", isSelected: bodyGenderRaw == "female",
                                       fillWidth: true) { bodyGenderRaw = "female" }
                    }
                    // One feedback per chip GROUP, at the container — per-chip would double-fire.
                    .sensoryFeedback(.selection, trigger: bodyGenderRaw)
                }

                DisclosureRow(title: "Birthday",
                              value: birthdayTS > 0
                                  ? Date(timeIntervalSince1970: birthdayTS)
                                      .formatted(.dateTime.month(.abbreviated).day().year())
                                  : "Not set",
                              hint: ProfileFields.age(fromTimestamp: birthdayTS).map { "Age \($0)" },
                              isExpanded: openField == .birthday) { toggleField(.birthday) } content: {
                    DatePicker("", selection: birthdayBinding, in: ProfileFields.birthdayRange,
                               displayedComponents: [.date])
                        .labelsHidden()
                        .datePickerStyle(.wheel)
                }

                DisclosureRow(title: "Height",
                              value: ProfileFields.heightDisplay(feetText: heightFeetText,
                                                                 inchesText: heightInchesText,
                                                                 cmText: heightText,
                                                                 imperial: weightInPounds) ?? "Not set",
                              isExpanded: openField == .height) { toggleField(.height) } content: {
                    HeightField(feetText: $heightFeetText, inchesText: $heightInchesText,
                                cmText: $heightText, imperial: weightInPounds)
                }
            }
        }
    }

    /// Opens `field` and closes whatever else was open (tapping the open row closes it).
    private func toggleField(_ field: AboutYouField) {
        let wasEditingHeight = openField == .height
        let isOpening = openField != field
        openField = isOpening ? field : nil
        // COMMIT THE PRESELECTED VALUE THE MOMENT THE ROW OPENS.
        //
        // This fixes a phantom: a wheel whose binding GETTER falls back to a default renders that
        // default as if it were the user's value, but SwiftUI only fires the SETTER when the
        // selection CHANGES. So a user who opened Height, saw "5 ft 10 in", agreed with it and
        // closed the row — or who scrolled and landed back on it — committed nothing, and the
        // collapsed row read "Not set". The wheel was showing a number the store did not hold.
        //
        // Seeding on open makes the displayed value the STORED value, so every wheel position the
        // user can see is real and any scroll from there simply updates it. It is also why this is
        // not the "don't fabricate a measurement" case it looks like: presenting an uncommitted
        // default is the fabrication — this removes it.
        if isOpening { seedIfUnset(field) }
        // Belt and braces for dismissing the sheet with the row still open; the per-keystroke
        // commit below makes it redundant in the normal path.
        if wasEditingHeight, openField != .height { commitHeight() }
    }

    /// Writes the value a freshly-opened wheel is already displaying, so it stops being a phantom.
    private func seedIfUnset(_ field: AboutYouField) {
        switch field {
        case .sex:
            break   // chips commit on tap and `bodyGenderRaw` always holds a real value
        case .birthday:
            if birthdayTS <= 0 { birthdayTS = ProfileFields.defaultBirthday.timeIntervalSince1970 }
        case .height:
            if heightCm <= 0 { heightCm = ProfileFields.defaultHeightCm }
            // Mirror the stored value into the wheel's String bindings, so the control and the
            // collapsed row read from the same number rather than each inventing a fallback.
            let f = ProfileFields.heightFields(fromCm: heightCm)
            heightFeetText = f.feet
            heightInchesText = f.inches
            heightText = f.cm
        }
    }

    private func commitHeight() {
        if let cm = ProfileFields.parseHeightCm(feetText: heightFeetText, inchesText: heightInchesText,
                                               cmText: heightText, imperial: weightInPounds) {
            heightCm = cm
        }
    }

    private func detailRow(_ label: String, _ value: String, icon: String? = nil) -> some View {
        HStack {
            Text(label).font(Typo.body).foregroundStyle(BrandColor.textPrimary)
            Spacer()
            HStack(spacing: Space.xs) {
                if let icon { Image(systemName: icon).font(.caption) }
                Text(value).font(.caption.weight(.medium))
            }
            .foregroundStyle(BrandColor.textSecondary)
        }
    }
}

import LockyKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// The Mac lab: any Mac of the catalog on the stage of the home screen, handled the same way, over
/// the same background, never faded (it does not need the Mac in reach), with the wallpaper of the
/// paired Mac or a picture chosen for the lab alone: from the photo library, the camera, Files or a
/// link the app downloads. Its Macs keep their own settings (lid, tilt, keyboard:
/// ``MacLab/defaults``); nothing here touches the rest of the app.
struct MacLabView: View {
    @Environment(AppModel.self) private var model
    /// The margins of the system bars: the lab covers the whole window, its background under
    /// them, its buttons within them.
    let safeArea: EdgeInsets
    let close: () -> Void

    /// The Mac shown, by its picture; the paired Mac at first.
    @AppStorage("labModel") private var selectedID: String = ""
    @State private var customWallpaper: MacLabWallpaper? = MacLabWallpaper.stored()
    @State private var isModelListPresented: Bool = false
    // Where the picture comes from.
    @State private var pickedItem: PhotosPickerItem?
    @State private var isLibraryPresented: Bool = false
    @State private var isCameraPresented: Bool = false
    @State private var isFileImporterPresented: Bool = false
    @State private var isLinkPresented: Bool = false
    @State private var link: String = ""
    @State private var isLoading: Bool = false
    @State private var isFailurePresented: Bool = false
    /// Felt once the lab is locked again (``MacLab/relock()``).
    @State private var relockCount: Int = 0
    /// Where the Mac begins, from the top of the lab: above it, three fingers held still lock the
    /// lab again.
    @State private var stageTop: CGFloat = 0

    var body: some View {
        let selected: MacLabModel? = MacLabCatalog.model(id: selectedID) ?? defaultModel
        ZStack {
            ImmersiveBackground(wallpaper: customWallpaper?.background ?? model.visuals.backgroundWallpaper, intensity: 0.3, isFaded: false)
                .animation(.smooth(duration: 0.6), value: customWallpaper?.background)
            content(selected: selected)
                .padding(safeArea)
        }
        .sheet(isPresented: $isModelListPresented) {
            MacLabModelList(
                selectedID: Binding(get: { selected?.id ?? "" }, set: { selectedID = $0 }),
                wallpaper: (customWallpaper?.image ?? model.visuals.wallpaperImage).flatMap(MacLabModelList.thumbnail)
            )
        }
        .photosPicker(isPresented: $isLibraryPresented, selection: $pickedItem, matching: .images)
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            pickedItem = nil
            load { try await item.loadTransferable(type: Data.self) }
        }
        .fullScreenCover(isPresented: $isCameraPresented) {
            CameraPicker { image in
                isCameraPresented = false
                guard let image else { return }
                load { image.jpegData(compressionQuality: 0.9) }
            }
            .ignoresSafeArea()
        }
        .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.image]) { result in
            guard case let .success(url) = result else { return }
            load { try Self.read(url) }
        }
        .alert("Picture from a link", isPresented: $isLinkPresented) {
            TextField(String(localized: "https://…"), text: $link)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Load") {
                let address: String = link.trimmingCharacters(in: .whitespacesAndNewlines)
                load { try await Self.download(address) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The address of a picture on the web.")
        }
        .alert("This is not a picture Locky can show.", isPresented: $isFailurePresented) {
            Button("OK", role: .cancel) {}
        }
    }

    private func content(selected: MacLabModel?) -> some View {
        VStack(spacing: 20) {
            MacLabTopBar(
                hasCustomWallpaper: customWallpaper != nil,
                isLoading: isLoading,
                close: close,
                choose: choose,
                resetWallpaper: resetWallpaper
            )
            Spacer(minLength: 0)
            if let selected {
                MacStage(
                    frame: selected.frame,
                    family: selected.family,
                    wallpaper: customWallpaper?.image ?? model.visuals.wallpaperImage,
                    lockState: .unlocked,
                    isConnected: true,
                    userPicture: model.visuals.userPicture,
                    userName: model.macStatus?.userName,
                    name: selected.name,
                    detail: selected.detail
                )
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.space)).minY } action: { stageTop = $0 }
            }
            Spacer(minLength: 0)
            MacLabModelButton(model: selected) {
                isModelListPresented = true
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .coordinateSpace(.named(Self.space))
        // The empty top of the lab takes the fingers too.
        .contentShape(.rect)
        // Three fingers held still at the top, above the Mac: the lab locks itself again, felt
        // and not seen, for the fireworks to come back.
        .gesture(HandLongPressRecognizer(touches: MacLab.relockingFingers, duration: MacLab.relockingDuration) { point in
            guard point.y < stageTop else { return }
            MacLab.relock()
            relockCount += 1
        })
        .sensoryFeedback(.success, trigger: relockCount)
    }

    private static let space: String = "MacLab"

    /// The paired Mac, or the first one of the catalog.
    private var defaultModel: MacLabModel? {
        MacLabCatalog.model(id: model.macFrame?.asset) ?? MacLabCatalog.models.first
    }

    private func choose(_ source: MacLabPictureSource) {
        switch source {
        case .library: isLibraryPresented = true
        case .camera: isCameraPresented = true
        case .files: isFileImporterPresented = true
        case .link:
            link = ""
            isLinkPresented = true
        }
    }

    /// Makes the picture of `data` the wallpaper of the lab, or tells it could not.
    private func load(_ data: @escaping () async throws -> Data?) {
        isLoading = true
        Task {
            let wallpaper: MacLabWallpaper? = (try? await data()).flatMap(MacLabWallpaper.init(data:))
            isLoading = false
            guard let wallpaper else {
                isFailurePresented = true
                return
            }
            wallpaper.store()
            withAnimation(.smooth) { customWallpaper = wallpaper }
        }
    }

    private func resetWallpaper() {
        MacLabWallpaper.remove()
        withAnimation(.smooth) { customWallpaper = nil }
    }

    /// A file chosen in Files, which may live outside the app.
    private static func read(_ url: URL) throws -> Data {
        let isScoped: Bool = url.startAccessingSecurityScopedResource()
        defer {
            if isScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try Data(contentsOf: url)
    }

    /// The picture at `address`, downloaded by the app (https when no scheme is typed), at most
    /// 40 MB.
    private static func download(_ address: String) async throws -> Data? {
        let text: String = address.contains("://") ? address : "https://" + address
        guard let url = URL(string: text), url.scheme == "https" || url.scheme == "http" else { return nil }
        var request: URLRequest = .init(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        let (data, response): (Data, URLResponse) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count < 40_000_000 else { return nil }
        return data
    }
}

/// Where a picture of the lab comes from.
enum MacLabPictureSource {
    case library
    case camera
    case files
    case link
}

/// The cross that closes the lab on the leading side, the wallpaper on the trailing side.
private struct MacLabTopBar: View {
    let hasCustomWallpaper: Bool
    let isLoading: Bool
    let close: () -> Void
    let choose: (MacLabPictureSource) -> Void
    let resetWallpaper: () -> Void

    var body: some View {
        HStack {
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .accessibilityLabel("Close")
            Spacer()
            Text(verbatim: "Mac Lab")
                .font(.headline)
            Spacer()
            Menu {
                Button("Photo library", systemImage: "photo.on.rectangle") { choose(.library) }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take a photo", systemImage: "camera") { choose(.camera) }
                }
                Button("Files", systemImage: "folder") { choose(.files) }
                Button("From a link", systemImage: "link") { choose(.link) }
                if hasCustomWallpaper {
                    Divider()
                    Button("Wallpaper of my Mac", systemImage: "arrow.uturn.backward", action: resetWallpaper)
                }
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title3.weight(.semibold))
                    }
                }
                .frame(width: 44, height: 44)
                .glassEffect(.regular.interactive(), in: .circle)
            }
            .disabled(isLoading)
            .accessibilityLabel("Wallpaper")
        }
        .foregroundStyle(.primary)
    }
}

/// The camera, for a picture taken on the spot; `nil` when cancelled.
private struct CameraPicker: UIViewControllerRepresentable {
    let taken: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(taken: taken)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker: UIImagePickerController = .init()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let taken: (UIImage?) -> Void

        init(taken: @escaping (UIImage?) -> Void) {
            self.taken = taken
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            taken(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            taken(nil)
        }
    }
}

/// The Mac shown, which opens the list of every Mac.
private struct MacLabModelButton: View {
    let model: MacLabModel?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: model?.family.systemImage ?? "laptopcomputer")
                    .font(.title3)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Choose a Mac")
                        .font(.headline)
                    if let model {
                        Text(verbatim: "\(model.name) · \(model.detail)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: 480)
            .contentShape(.capsule)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}

/// Every Mac of the catalog, by family, each with its picture.
private struct MacLabModelList: View {
    @Binding var selectedID: String
    /// The wallpaper of the lab, small, on the screen of every Mac of the list.
    let wallpaper: UIImage?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(MacLabCatalog.sections) { section in
                    Section(section.title) {
                        ForEach(section.models) { model in
                            Button {
                                selectedID = model.id
                                dismiss()
                            } label: {
                                MacLabModelRow(model: model, wallpaper: wallpaper, isSelected: model.id == selectedID)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Choose a Mac")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// The wallpaper at the size of the screens of the list: a few dozen of them at once.
    static func thumbnail(_ image: UIImage) -> UIImage? {
        let width: CGFloat = 240
        let height: CGFloat = (width * image.size.height / max(image.size.width, 1)).rounded()
        return image.preparingThumbnail(of: CGSize(width: width, height: max(height, 1))) ?? image
    }
}

private struct MacLabModelRow: View {
    let model: MacLabModel
    let wallpaper: UIImage?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let frame = model.frame {
                    // Its screen shows the wallpaper of the lab, as on the stage.
                    MacDeviceImage(frame: frame, family: model.family, wallpaper: wallpaper, lockState: .unlocked)
                } else {
                    Image(systemName: model.family.systemImage)
                }
            }
            .frame(width: 64, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.name)
                    .font(.body)
                Text(model.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

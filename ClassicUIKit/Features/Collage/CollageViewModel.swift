import UIKit
import Observation
import Vision
import CoreImage
import FactoryKit

@Observable
final class CollageViewModel {

    let collageID: UUID?
    var canvasItems: [CanvasItemModel] = []
    var selectedItemID: UUID?
    var isSaving: Bool = false
    var hasUnsavedChanges: Bool = false
    var canvasSize: CGSize = .zero

    var toolbarState: CollageToolbarState {
        guard let id = selectedItemID, let item = canvasItems.first(where: { $0.id == id }) else {
            return .hidden
        }
        var shaderStates: [ShaderType: Bool] = [:]
        ShaderType.allCases.forEach { shaderStates[$0] = item.shaderStack.contains($0) }
        return CollageToolbarState(isVisible: true, isCutoutActive: item.usesCutout, shaderStates: shaderStates)
    }

    @ObservationIgnored @Injected(Container.shared.collageRepository) private var collageRepository: CollageRepository
    @ObservationIgnored private weak var coordinator: CollageCoordinating?
    @ObservationIgnored @Injected(Container.shared.photoLibraryService) private var photoLibraryService: PhotoLibraryService
    @ObservationIgnored @Injected(Container.shared.shaderProcessingService) private var shaderService: ShaderProcessingService
    @ObservationIgnored @Injected(Container.shared.imageLoader) private var imageLoader: ImageLoader
    @ObservationIgnored private var cutoutTasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var hasLoaded = false

    private var collage: Collage

    init(collageID: UUID?, coordinator: CollageCoordinating?) {
        self.collageID = collageID
        self.coordinator = coordinator
        self.collage = Collage(id: collageID ?? UUID())
    }

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        guard let collageID else { return }
        let loaded = try? collageRepository.loadCollage(id: collageID)
        if let loaded {
            collage = loaded
            canvasItems = loaded.items.compactMap(makeCanvasItem)
        }
    }

    func presentImagePicker(from controller: UIViewController, delegate: (UIImagePickerControllerDelegate & UINavigationControllerDelegate)?) {
        photoLibraryService.presentPicker(from: controller, delegate: delegate)
    }

    func addImage(_ image: UIImage) {
        let resized = image.resized(maxDimension: 2048) ?? image
        addImageToCanvas(resized)
    }

    func selectItem(_ id: UUID?) {
        selectedItemID = id
        guard let id else { return }
        bringItemToFront(id)
    }

    func toggleCutout() {
        guard let selectedItemID,
              let index = canvasItems.firstIndex(where: { $0.id == selectedItemID }) else { return }
        if canvasItems[index].usesCutout {
            canvasItems[index].usesCutout = false
            refreshRenderedImage(for: index)
            hasUnsavedChanges = true
            return
        }
        canvasItems[index].isProcessingCutout = true
        let image = canvasItems[index].baseImage
        cutoutTasks[selectedItemID]?.cancel()
        cutoutTasks[selectedItemID] = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let cutout = try? await self.generateCutout(from: image)
            await MainActor.run {
                guard let idx = self.canvasItems.firstIndex(where: { $0.id == selectedItemID }) else { return }
                self.canvasItems[idx].isProcessingCutout = false
                if let cutout {
                    self.canvasItems[idx].cutoutImage = cutout
                    self.canvasItems[idx].usesCutout = true
                    self.canvasItems[idx].requiresAssetSave = true
                    self.hasUnsavedChanges = true
                    self.refreshRenderedImage(for: idx)
                }
            }
        }
    }

    func toggleShader(_ shader: ShaderType) {
        guard let selectedItemID,
              let index = canvasItems.firstIndex(where: { $0.id == selectedItemID }) else { return }
        if let existingIndex = canvasItems[index].shaderStack.firstIndex(of: shader) {
            canvasItems[index].shaderStack.remove(at: existingIndex)
        } else {
            canvasItems[index].shaderStack.append(shader)
        }
        hasUnsavedChanges = true
        refreshRenderedImage(for: index)
    }

    func updateTransform(for itemID: UUID, transform: CollageItemTransform) {
        guard let index = canvasItems.firstIndex(where: { $0.id == itemID }) else { return }
        canvasItems[index].transform = transform
        hasUnsavedChanges = true
    }

    func saveCollage(snapshot: UIImage) {
        guard !canvasItems.isEmpty else {
            coordinator?.dismissCollage(shouldRefresh: false)
            return
        }
        isSaving = true
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            var updatedItems: [CollageItem] = []
            let currentItems = await MainActor.run { self.canvasItems }
            for canvasItem in currentItems {
                if canvasItem.requiresAssetSave || canvasItem.basePath == nil {
                    let paths = self.collageRepository.persistItemAssets(
                        collageID: self.collage.id,
                        itemID: canvasItem.id,
                        baseImage: canvasItem.baseImage,
                        cutout: canvasItem.cutoutImage
                    )
                    await MainActor.run {
                        if let idx = self.canvasItems.firstIndex(where: { $0.id == canvasItem.id }) {
                            self.canvasItems[idx].basePath = paths.basePath
                            self.canvasItems[idx].cutoutPath = paths.cutoutPath
                            self.canvasItems[idx].requiresAssetSave = false
                        }
                    }
                }
                let basePath = await MainActor.run { self.canvasItems.first(where: { $0.id == canvasItem.id })?.basePath } ?? ""
                let cutoutPath = await MainActor.run { self.canvasItems.first(where: { $0.id == canvasItem.id })?.cutoutPath }
                let collageItem = CollageItem(
                    id: canvasItem.id,
                    baseImagePath: basePath,
                    cutoutImagePath: cutoutPath,
                    usesCutout: canvasItem.usesCutout,
                    zPosition: canvasItem.zPosition,
                    transform: canvasItem.transform,
                    shaderStack: canvasItem.shaderStack
                )
                updatedItems.append(collageItem)
            }
            self.collage.items = updatedItems
            let savedCollage = try? self.collageRepository.saveCollage(self.collage, snapshot: snapshot)
            self.photoLibraryService.saveImageToLibrary(snapshot) { _ in }
            await MainActor.run {
                self.isSaving = false
                self.hasUnsavedChanges = false
                if let savedCollage {
                    self.collage = savedCollage
                }
                self.coordinator?.dismissCollage(shouldRefresh: true)
            }
        }
    }

    func dismissWithoutSaving() {
        coordinator?.dismissCollage(shouldRefresh: false)
    }

    func bringItemToFront(_ id: UUID) {
        guard let index = canvasItems.firstIndex(where: { $0.id == id }) else { return }
        let maxZ = (canvasItems.map { $0.zPosition }.max() ?? 0) + 1
        canvasItems[index].zPosition = maxZ
        canvasItems.sort { $0.zPosition < $1.zPosition }
    }

    func renderedImage(for id: UUID) -> UIImage? {
        guard let item = canvasItems.first(where: { $0.id == id }) else { return nil }
        return item.renderedImage ?? item.activeImage
    }

    private func addImageToCanvas(_ image: UIImage) {
        let clampedSize = defaultItemSize()
        let transform = CollageItemTransform(
            translation: .zero,
            scale: 1,
            rotation: 0,
            size: clampedSize
        )
        var item = CanvasItemModel(
            baseImage: image,
            renderedImage: image,
            transform: transform,
            zPosition: (canvasItems.map { $0.zPosition }.max() ?? 0) + 1
        )
        canvasItems.append(item)
        hasUnsavedChanges = true
        selectedItemID = item.id
    }

    private func refreshRenderedImage(for index: Int) {
        let item = canvasItems[index]
        let sourceImage = item.usesCutout ? (item.cutoutImage ?? item.baseImage) : item.baseImage
        guard !item.shaderStack.isEmpty else {
            canvasItems[index].renderedImage = sourceImage
            return
        }
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let filtered = self.shaderService.apply(shaders: item.shaderStack, to: sourceImage)
            await MainActor.run {
                guard let idx = self.canvasItems.firstIndex(where: { $0.id == item.id }) else { return }
                self.canvasItems[idx].renderedImage = filtered ?? sourceImage
            }
        }
    }

    private func makeCanvasItem(from collageItem: CollageItem) -> CanvasItemModel? {
        guard let baseImage = imageLoader.image(for: collageItem.baseImagePath) else { return nil }
        let cutoutImage = imageLoader.image(for: collageItem.cutoutImagePath)
        return CanvasItemModel(
            id: collageItem.id,
            baseImage: baseImage,
            cutoutImage: cutoutImage,
            renderedImage: cutoutImage ?? baseImage,
            basePath: collageItem.baseImagePath,
            cutoutPath: collageItem.cutoutImagePath,
            usesCutout: collageItem.usesCutout,
            shaderStack: collageItem.shaderStack,
            transform: collageItem.transform,
            zPosition: collageItem.zPosition,
            isProcessingCutout: false,
            requiresAssetSave: false
        )
    }

    private func defaultItemSize() -> CGSize {
        guard canvasSize != .zero else { return CGSize(width: 200, height: 240) }
        return CGSize(width: canvasSize.width * 0.5, height: canvasSize.height * 0.5)
    }

    private func generateCutout(from image: UIImage) async throws -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        guard let observation = request.results?.first else { return nil }
        let pixelBuffer = try observation.generateMaskedImage(ofInstances: observation.allInstances, from: handler, croppedToInstancesExtent: false)
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let result = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: result)
    }
}

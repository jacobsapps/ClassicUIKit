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

    @ObservationIgnored @Injected(\.collageRepository) private var collageRepository: CollageRepository
    @ObservationIgnored private weak var coordinator: CollageCoordinating?
    @ObservationIgnored @Injected(\.photoLibraryService) private var photoLibraryService: PhotoLibraryService
    @ObservationIgnored @Injected(\.shaderProcessingService) private var shaderService: ShaderProcessingService
    @ObservationIgnored @Injected(\.imageLoader) private var imageLoader: ImageLoader
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
        cutoutTasks[selectedItemID] = Task { [weak self] in
            await self?.performCutout(for: selectedItemID, image: image)
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
        Task { [weak self] in
            await self?.performSave(snapshot: snapshot)
        }
    }

    func deleteSelectedItem() {
        guard let selectedItemID,
              let index = canvasItems.firstIndex(where: { $0.id == selectedItemID }) else { return }
        cutoutTasks[selectedItemID]?.cancel()
        cutoutTasks.removeValue(forKey: selectedItemID)
        canvasItems.remove(at: index)
        hasUnsavedChanges = true
        self.selectedItemID = nil
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
        let clampedSize = itemSize(for: image)
        let transform = CollageItemTransform(
            translation: .zero,
            scale: 1,
            rotation: 0,
            size: clampedSize
        )
        let item = CanvasItemModel(
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
        let shaderStack = item.shaderStack
        let itemID = item.id
        Task { [weak self] in
            await self?.performShaderRefresh(for: itemID, stack: shaderStack, sourceImage: sourceImage)
        }
    }

    private func makeCanvasItem(from collageItem: CollageItem) -> CanvasItemModel? {
        guard let baseImage = imageLoader.image(for: collageItem.baseImagePath) else { return nil }
        let cutoutImage = imageLoader.image(for: collageItem.cutoutImagePath)
        let activeImage = collageItem.usesCutout ? (cutoutImage ?? baseImage) : baseImage
        let renderedImage: UIImage
        if collageItem.shaderStack.isEmpty {
            renderedImage = activeImage
        } else {
            renderedImage = shaderService.apply(shaders: collageItem.shaderStack, to: activeImage) ?? activeImage
        }
        return CanvasItemModel(
            id: collageItem.id,
            baseImage: baseImage,
            cutoutImage: cutoutImage,
            renderedImage: renderedImage,
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

    private func itemSize(for image: UIImage) -> CGSize {
        guard canvasSize != .zero else { return image.size }
        let maxWidth = canvasSize.width * 0.6
        let maxHeight = canvasSize.height * 0.6
        let aspectRatio = image.size.width / max(image.size.height, 1)
        var width = maxWidth
        var height = width / aspectRatio
        if height > maxHeight {
            height = maxHeight
            width = height * aspectRatio
        }
        return CGSize(width: width, height: height)
    }

    @concurrent
    private func performCutout(for itemID: UUID, image: UIImage) async {
        let cutout = try? await generateCutout(from: image)
        await MainActor.run {
            guard let idx = self.canvasItems.firstIndex(where: { $0.id == itemID }) else { return }
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

    @MainActor
    private func performSave(snapshot: UIImage) async {
        var stagedItems = canvasItems
        let collageID = collage.id
        var updatedItems: [CollageItem] = []

        for index in stagedItems.indices {
            var currentItem = stagedItems[index]
            if currentItem.requiresAssetSave || currentItem.basePath == nil {
                let paths = collageRepository.persistItemAssets(
                    collageID: collageID,
                    itemID: currentItem.id,
                    baseImage: currentItem.baseImage,
                    cutout: currentItem.cutoutImage
                )
                currentItem.basePath = paths.basePath
                currentItem.cutoutPath = paths.cutoutPath
                currentItem.requiresAssetSave = false
            }
            stagedItems[index] = currentItem
            let collageItem = CollageItem(
                id: currentItem.id,
                baseImagePath: currentItem.basePath ?? "",
                cutoutImagePath: currentItem.cutoutPath,
                usesCutout: currentItem.usesCutout,
                zPosition: currentItem.zPosition,
                transform: currentItem.transform,
                shaderStack: currentItem.shaderStack
            )
            updatedItems.append(collageItem)
        }

        var updatedCollage = collage
        updatedCollage.items = updatedItems
        let savedCollage = try? collageRepository.saveCollage(updatedCollage, snapshot: snapshot)

        canvasItems = stagedItems
        isSaving = false
        hasUnsavedChanges = false
        photoLibraryService.saveImageToLibrary(snapshot) { _ in }
        collage = savedCollage ?? updatedCollage
        coordinator?.dismissCollage(shouldRefresh: true)
    }

    @MainActor
    private func performShaderRefresh(for itemID: UUID, stack: [ShaderType], sourceImage: UIImage) async {
        let filtered = shaderService.apply(shaders: stack, to: sourceImage)
        guard let idx = canvasItems.firstIndex(where: { $0.id == itemID }) else { return }
        var updatedItems = canvasItems
        updatedItems[idx].renderedImage = filtered ?? sourceImage
        canvasItems = updatedItems
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

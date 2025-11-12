import XCTest
import UIKit
import FactoryKit
@testable import ClassicUIKit

final class CollageViewModelTests: XCTestCase {

    private var repository: MockCollageRepository!
    private var photoLibrary: MockPhotoLibraryService!
    private var shaderService: MockShaderProcessingService!
    private var imageLoader: MockImageLoader!
    private var coordinator: MockCollageCoordinator!
    private var viewModel: CollageViewModel!

    override func setUp() {
        super.setUp()
        repository = MockCollageRepository()
        photoLibrary = MockPhotoLibraryService()
        shaderService = MockShaderProcessingService()
        imageLoader = MockImageLoader()
        coordinator = MockCollageCoordinator()
        Container.shared.collageRepository.register(factory: { repository })
        Container.shared.photoLibraryService.register(factory: { photoLibrary })
        Container.shared.shaderProcessingService.register(factory: { shaderService })
        Container.shared.imageLoader.register(factory: { imageLoader })
        viewModel = CollageViewModel(collageID: nil, coordinator: coordinator)
        viewModel.canvasSize = CGSize(width: 400, height: 600)
    }

    override func tearDown() {
        viewModel = nil
        coordinator = nil
        imageLoader = nil
        shaderService = nil
        photoLibrary = nil
        repository = nil
        super.tearDown()
    }

    func testImagePickerAddsCanvasItem() {
        let picker = MockPicker()
        let image = UIImage(systemName: "scribble") ?? UIImage()
        viewModel.imagePickerController(picker, didFinishPickingMediaWithInfo: [.originalImage: image])
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(viewModel.canvasItems.count, 1)
        XCTAssertTrue(viewModel.hasUnsavedChanges)
    }

    func testToggleShaderUpdatesStack() {
        let image = UIImage(systemName: "scribble") ?? UIImage()
        let item = CanvasItemModel(baseImage: image)
        viewModel.canvasItems = [item]
        viewModel.selectItem(item.id)
        viewModel.toggleShader(.pixellate)
        XCTAssertTrue(viewModel.canvasItems[0].shaderStack.contains(.pixellate))
    }

    func testSaveCollageDismissesOnSuccess() {
        let image = UIImage(systemName: "scribble") ?? UIImage()
        var item = CanvasItemModel(baseImage: image)
        item.basePath = nil
        viewModel.canvasItems = [item]
        viewModel.selectItem(item.id)

        let expectation = expectation(description: "save")
        coordinator.onDismiss = { shouldRefresh in
            if shouldRefresh { expectation.fulfill() }
        }

        viewModel.saveCollage(snapshot: image)
        wait(for: [expectation], timeout: 2)
        XCTAssertTrue(photoLibrary.didSaveImage)
    }
}

final class MockPhotoLibraryService: PhotoLibraryService {
    var didSaveImage = false
    var didPresentPicker = false
    func presentPicker(from controller: UIViewController, delegate: (UIImagePickerControllerDelegate & UINavigationControllerDelegate)?) {
        didPresentPicker = true
    }
    func saveImageToLibrary(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        didSaveImage = true
        completion(true)
    }
}

final class MockShaderProcessingService: ShaderProcessingService {
    func apply(shaders: [ShaderType], to image: UIImage) -> UIImage? {
        image
    }
}

final class MockCollageCoordinator: CollageCoordinating {
    var onDismiss: ((Bool) -> Void)?
    func dismissCollage(shouldRefresh: Bool) {
        onDismiss?(shouldRefresh)
    }
}

final class MockPicker: UIImagePickerController {
    var didDismiss = false
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        didDismiss = true
        completion?()
    }
}

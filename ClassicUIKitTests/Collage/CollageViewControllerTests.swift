import XCTest
import UIKit
import FactoryKit
@testable import ClassicUIKit

final class CollageViewControllerTests: XCTestCase {

    private var repository: MockCollageRepository!
    private var photoLibrary: MockPhotoLibraryService!
    private var shaderService: MockShaderProcessingService!
    private var imageLoader: MockImageLoader!
    private var coordinator: MockCollageCoordinator!
    private var viewModel: CollageViewModel!
    private var sut: CollageViewController!

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
        sut = CollageViewController(viewModel: viewModel)
        sut.loadViewIfNeeded()
        viewModel.canvasSize = CGSize(width: 400, height: 600)
    }

    override func tearDown() {
        sut = nil
        viewModel = nil
        coordinator = nil
        imageLoader = nil
        shaderService = nil
        photoLibrary = nil
        repository = nil
        super.tearDown()
    }

    func testHandleAddTapsPresentsPicker() {
        sut.handleAddTapped()
        XCTAssertTrue(photoLibrary.didPresentPicker)
    }

    func testCanvasRendersItems() {
        let image = UIImage(systemName: "scribble") ?? UIImage()
        var item = CanvasItemModel(baseImage: image)
        item.transform = CollageItemTransform(translation: .zero, scale: 1, rotation: 0, size: CGSize(width: 100, height: 120))
        viewModel.canvasItems = [item]
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(sut.canvasImageViews.count, 1)
    }
}

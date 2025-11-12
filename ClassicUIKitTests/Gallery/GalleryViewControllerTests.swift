import XCTest
import UIKit
import FactoryKit
@testable import ClassicUIKit

final class GalleryViewControllerTests: XCTestCase {

    private var repository: MockCollageRepository!
    private var imageLoader: MockImageLoader!
    private var coordinator: MockGalleryCoordinator!
    private var viewModel: GalleryViewModel!
    private var sut: GalleryViewController!

    override func setUp() {
        super.setUp()
        repository = MockCollageRepository()
        imageLoader = MockImageLoader()
        coordinator = MockGalleryCoordinator()
        Container.shared.collageRepository.register(factory: { repository })
        Container.shared.imageLoader.register(factory: { imageLoader })
        viewModel = GalleryViewModel(coordinator: coordinator)
        sut = GalleryViewController(viewModel: viewModel)
        sut.loadViewIfNeeded()
    }

    override func tearDown() {
        sut = nil
        viewModel = nil
        coordinator = nil
        imageLoader = nil
        repository = nil
        super.tearDown()
    }

    func testCollectionViewRendersItems() {
        let collage = Collage(id: UUID(), snapshotPath: nil, createdAt: .now, updatedAt: .now)
        viewModel.items = [GalleryDisplayModel(collage: collage, image: UIImage())]
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))

        let count = sut.collectionView.numberOfItems(inSection: 0)
        XCTAssertEqual(count, 1)
    }

    func testSelectingItemTriggersCoordinator() {
        let collage = Collage(id: UUID(), snapshotPath: nil, createdAt: .now, updatedAt: .now)
        viewModel.items = [GalleryDisplayModel(collage: collage, image: UIImage())]
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))

        let indexPath = IndexPath(item: 0, section: 0)
        sut.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        sut.collectionView.delegate?.collectionView?(sut.collectionView, didSelectItemAt: indexPath)

        XCTAssertEqual(coordinator.selectedCollageID, collage.id)
    }
}

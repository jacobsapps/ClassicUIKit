import XCTest
import UIKit
import FactoryKit
@testable import ClassicUIKit

final class GalleryViewModelTests: XCTestCase {

    private var repository: MockCollageRepository!
    private var imageLoader: MockImageLoader!
    private var coordinator: MockGalleryCoordinator!
    private var viewModel: GalleryViewModel!

    override func setUp() {
        super.setUp()
        repository = MockCollageRepository()
        imageLoader = MockImageLoader()
        coordinator = MockGalleryCoordinator()
        Container.shared.collageRepository.register(factory: { repository })
        Container.shared.imageLoader.register(factory: { imageLoader })
        viewModel = GalleryViewModel(coordinator: coordinator)
    }

    override func tearDown() {
        viewModel = nil
        coordinator = nil
        imageLoader = nil
        repository = nil
        super.tearDown()
    }

    func testLoadPopulatesItems() {
        let first = Collage(id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!, snapshotPath: "first", createdAt: .distantPast, updatedAt: .distantPast)
        let second = Collage(id: UUID(uuidString: "FFFFFFFF-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!, snapshotPath: "second", createdAt: .distantPast, updatedAt: Date())
        repository.collages = [first, second]
        imageLoader.images = ["first": UIImage(), "second": UIImage()]

        let expectation = expectation(description: "load")
        viewModel.load()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)

        XCTAssertEqual(viewModel.items.count, 2)
        XCTAssertTrue(viewModel.items.contains { $0.collage.id == first.id })
        XCTAssertTrue(viewModel.items.contains { $0.collage.id == second.id })
    }

    func testSelectCollageNotifiesCoordinator() {
        let collageID = UUID()
        viewModel.selectCollage(id: collageID, anchorView: nil)
        XCTAssertEqual(coordinator.selectedCollageID, collageID)
    }

    func testCreateNewCollageRequestsCoordinator() {
        viewModel.createNewCollage(from: nil)
        XCTAssertTrue(coordinator.didRequestNewCollage)
    }
}

final class MockCollageRepository: CollageRepository {
    var collages: [Collage] = []
    var savedCollage: Collage?

    func loadCollages() throws -> [Collage] {
        collages
    }

    func loadCollage(id: UUID) throws -> Collage? {
        collages.first { $0.id == id }
    }

    func saveCollage(_ collage: Collage, snapshot: UIImage?) throws -> Collage {
        savedCollage = collage
        return collage
    }

    func persistItemAssets(collageID: UUID, itemID: UUID, baseImage: UIImage, cutout: UIImage?) -> (basePath: String, cutoutPath: String?) {
        ("base", "cutout")
    }
}

final class MockImageLoader: ImageLoader {
    var images: [String: UIImage] = [:]
    func image(for path: String?) -> UIImage? {
        guard let path else { return nil }
        return images[path]
    }
}

final class MockGalleryCoordinator: GalleryCoordinating {
    var selectedCollageID: UUID?
    var didRequestNewCollage = false

    func showCollage(for collageID: UUID?, from sourceView: UIView?) {
        if let collageID {
            selectedCollageID = collageID
        } else {
            didRequestNewCollage = true
        }
    }
}

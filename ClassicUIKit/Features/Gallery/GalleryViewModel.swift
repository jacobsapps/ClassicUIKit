import Foundation
import Observation
import UIKit
import FactoryKit

@Observable
final class GalleryViewModel {

    var items: [GalleryDisplayModel] = []
    var isLoading: Bool = false

    @ObservationIgnored @Injected(\.collageRepository) private var collageRepository: CollageRepository
    @ObservationIgnored @Injected(\.imageLoader) private var imageLoader: ImageLoader
    @ObservationIgnored private weak var coordinator: GalleryCoordinating?
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    init(coordinator: GalleryCoordinating?) {
        self.coordinator = coordinator
    }

    deinit {
        loadTask?.cancel()
    }

    func load() {
        loadTask?.cancel()
        isLoading = true
        loadTask = Task { [weak self] in
            await self?.performLoad()
        }
    }

    func selectCollage(id: UUID, anchorView: UIView?) {
        coordinator?.showCollage(for: id, from: anchorView)
    }

    func createNewCollage(from view: UIView?) {
        coordinator?.showCollage(for: nil, from: view)
    }
    
    func deleteCollage(id: UUID) {
        Task { [weak self] in
            await self?.performDelete(id: id)
        }
    }

    @MainActor
    private func performLoad() async {
        let collages = (try? collageRepository.loadCollages()) ?? []
        let models = collages.map { collage -> GalleryDisplayModel in
            let image = imageLoader.image(for: collage.snapshotPath)
            return GalleryDisplayModel(collage: collage, image: image)
        }
        items = models
        isLoading = false
    }

    @MainActor
    private func performDelete(id: UUID) async {
        try? collageRepository.deleteCollage(id: id)
        items.removeAll { $0.collage.id == id }
    }
}

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

    @concurrent
    private func performLoad() async {
        let repository = collageRepository
        let loader = imageLoader
        let collages = (try? repository.loadCollages()) ?? []
        let models = collages.map { collage -> GalleryDisplayModel in
            let image = loader.image(for: collage.snapshotPath)
            return GalleryDisplayModel(collage: collage, image: image)
        }
        await MainActor.run {
            self.items = models
            self.isLoading = false
        }
    }

    @concurrent
    private func performDelete(id: UUID) async {
        let repository = collageRepository
        try? repository.deleteCollage(id: id)
        await MainActor.run {
            self.items.removeAll { $0.collage.id == id }
        }
    }
}

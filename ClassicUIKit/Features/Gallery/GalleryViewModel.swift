import Foundation
import Observation
import UIKit
import FactoryKit

@Observable
final class GalleryViewModel {

    var items: [GalleryDisplayModel] = []
    var isLoading: Bool = false

    @ObservationIgnored @Injected(Container.shared.collageRepository) private var collageRepository: CollageRepository
    @ObservationIgnored @Injected(Container.shared.imageLoader) private var imageLoader: ImageLoader
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
        loadTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let collages = (try? self.collageRepository.loadCollages()) ?? []
            let displayModels = collages.map { collage -> GalleryDisplayModel in
                let image = self.imageLoader.image(for: collage.snapshotPath)
                return GalleryDisplayModel(collage: collage, image: image)
            }
            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.items = displayModels
                self.isLoading = false
            }
        }
    }

    func selectCollage(id: UUID, anchorView: UIView?) {
        coordinator?.showCollage(for: id, from: anchorView)
    }

    func createNewCollage(from view: UIView?) {
        coordinator?.showCollage(for: nil, from: view)
    }
}

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
        let repository = collageRepository
        let loader = imageLoader
        loadTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let collages = await MainActor.run { (try? repository.loadCollages()) ?? [] }
            var models: [GalleryDisplayModel] = []
            for collage in collages {
                let image = await MainActor.run { loader.image(for: collage.snapshotPath) }
                models.append(GalleryDisplayModel(collage: collage, image: image))
            }
            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.items = models
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

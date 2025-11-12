import FactoryKit
import UIKit

extension Container {
    private func makeCollageDatabase() -> CollageDatabase {
        do {
            return try CollageDatabaseImpl()
        } catch {
            preconditionFailure("Failed to create CollageDatabaseImpl: \(error)")
        }
    }

    var collageDatabase: Factory<CollageDatabase> {
        self { self.makeCollageDatabase() }.singleton
    }

    @MainActor
    var collageRepository: Factory<CollageRepository> {
        self { @MainActor in
            CollageRepositoryImpl(database: Container.shared.collageDatabase())
        }.singleton
    }

    @MainActor
    var imageLoader: Factory<ImageLoader> {
        self { @MainActor in
            ImageLoaderImpl()
        }
    }

    @MainActor
    var photoLibraryService: Factory<PhotoLibraryService> {
        self { @MainActor in
            PhotoLibraryServiceImpl()
        }.singleton
    }

    @MainActor
    var shaderProcessingService: Factory<ShaderProcessingService> {
        self { @MainActor in
            ShaderProcessingServiceImpl()
        }.singleton
    }
}

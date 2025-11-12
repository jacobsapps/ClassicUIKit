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

    var collageRepository: Factory<CollageRepository> {
        self {
            CollageRepositoryImpl(database: Container.shared.collageDatabase())
        }.singleton
    }

    var imageLoader: Factory<ImageLoader> {
        self {
            ImageLoaderImpl()
        }
    }

    var photoLibraryService: Factory<PhotoLibraryService> {
        self {
            PhotoLibraryServiceImpl()
        }.singleton
    }

    var shaderProcessingService: Factory<ShaderProcessingService> {
        self {
            ShaderProcessingServiceImpl()
        }.singleton
    }
}

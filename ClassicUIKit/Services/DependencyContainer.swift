import FactoryKit
import UIKit

extension Container {
    var collageDatabase: Factory<CollageDatabase> {
        self {
            do {
                return try CollageDatabaseImpl()
            } catch {
                fatalError("Failed to create CollageDatabaseImpl: \(error)")
            }
        }.singleton
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

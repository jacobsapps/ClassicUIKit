import UIKit
import FactoryKit

protocol GalleryCoordinating: AnyObject {
    func showCollage(for collageID: UUID?, from sourceView: UIView?)
}

protocol CollageCoordinating: AnyObject {
    func dismissCollage(shouldRefresh: Bool)
}

final class AppCoordinator: Coordinator {

    let navigationController: UINavigationController
    private let window: UIWindow
    private lazy var heroTransitionDelegate = HeroTransitioningDelegate()

    init(window: UIWindow) {
        self.window = window
        self.navigationController = UINavigationController()
        navigationController.navigationBar.prefersLargeTitles = true
    }

    func start() {
        let viewModel = GalleryViewModel(coordinator: self)
        let viewController = GalleryViewController(viewModel: viewModel)
        navigationController.viewControllers = [viewController]
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
    }
}

extension AppCoordinator: GalleryCoordinating {
    func showCollage(for collageID: UUID?, from sourceView: UIView?) {
        let viewModel = CollageViewModel(collageID: collageID, coordinator: self)
        let viewController = CollageViewController(viewModel: viewModel)
        if let collageID, let sourceView {
            viewController.modalPresentationStyle = .custom
            heroTransitionDelegate.originView = sourceView
            viewController.transitioningDelegate = heroTransitionDelegate
        } else {
            viewController.modalPresentationStyle = .fullScreen
            viewController.transitioningDelegate = nil
            heroTransitionDelegate.originView = nil
        }
        navigationController.present(viewController, animated: true)
    }
}

extension AppCoordinator: CollageCoordinating {
    func dismissCollage(shouldRefresh: Bool) {
        navigationController.dismiss(animated: true) {
            guard shouldRefresh,
                  let galleryController = self.navigationController.viewControllers.first as? GalleryViewController else { return }
            galleryController.reloadContent()
        }
    }
}

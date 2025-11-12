import UIKit
import SnapKit

private enum GallerySectionIdentifier {
    static let main = "gallery-main"
}

final class GalleryViewController: UIViewController {

    let viewModel: GalleryViewModel
    private(set) lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 16
        layout.minimumLineSpacing = 16
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.contentInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        collectionView.register(GalleryCollectionViewCell.self, forCellWithReuseIdentifier: GalleryCollectionViewCell.reuseIdentifier)
        collectionView.delegate = self
        collectionView.alwaysBounceVertical = true
        return collectionView
    }()

    lazy var dataSource = makeDataSource()
    private let loadingView = UIActivityIndicatorView(style: .large)
    private let emptyView = EmptyStateView(message: "Create your first collage by tapping ➕")
    private lazy var deleteGesture: UILongPressGestureRecognizer = {
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        gesture.minimumPressDuration = 0.5
        return gesture
    }()

    init(viewModel: GalleryViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        title = "Gallery"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureNavbar()
        layoutViews()
        collectionView.addGestureRecognizer(deleteGesture)
        applySnapshot()
        updateLoadingState()
        viewModel.load()
    }

    func reloadContent() {
        viewModel.load()
    }

    private func configureNavbar() {
        let addImage = UIImage(systemName: "plus")
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: addImage, style: .plain, target: self, action: #selector(handleAddTapped))
    }
    private func layoutViews() {
        view.addSubview(collectionView)
        view.addSubview(loadingView)
        view.addSubview(emptyView)

        collectionView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        loadingView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        emptyView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.lessThanOrEqualToSuperview().multipliedBy(0.7)
        }
        emptyView.isHidden = true
    }

    override func updateProperties() {
        super.updateProperties()
        applySnapshot()
        updateLoadingState()
    }

    private func updateLoadingState() {
        viewModel.isLoading ? loadingView.startAnimating() : loadingView.stopAnimating()
        emptyView.isHidden = !(viewModel.items.isEmpty && !viewModel.isLoading)
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<String, UUID> {
        UICollectionViewDiffableDataSource(collectionView: collectionView) { [weak self] collectionView, indexPath, collageID in
            guard
                let self,
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: GalleryCollectionViewCell.reuseIdentifier,
                    for: indexPath
                ) as? GalleryCollectionViewCell
            else {
                return UICollectionViewCell()
            }
            guard let model = self.viewModel.items.first(where: { $0.collage.id == collageID }) else {
                return cell
            }
            cell.configurationUpdateHandler = { [weak self] cell, _ in
                guard
                    let self,
                    let galleryCell = cell as? GalleryCollectionViewCell,
                    let current = self.viewModel.items.first(where: { $0.collage.id == collageID })
                else { return }
                galleryCell.configure(with: current)
            }
            cell.configure(with: model)
            return cell
        }
    }

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<String, UUID>()
        snapshot.appendSections([GallerySectionIdentifier.main])
        let identifiers = viewModel.items.map { $0.collage.id }
        snapshot.appendItems(identifiers, toSection: GallerySectionIdentifier.main)
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    @objc private func handleAddTapped() {
        let anchor = navigationController?.navigationBar ?? view
        viewModel.createNewCollage(from: anchor)
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let location = gesture.location(in: collectionView)
        guard
            let indexPath = collectionView.indexPathForItem(at: location),
            let collageID = dataSource.itemIdentifier(for: indexPath)
        else { return }

        let alert = UIAlertController(title: "Delete collage?", message: "This action can't be undone.", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.viewModel.deleteCollage(id: collageID)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = alert.popoverPresentationController,
           let cell = collectionView.cellForItem(at: indexPath) {
            popover.sourceView = cell
            popover.sourceRect = cell.bounds
        }
        present(alert, animated: true)
    }
}

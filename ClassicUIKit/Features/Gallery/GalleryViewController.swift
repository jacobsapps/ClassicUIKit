import UIKit
import SnapKit
import Observation

final class GalleryViewController: UIViewController {

    private enum Section {
        case main
    }

    private let viewModel: GalleryViewModel
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

    private lazy var dataSource = makeDataSource()
    private let loadingView = UIActivityIndicatorView(style: .large)
    private let emptyView = EmptyStateView(message: "Create your first collage by tapping ➕")

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
        bindViewModel()
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

    private func bindViewModel() {
        withObservationTracking { [weak self] in
            guard let self else { return }
            self.updateProperties()
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.bindViewModel()
            }
        }
    }

    private func updateProperties() {
        applySnapshot()
        updateLoadingState()
    }

    private func updateLoadingState() {
        viewModel.isLoading ? loadingView.startAnimating() : loadingView.stopAnimating()
        emptyView.isHidden = !(viewModel.items.isEmpty && !viewModel.isLoading)
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, GalleryDisplayModel> {
        UICollectionViewDiffableDataSource(collectionView: collectionView) { [weak self] collectionView, indexPath, item in
            guard
                let self,
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: GalleryCollectionViewCell.reuseIdentifier,
                    for: indexPath
                ) as? GalleryCollectionViewCell
            else {
                return UICollectionViewCell()
            }
            let collageID = item.collage.id
            cell.configurationUpdateHandler = { [weak self] cell, _ in
                withObservationTracking {
                    guard let self else { return }
                    guard let current = self.viewModel.items.first(where: { $0.collage.id == collageID }) else { return }
                    cell.configure(with: current)
                } onChange: { [weak cell] _ in
                    cell?.setNeedsUpdateConfiguration()
                }
            }
            cell.setNeedsUpdateConfiguration()
            return cell
        }
    }

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, GalleryDisplayModel>()
        snapshot.appendSections([.main])
        snapshot.appendItems(viewModel.items, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    @objc private func handleAddTapped() {
        let anchor = navigationController?.navigationBar ?? view
        viewModel.createNewCollage(from: anchor)
    }
}

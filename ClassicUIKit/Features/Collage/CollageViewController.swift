import UIKit
import SnapKit

final class CollageViewController: UIViewController {

    private let viewModel: CollageViewModel
    private(set) var canvasImageViews: [UUID: CollageCanvasImageView] = [:]
    private var needsDeferredCanvasSync = false

    private let canvasView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.layer.cornerRadius = 0
        view.clipsToBounds = true
        return view
    }()

    private let floatingToolbar = FloatingToolbarView()
    private let navigationBar: UINavigationBar = {
        let bar = UINavigationBar()
        bar.isTranslucent = true
        bar.prefersLargeTitles = false
        return bar
    }()
    private let navItem = UINavigationItem(title: "")
    private let savingOverlay = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    private let savingIndicator = UIActivityIndicatorView(style: .large)

    init(viewModel: CollageViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        modalPresentationCapturesStatusBarAppearance = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureNavigationBar()
        layoutViews()
        setupCanvasTap()
        viewModel.loadIfNeeded()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let newSize = canvasView.bounds.size
        if newSize != .zero && newSize != viewModel.canvasSize {
            viewModel.canvasSize = newSize
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if needsDeferredCanvasSync && canvasView.bounds != .zero {
            needsDeferredCanvasSync = false
            syncCanvas()
        }
    }

    override func updateProperties() {
        super.updateProperties()
        syncCanvas()
        updateToolbar()
        updateSavingState()
    }

    private func configureNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.clear]
        navigationBar.standardAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.tintColor = .white
        navigationBar.setItems([navItem], animated: false)

        let backItem = UIBarButtonItem(image: UIImage(systemName: "arrow.backward"),
                                       style: .plain,
                                       target: self,
                                       action: #selector(handleBackButtonTapped))
        backItem.accessibilityLabel = "Back"

        let saveItem = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.down.fill"),
                                       style: .plain,
                                       target: self,
                                       action: #selector(handleSaveButtonTapped))
        saveItem.accessibilityLabel = "Save Collage"

        let addItem = UIBarButtonItem(image: UIImage(systemName: "photo.badge.plus.fill"),
                                      style: .plain,
                                      target: self,
                                      action: #selector(handleAddButtonTapped))
        addItem.accessibilityLabel = "Add Photo"

        navItem.leftBarButtonItem = backItem
        navItem.rightBarButtonItems = [addItem, saveItem]
    }

    private func layoutViews() {
        view.insertSubview(canvasView, at: 0)
        view.addSubview(navigationBar)
        view.addSubview(floatingToolbar)
        view.addSubview(savingOverlay)
        savingOverlay.contentView.addSubview(savingIndicator)

        navigationBar.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
        }

        canvasView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        floatingToolbar.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).inset(24)
        }
        floatingToolbar.alpha = 0
        floatingToolbar.isHidden = true

        savingOverlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        savingOverlay.isHidden = true

        savingIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        floatingToolbar.onCutoutToggle = { [weak self] in
            self?.viewModel.toggleCutout()
        }
        floatingToolbar.onShaderToggle = { [weak self] shader in
            self?.viewModel.toggleShader(shader)
        }
    }

    private func updateToolbar() {
        let state = viewModel.toolbarState
        floatingToolbar.update(with: state)
        let shouldShow = state.isVisible
        if shouldShow { floatingToolbar.isHidden = false }
        UIView.animate(withDuration: 0.25) {
            self.floatingToolbar.alpha = shouldShow ? 1 : 0
        } completion: { _ in
            self.floatingToolbar.isHidden = !shouldShow
        }
    }

    private func updateSavingState() {
        if viewModel.isSaving {
            savingOverlay.isHidden = false
            savingIndicator.startAnimating()
        } else {
            savingOverlay.isHidden = true
            savingIndicator.stopAnimating()
        }
    }

    private func setupCanvasTap() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleCanvasTap(_:)))
        canvasView.addGestureRecognizer(tap)
    }

    private func syncCanvas() {
        guard canvasView.bounds != .zero else {
            needsDeferredCanvasSync = true
            return
        }
        needsDeferredCanvasSync = false
        let items = viewModel.canvasItems
        let ids = Set(items.map { $0.id })
        for (id, view) in canvasImageViews where !ids.contains(id) {
            view.removeFromSuperview()
            canvasImageViews.removeValue(forKey: id)
        }

        for item in items {
            let imageView = canvasImageViews[item.id] ?? createCanvasImageView(for: item)
            update(imageView: imageView, with: item)
        }
    }

    private func createCanvasImageView(for item: CanvasItemModel) -> CollageCanvasImageView {
        let imageView = CollageCanvasImageView(itemID: item.id, baseSize: item.transform.size, scale: item.transform.scale, rotation: item.transform.rotation)
        canvasView.addSubview(imageView)
        canvasImageViews[item.id] = imageView
        addGestures(to: imageView)
        return imageView
    }

    private func addGestures(to imageView: CollageCanvasImageView) {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        let rotation = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleItemTap(_:)))
        [pan, pinch, rotation, tap].forEach {
            $0.delegate = self
            imageView.addGestureRecognizer($0)
        }
    }

    private func update(imageView: CollageCanvasImageView, with item: CanvasItemModel) {
        imageView.baseSize = item.transform.size
        imageView.bounds.size = item.transform.size
        imageView.center = CGPoint(x: canvasView.bounds.center.x + item.transform.translation.x,
                                   y: canvasView.bounds.center.y + item.transform.translation.y)
        imageView.applyTransform(scale: item.transform.scale, rotation: item.transform.rotation)
        imageView.update(image: viewModel.renderedImage(for: item.id))
        imageView.setProcessing(item.isProcessingCutout)
        imageView.isSelected = viewModel.selectedItemID == item.id
        imageView.layer.zPosition = CGFloat(item.zPosition)
    }

    private func updateTransform(for imageView: CollageCanvasImageView) {
        let translation = CGPoint(
            x: imageView.center.x - canvasView.bounds.center.x,
            y: imageView.center.y - canvasView.bounds.center.y
        )
        let transform = CollageItemTransform(
            translation: translation,
            scale: imageView.currentScale,
            rotation: imageView.currentRotation,
            size: imageView.baseSize
        )
        viewModel.updateTransform(for: imageView.itemID, transform: transform)
    }

    @objc func handleAddTapped() {
        viewModel.presentImagePicker(from: self, delegate: self)
    }

    @objc func handleSaveTapped() {
        let previouslySelectedID = viewModel.selectedItemID
        if previouslySelectedID != nil {
            viewModel.selectItem(nil)
            view.layoutIfNeeded()
        }
        let snapshot = canvasView.snapshotImage()
        viewModel.saveCollage(snapshot: snapshot)
        if let previouslySelectedID {
            viewModel.selectItem(previouslySelectedID)
        }
    }

    func canvasFrame(in targetView: UIView) -> CGRect {
        targetView.convert(canvasView.bounds, from: canvasView)
    }

    @objc func handleBackTapped() {
        guard viewModel.hasUnsavedChanges else {
            viewModel.dismissWithoutSaving()
            return
        }
        let alert = UIAlertController(title: "Discard changes?", message: "You have unsaved edits.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Keep Editing", style: .cancel))
        alert.addAction(UIAlertAction(title: "Discard", style: .destructive) { [weak self] _ in
            self?.viewModel.dismissWithoutSaving()
        })
        present(alert, animated: true)
    }

    @objc func handleCanvasTap(_ gesture: UITapGestureRecognizer) {
        viewModel.selectItem(nil)
    }

    @objc func handleItemTap(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view as? CollageCanvasImageView else { return }
        viewModel.selectItem(view.itemID)
    }

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let imageView = gesture.view as? CollageCanvasImageView else { return }
        let translation = gesture.translation(in: canvasView)
        if gesture.state == .began {
            viewModel.selectItem(imageView.itemID)
        }
        imageView.center = CGPoint(x: imageView.center.x + translation.x, y: imageView.center.y + translation.y)
        gesture.setTranslation(.zero, in: canvasView)
        if gesture.state == .ended {
            updateTransform(for: imageView)
        }
    }

    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let imageView = gesture.view as? CollageCanvasImageView else { return }
        if gesture.state == .began {
            viewModel.selectItem(imageView.itemID)
        }
        let newScale = imageView.currentScale * gesture.scale
        imageView.applyTransform(scale: newScale, rotation: imageView.currentRotation)
        gesture.scale = 1
        if gesture.state == .ended {
            updateTransform(for: imageView)
        }
    }

    @objc func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        guard let imageView = gesture.view as? CollageCanvasImageView else { return }
        if gesture.state == .began {
            viewModel.selectItem(imageView.itemID)
        }
        let newRotation = imageView.currentRotation + gesture.rotation
        imageView.applyTransform(scale: imageView.currentScale, rotation: newRotation)
        gesture.rotation = 0
        if gesture.state == .ended {
            updateTransform(for: imageView)
        }
    }

    @objc private func handleBackButtonTapped() {
        handleBackTapped()
    }

    @objc private func handleAddButtonTapped() {
        handleAddTapped()
    }

    @objc private func handleSaveButtonTapped() {
        handleSaveTapped()
    }
}

extension CollageViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage else { return }
        viewModel.addImage(image)
    }
}

extension CollageViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

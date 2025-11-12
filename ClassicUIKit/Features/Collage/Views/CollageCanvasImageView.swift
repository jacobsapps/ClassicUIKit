import UIKit
import SnapKit

final class CollageCanvasImageView: UIView {

    let itemID: UUID
    var baseSize: CGSize
    var currentScale: CGFloat
    var currentRotation: CGFloat

    private let imageView = UIImageView()
    private let selectionLayer = CAShapeLayer()
    private let loadingView = UIActivityIndicatorView(style: .medium)

    var isSelected: Bool = false {
        didSet { updateSelectionAppearance() }
    }

    init(itemID: UUID, baseSize: CGSize, scale: CGFloat, rotation: CGFloat) {
        self.itemID = itemID
        self.baseSize = baseSize
        self.currentScale = scale
        self.currentRotation = rotation
        super.init(frame: CGRect(origin: .zero, size: baseSize))
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        isUserInteractionEnabled = true
        layer.shadowColor = UIColor.black.withAlphaComponent(0.25).cgColor
        layer.shadowOpacity = 1
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 6)

        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 16
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        selectionLayer.fillColor = UIColor.clear.cgColor
        selectionLayer.strokeColor = UIColor.systemBlue.cgColor
        selectionLayer.lineWidth = 3
        selectionLayer.isHidden = true
        layer.addSublayer(selectionLayer)

        addSubview(loadingView)
        loadingView.hidesWhenStopped = true
        loadingView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        selectionLayer.path = UIBezierPath(roundedRect: bounds.insetBy(dx: 3, dy: 3), cornerRadius: 18).cgPath
        selectionLayer.frame = bounds
    }

    func update(image: UIImage?) {
        imageView.image = image
    }

    func setProcessing(_ processing: Bool) {
        processing ? loadingView.startAnimating() : loadingView.stopAnimating()
    }

    func applyTransform(scale: CGFloat, rotation: CGFloat) {
        currentScale = scale
        currentRotation = rotation
        let transform = CGAffineTransform(rotationAngle: rotation).scaledBy(x: scale, y: scale)
        self.transform = transform
    }

    private func updateSelectionAppearance() {
        selectionLayer.isHidden = !isSelected
    }
}

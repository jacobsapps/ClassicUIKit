import UIKit
import SnapKit
import FactoryKit

final class FloatingToolbarView: UIView {

    var onCutoutToggle: (() -> Void)?
    var onShaderToggle: ((ShaderType) -> Void)?
    var onDone: (() -> Void)?
    var onDelete: (() -> Void)?

    private enum Constants {
        static let containerCornerRadius: CGFloat = 26
        static let blurContentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        static let horizontalContentPadding: CGFloat = 16
    }

    private let blurView: UIVisualEffectView = {
        UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    }()

    private let highlightLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor.white.withAlphaComponent(0.35).cgColor,
            UIColor.white.withAlphaComponent(0.05).cgColor
        ]
        layer.startPoint = CGPoint(x: 0, y: 0)
        layer.endPoint = CGPoint(x: 1, y: 1)
        return layer
    }()

    private let scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.alwaysBounceHorizontal = true
        scroll.contentInsetAdjustmentBehavior = .never
        return scroll
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 12
        return stack
    }()

    @Injected(\.shaderProcessingService) private var shaderService: ShaderProcessingService

    private let cutoutButton = FloatingToggleButton(symbolName: "scissors")
    private var shaderButtons: [ShaderType: FloatingToggleButton] = [:]
    private var shaderLookup: [ObjectIdentifier: ShaderType] = [:]
    private let doneButton = FloatingToolbarActionButton(symbolName: "checkmark.circle.fill", tintColor: .systemGreen)
    private let deleteButton = FloatingToolbarActionButton(symbolName: "trash.fill", tintColor: .systemRed)
    private let leadingSpacer = UIView()
    private let trailingSpacer = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        layer.cornerRadius = Constants.containerCornerRadius
        layer.cornerCurve = .continuous
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.withAlphaComponent(0.25).cgColor
        layer.shadowOpacity = 1
        layer.shadowRadius = 16
        layer.shadowOffset = CGSize(width: 0, height: 10)

        addSubview(blurView)
        blurView.layer.cornerRadius = Constants.containerCornerRadius
        blurView.layer.cornerCurve = .continuous
        blurView.clipsToBounds = true
        blurView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        blurView.layer.insertSublayer(highlightLayer, at: 0)

        blurView.contentView.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(Constants.blurContentInset)
        }

        scrollView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.equalTo(scrollView.contentLayoutGuide.snp.top)
            make.bottom.equalTo(scrollView.contentLayoutGuide.snp.bottom)
            make.leading.equalTo(scrollView.contentLayoutGuide.snp.leading)
            make.trailing.equalTo(scrollView.contentLayoutGuide.snp.trailing)
            make.height.equalTo(scrollView.frameLayoutGuide.snp.height)
            make.width.greaterThanOrEqualTo(scrollView.frameLayoutGuide.snp.width)
            make.width.equalTo(scrollView.frameLayoutGuide.snp.width).priority(.high)
        }

        doneButton.addTarget(self, action: #selector(handleDoneTap), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(handleDeleteTap), for: .touchUpInside)
        cutoutButton.addTarget(self, action: #selector(handleCutoutTap), for: .touchUpInside)

        [leadingSpacer, trailingSpacer].forEach { spacer in
            spacer.translatesAutoresizingMaskIntoConstraints = false
            spacer.isUserInteractionEnabled = false
            spacer.backgroundColor = .clear
            spacer.widthAnchor.constraint(equalToConstant: Constants.horizontalContentPadding).isActive = true
        }

        stackView.addArrangedSubview(leadingSpacer)
        stackView.setCustomSpacing(0, after: leadingSpacer)

        var lastInteractiveView: UIView?
        func appendButton(_ button: UIView) {
            stackView.addArrangedSubview(button)
            lastInteractiveView = button
        }

        appendButton(doneButton)
        appendButton(deleteButton)
        appendButton(cutoutButton)

        ShaderType.allCases.forEach { shader in
            let button = FloatingToggleButton(symbolName: shader.symbolName)
            button.addTarget(self, action: #selector(handleShaderTap(_:)), for: .touchUpInside)
            appendButton(button)
            shaderButtons[shader] = button
            shaderLookup[ObjectIdentifier(button)] = shader
            generatePreview(for: shader, button: button)
        }

        stackView.addArrangedSubview(trailingSpacer)
        if let lastInteractiveView {
            stackView.setCustomSpacing(0, after: lastInteractiveView)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        highlightLayer.frame = blurView.bounds
        highlightLayer.cornerRadius = blurView.layer.cornerRadius
    }

    func update(with state: CollageToolbarState) {
        isHidden = !state.isVisible
        isUserInteractionEnabled = state.isVisible
        cutoutButton.isToggled = state.isCutoutActive
        shaderButtons.forEach { shader, button in
            button.isToggled = state.shaderStates[shader] ?? false
        }
    }

    @objc private func handleCutoutTap() {
        onCutoutToggle?()
    }

    @objc private func handleShaderTap(_ sender: FloatingToggleButton) {
        guard let shader = shaderLookup[ObjectIdentifier(sender)] else { return }
        onShaderToggle?(shader)
    }

    @objc private func handleDoneTap() {
        onDone?()
    }

    @objc private func handleDeleteTap() {
        onDelete?()
    }

    private func generatePreview(for shader: ShaderType, button: FloatingToggleButton) {
        guard let baseImage = makeBaseIcon(for: shader) else { return }
        button.setIconImage(baseImage)
        Task.detached(priority: .userInitiated) { [weak self, weak button] in
            guard let self else { return }
            let filtered = await self.applyPreviewShader(shader, to: baseImage)
            await MainActor.run {
                guard
                    let button,
                    self.shaderButtons[shader] === button
                else { return }
                button.setIconImage(filtered)
            }
        }
    }

    private func applyPreviewShader(_ shader: ShaderType, to image: UIImage) async -> UIImage {
        await MainActor.run { [weak self] in
            self?.shaderService.apply(shaders: [shader], to: image) ?? image
        }
    }

    private func makeBaseIcon(for shader: ShaderType) -> UIImage? {
        let size = CGSize(width: 44, height: 44)
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        guard let symbol = UIImage(systemName: shader.symbolName, withConfiguration: symbolConfig)?
            .withRenderingMode(.alwaysTemplate) else { return nil }

        let renderer = UIGraphicsImageRenderer(size: size)
        let colors = shader.previewGradientColors
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: size.width / 2)
            context.cgContext.saveGState()
            path.addClip()

            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors.map { $0.cgColor } as CFArray,
                locations: nil
            ) {
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            } else {
                colors.first?.setFill()
                context.fill(rect)
            }
            context.cgContext.restoreGState()

            UIColor.white.set()
            let inset: CGFloat = 10
            symbol.draw(in: rect.insetBy(dx: inset, dy: inset))
        }.withRenderingMode(.alwaysOriginal)
    }

}

private extension ShaderType {
    var previewGradientColors: [UIColor] {
        switch self {
        case .pixellate:
            return [
                UIColor(red: 0.95, green: 0.28, blue: 0.62, alpha: 1.0),
                UIColor(red: 1.0, green: 0.58, blue: 0.16, alpha: 1.0)
            ]
        case .grainy:
            return [
                UIColor(red: 0.38, green: 0.32, blue: 0.05, alpha: 1.0),
                UIColor(red: 0.77, green: 0.65, blue: 0.18, alpha: 1.0)
            ]
        case .grayscale:
            return [
                UIColor(white: 0.15, alpha: 1.0),
                UIColor(white: 0.8, alpha: 1.0)
            ]
        case .spectral:
            return [
                UIColor(red: 0.64, green: 0.14, blue: 0.84, alpha: 1.0),
                UIColor(red: 1.0, green: 0.33, blue: 0.68, alpha: 1.0)
            ]
        case .threeDGlasses:
            return [
                UIColor(red: 0.95, green: 0.18, blue: 0.2, alpha: 1.0),
                UIColor(red: 1.0, green: 0.54, blue: 0.0, alpha: 1.0)
            ]
        case .alien:
            return [
                UIColor(red: 0.1, green: 0.85, blue: 0.3, alpha: 1.0),
                UIColor(red: 0.52, green: 1.0, blue: 0.58, alpha: 1.0)
            ]
        case .thickGlassSquares:
            return [
                UIColor(red: 0.0, green: 0.74, blue: 0.46, alpha: 1.0),
                UIColor(red: 0.18, green: 0.95, blue: 0.65, alpha: 1.0)
            ]
        case .lens:
            return [
                UIColor(red: 1.0, green: 0.78, blue: 0.1, alpha: 1.0),
                UIColor(red: 1.0, green: 0.32, blue: 0.25, alpha: 1.0)
            ]
        }
    }
}

final class FloatingToggleButton: UIButton {

    var isToggled: Bool = false {
        didSet { updateAppearance() }
    }

    init(symbolName: String, size: CGFloat = 44) {
        super.init(frame: .zero)
        var config = UIButton.Configuration.plain()
        config.contentInsets = .zero
        config.imagePadding = 0
        config.image = makeSymbolImage(named: symbolName, tint: .label)
        self.configuration = config
        layer.cornerRadius = size / 2
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        backgroundColor = UIColor.white.withAlphaComponent(0.18)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: size).isActive = true
        widthAnchor.constraint(equalToConstant: size).isActive = true
        imageView?.contentMode = .scaleAspectFit
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setIconImage(_ image: UIImage?) {
        configuration?.image = image?.withRenderingMode(.alwaysOriginal)
    }

    private func updateAppearance() {
        if isToggled {
            layer.borderWidth = 2
            layer.borderColor = UIColor.systemBlue.cgColor
            backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
        } else {
            layer.borderWidth = 1
            layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
            backgroundColor = UIColor.white.withAlphaComponent(0.18)
        }
    }
}

final class FloatingToolbarActionButton: UIButton {

    init(symbolName: String, tintColor: UIColor) {
        super.init(frame: .zero)
        var config = UIButton.Configuration.plain()
        config.contentInsets = .zero
        config.imagePadding = 0
        config.image = makeSymbolImage(named: symbolName, tint: tintColor)
        self.configuration = config
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous
        backgroundColor = UIColor.white.withAlphaComponent(0.18)
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 44).isActive = true
        widthAnchor.constraint(equalToConstant: 44).isActive = true
        imageView?.contentMode = .scaleAspectFit
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@inline(__always)
private func makeSymbolImage(named symbolName: String, tint: UIColor) -> UIImage? {
    let pointSize: CGFloat = 24
    let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
    guard let symbol = UIImage(systemName: symbolName, withConfiguration: config)?
        .withRenderingMode(.alwaysTemplate) else { return nil }
    let size = CGSize(width: pointSize, height: pointSize)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { _ in
        tint.set()
        symbol.draw(in: CGRect(origin: .zero, size: size))
    }.withRenderingMode(.alwaysOriginal)
}

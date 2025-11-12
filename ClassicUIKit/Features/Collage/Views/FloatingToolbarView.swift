import UIKit
import SnapKit

final class FloatingToolbarView: UIView {

    var onCutoutToggle: (() -> Void)?
    var onShaderToggle: ((ShaderType) -> Void)?
    var onDone: (() -> Void)?
    var onDelete: (() -> Void)?

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

    private let cutoutButton = FloatingToggleButton(symbolName: "scissors")
    private var shaderButtons: [ShaderType: FloatingToggleButton] = [:]
    private var shaderLookup: [ObjectIdentifier: ShaderType] = [:]
    private let doneButton = FloatingToolbarActionButton(symbolName: "checkmark.circle.fill", tintColor: .systemGreen)
    private let deleteButton = FloatingToolbarActionButton(symbolName: "trash.fill", tintColor: .systemRed)

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        layer.cornerRadius = 26
        layer.cornerCurve = .continuous
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.withAlphaComponent(0.25).cgColor
        layer.shadowOpacity = 1
        layer.shadowRadius = 16
        layer.shadowOffset = CGSize(width: 0, height: 10)

        addSubview(blurView)
        blurView.layer.cornerRadius = 26
        blurView.layer.cornerCurve = .continuous
        blurView.clipsToBounds = true
        blurView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        blurView.layer.insertSublayer(highlightLayer, at: 0)

        blurView.contentView.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16))
        }

        scrollView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.height.equalTo(scrollView.frameLayoutGuide)
        }

        doneButton.addTarget(self, action: #selector(handleDoneTap), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(handleDeleteTap), for: .touchUpInside)
        cutoutButton.addTarget(self, action: #selector(handleCutoutTap), for: .touchUpInside)

        stackView.addArrangedSubview(doneButton)
        stackView.addArrangedSubview(deleteButton)
        stackView.addArrangedSubview(cutoutButton)

        ShaderType.allCases.forEach { shader in
            let button = FloatingToggleButton(symbolName: shader.symbolName)
            button.addTarget(self, action: #selector(handleShaderTap(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
            shaderButtons[shader] = button
            shaderLookup[ObjectIdentifier(button)] = shader
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
}

final class FloatingToggleButton: UIButton {

    var isToggled: Bool = false {
        didSet { updateAppearance() }
    }

    init(symbolName: String, size: CGFloat = 44) {
        super.init(frame: .zero)
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: symbolName)
        configuration.baseForegroundColor = .label
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        configuration.contentInsets = .zero
        self.configuration = configuration
        layer.cornerRadius = size / 2
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        backgroundColor = UIColor.white.withAlphaComponent(0.18)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant(size)).isActive = true
        widthAnchor.constraint(equalToConstant(size)).isActive = true
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateAppearance() {
        if isToggled {
            backgroundColor = UIColor.systemBlue.withAlphaComponent(0.9)
            layer.borderColor = UIColor.systemBlue.cgColor
            configuration?.baseForegroundColor = .white
        } else {
            backgroundColor = UIColor.white.withAlphaComponent(0.18)
            layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
            configuration?.baseForegroundColor = .label
        }
    }
}

final class FloatingToolbarActionButton: UIButton {

    init(symbolName: String, tintColor: UIColor) {
        super.init(frame: .zero)
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: symbolName)
        configuration.baseForegroundColor = tintColor
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        configuration.contentInsets = .zero
        self.configuration = configuration
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous
        backgroundColor = UIColor.white.withAlphaComponent(0.18)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant(44)).isActive = true
        widthAnchor.constraint(equalToConstant(44)).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

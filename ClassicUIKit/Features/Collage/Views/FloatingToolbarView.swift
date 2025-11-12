import UIKit
import SnapKit

final class FloatingToolbarView: UIView {

    var onCutoutToggle: (() -> Void)?
    var onShaderToggle: ((ShaderType) -> Void)?

    private let blurView: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemUltraThinMaterial)
        return UIVisualEffectView(effect: blur)
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

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 12
        return stack
    }()

    private let cutoutButton = FloatingToggleButton(symbolName: "scissors")
    private let pixellateButton = FloatingToggleButton(symbolName: "rectangle.split.2x2")
    private let threeDButton = FloatingToggleButton(symbolName: "eyeglasses")
    private let glitchButton = FloatingToggleButton(symbolName: "waveform")

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        layer.cornerRadius = 36
        layer.cornerCurve = .continuous
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.withAlphaComponent(0.25).cgColor
        layer.shadowOpacity = 1
        layer.shadowRadius = 20
        layer.shadowOffset = CGSize(width: 0, height: 12)

        addSubview(blurView)
        blurView.layer.cornerRadius = 36
        blurView.layer.cornerCurve = .continuous
        blurView.clipsToBounds = true
        blurView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        blurView.layer.insertSublayer(highlightLayer, at: 0)

        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }

        [cutoutButton, pixellateButton, threeDButton, glitchButton].forEach { button in
            button.addTarget(self, action: #selector(handleButtonTap(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        highlightLayer.frame = blurView.bounds
        highlightLayer.cornerRadius = blurView.layer.cornerRadius
    }

    func update(with state: CollageToolbarState) {
        isHidden = !state.isVisible
        cutoutButton.isToggled = state.isCutoutActive
        pixellateButton.isToggled = state.shaderStates[.pixellate] ?? false
        threeDButton.isToggled = state.shaderStates[.threeDGlasses] ?? false
        glitchButton.isToggled = state.shaderStates[.glitch] ?? false
    }

    @objc private func handleButtonTap(_ sender: FloatingToggleButton) {
        switch sender {
        case cutoutButton:
            onCutoutToggle?()
        case pixellateButton:
            onShaderToggle?(.pixellate)
        case threeDButton:
            onShaderToggle?(.threeDGlasses)
        case glitchButton:
            onShaderToggle?(.glitch)
        default:
            break
        }
    }
}

final class FloatingToggleButton: UIButton {

    var isToggled: Bool = false {
        didSet { updateAppearance() }
    }

    init(symbolName: String) {
        super.init(frame: .zero)
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: symbolName)
        configuration.baseForegroundColor = .label
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        self.configuration = configuration
        layer.cornerRadius = 26
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        backgroundColor = UIColor.white.withAlphaComponent(0.18)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 52).isActive = true
        widthAnchor.constraint(equalToConstant: 52).isActive = true
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateAppearance() {
        if isToggled {
            backgroundColor = UIColor.systemBlue.withAlphaComponent(0.85)
            layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.95).cgColor
            configuration?.baseForegroundColor = .white
        } else {
            backgroundColor = UIColor.white.withAlphaComponent(0.18)
            layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
            configuration?.baseForegroundColor = .label
        }
    }
}

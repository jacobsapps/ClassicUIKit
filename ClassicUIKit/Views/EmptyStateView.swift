import UIKit
import SnapKit

final class EmptyStateView: UIView {

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .title3)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    init(message: String) {
        super.init(frame: .zero)
        addSubview(messageLabel)
        messageLabel.text = message
        messageLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(24)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

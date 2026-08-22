import UIKit

/// Base Poker Alert View (Single Button Style)
public class PokerAlertView: PokerView, PokerTitleRepresentable, PokerConfirmRepresentable {
    
    /// Title label for an alertView
    public var titleLabel: UILabel = PKLabel(fontSize: 18)
    /// Detail label for an alertView
    public var detailLabel: UILabel?
    /// Confirm button for an alertView
    public var confirmButton: UIButton = PKButton(title: "OK", fontSize: 16)
    
    // Horizontal separator line
    private let horizontalSeparator = UIView()
    
    public convenience init(title: String, detail: String? = nil) {
        self.init()
        
        // Background and Style Settings
        self.backgroundColor = UIColor(red: 40/255, green: 40/255, blue: 40/255, alpha: 0.95)
        self.layer.cornerRadius = 14
        self.clipsToBounds = true
        
        // Setup Title
        titleLabel = setupTitleLabel(for: self, with: title)
        titleLabel.textColor = .white
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        
        // Setup Detail
        setupDetail(with: detail)
        
        // Width Anchor
        widthAnchor.constraint(equalToConstant: baseWidth).isActive = true
        
        // Setup Single Button Layout
        setupButtonsLayout()
    }

    private func setupDetail(with detail: String?) {
        guard let detail = detail, !detail.isEmpty else { return }
        
        let label = PKLabel(fontSize: 15)
        label.text = detail
        label.textColor = UIColor(white: 0.85, alpha: 1.0)
        label.textAlignment = .center
        label.numberOfLines = 0
        addSubview(label)
        detailLabel = label
        
        label.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8).isActive = true
        label.constraint(withLeadingTrailing: 16)
    }
    
    private func setupButtonsLayout() {
        // Separator visual setup
        let separatorColor = UIColor(white: 1.0, alpha: 0.15)
        horizontalSeparator.backgroundColor = separatorColor
        horizontalSeparator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(horizontalSeparator)
        
        let topAnchorView = detailLabel ?? titleLabel
        horizontalSeparator.topAnchor.constraint(equalTo: topAnchorView.bottomAnchor, constant: 20).isActive = true
        horizontalSeparator.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        horizontalSeparator.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        horizontalSeparator.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        
        // Single Confirm Button Setup
        confirmButton.setTitle("ตกลง", for: .normal)
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        confirmButton.layer.cornerRadius = 0
        confirmButton.backgroundColor = .clear
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(confirmButton)
        
        // AutoLayout Constraints for Single Bottom Button
        NSLayoutConstraint.activate([
            confirmButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            confirmButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            confirmButton.topAnchor.constraint(equalTo: horizontalSeparator.bottomAnchor),
            confirmButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            confirmButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }
}

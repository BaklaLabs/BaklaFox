//
//  AppAppearanceOptionControl.swift
//  Reynard
//
//  Created by Minh Ton on 22/6/26.
//

import UIKit

final class AppAppearanceOptionControl: UIControl {
    private enum UX {
        static let topInset: CGFloat = 8
        static let optionHorizontalInset: CGFloat = 5
        static let previewHeight: CGFloat = 74
        static let previewCornerRadius: CGFloat = 14
        static let previewBorderWidth: CGFloat = 1
        static let previewSymbolSize: CGFloat = 25
        static let labelTopSpacing: CGFloat = 10
        static let labelFontSize: CGFloat = 13
        static let labelHorizontalInset: CGFloat = 4
        static let bottomInset: CGFloat = 10
    }
    
    let appearance: AppAppearance
    
    private let previewView = UIView()
    private let previewImageView = UIImageView()
    private let nameLabel = UILabel()
    
    init(appearance: AppAppearance, symbolName: String, title: String) {
        self.appearance = appearance
        super.init(frame: .zero)
        configureAccessibility(title: title)
        configurePreview()
        configurePreviewImage(symbolName: symbolName)
        configureNameLabel(title: title)
        installViews()
        activateConstraints()
        displaySelection(selected: false)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else {
            return
        }
        
        displaySelection(selected: isSelected)
    }
    
    func displaySelection(selected: Bool) {
        isSelected = selected
        if selected {
            previewView.backgroundColor = traitCollection.userInterfaceStyle == .dark ? .systemGray5 : .systemBackground
        } else {
            previewView.backgroundColor = .clear
        }
        previewView.layer.borderColor = selected ? UIColor.clear.cgColor : UIColor.systemGray5.cgColor
        previewImageView.tintColor = selected ? .label : .secondaryLabel
        nameLabel.textColor = selected ? .label : .secondaryLabel
    }
    
    func animateTap() {
        if #available(iOS 17.0, *) {
            previewImageView.addSymbolEffect(.bounce)
        }
    }
    
    private func configureAccessibility(title: String) {
        isAccessibilityElement = true
        accessibilityLabel = title
        accessibilityTraits = [.button]
    }
    
    private func configurePreview() {
        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewView.isUserInteractionEnabled = false
        previewView.layer.cornerRadius = UX.previewCornerRadius
        previewView.layer.cornerCurve = .continuous
        previewView.layer.borderWidth = UX.previewBorderWidth
    }
    
    private func configurePreviewImage(symbolName: String) {
        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        previewImageView.isUserInteractionEnabled = false
        previewImageView.contentMode = .scaleAspectFit
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: UX.previewSymbolSize, weight: .regular)
        previewImageView.image = UIImage(named: symbolName)?.applyingSymbolConfiguration(symbolConfiguration)
    }
    
    private func configureNameLabel(title: String) {
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.isUserInteractionEnabled = false
        nameLabel.font = UIFont.systemFont(ofSize: UX.labelFontSize, weight: .regular)
        nameLabel.textAlignment = .center
        nameLabel.text = title
    }
    
    private func installViews() {
        addSubview(previewView)
        previewView.addSubview(previewImageView)
        addSubview(nameLabel)
    }
    
    private func activateConstraints() {
        NSLayoutConstraint.activate([
            previewView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: UX.optionHorizontalInset),
            previewView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -UX.optionHorizontalInset),
            previewView.topAnchor.constraint(equalTo: topAnchor, constant: UX.topInset),
            previewView.heightAnchor.constraint(equalToConstant: UX.previewHeight),
            
            previewImageView.centerXAnchor.constraint(equalTo: previewView.centerXAnchor),
            previewImageView.centerYAnchor.constraint(equalTo: previewView.centerYAnchor),
            
            nameLabel.topAnchor.constraint(equalTo: previewView.bottomAnchor, constant: UX.labelTopSpacing),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: UX.labelHorizontalInset),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -UX.labelHorizontalInset),
            nameLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -UX.bottomInset),
        ])
    }
}

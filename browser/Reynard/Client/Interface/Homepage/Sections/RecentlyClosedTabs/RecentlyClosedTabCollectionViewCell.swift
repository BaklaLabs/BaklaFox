//
//  RecentlyClosedTabCollectionViewCell.swift
//  Reynard
//
//  Created by Minh Ton on 25/6/26.
//

import UIKit

final class RecentlyClosedTabCollectionViewCell: UICollectionViewCell {
    private enum UX {
        static let horizontalInset: CGFloat = 16
        static let titleFontSize: CGFloat = 15
        static let pillCornerRadius: CGFloat = 22
        static let shadowOpacity: Float = 0.12
        static let shadowRadius: CGFloat = 5
        static let shadowOffsetWidth: CGFloat = 0
        static let shadowOffsetHeight: CGFloat = 2
    }
    
    static let reuseIdentifier = "RecentlyClosedTabCollectionViewCell"
    
    private static let titleFont = UIFontMetrics(forTextStyle: .subheadline).scaledFont(
        for: .systemFont(ofSize: UX.titleFontSize, weight: .regular)
    )
    
    private let pillView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.backgroundColor = .systemGray5
        view.layer.cornerCurve = .continuous
        view.layer.cornerRadius = UX.pillCornerRadius
        view.clipsToBounds = true
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = RecentlyClosedTabCollectionViewCell.titleFont
        label.textColor = .label
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updatePillShape()
        updatePillShadow()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else {
            return
        }
        
        updateAppearance()
    }
    
    func configure(tab: TabManagementStore.RecentlyClosedTabSnapshot) {
        let title = tab.title.trimmingCharacters(in: .whitespacesAndNewlines)
        titleLabel.text = title.isEmpty ? "Untitled" : title
    }
    
    // MARK: - Configuration
    
    private func configureCell() {
        configureAppearance()
        configureHierarchy()
        configureConstraints()
    }
    
    private func configureAppearance() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        clipsToBounds = false
        contentView.clipsToBounds = false
        layer.cornerCurve = .continuous
        layer.cornerRadius = UX.pillCornerRadius
        layer.shadowOpacity = UX.shadowOpacity
        layer.shadowRadius = UX.shadowRadius
        layer.shadowOffset = CGSize(width: UX.shadowOffsetWidth, height: UX.shadowOffsetHeight)
        updateAppearance()
    }
    
    private func configureHierarchy() {
        contentView.addSubview(pillView)
        pillView.addSubview(titleLabel)
    }
    
    private func configureConstraints() {
        NSLayoutConstraint.activate([
            pillView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            pillView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            pillView.topAnchor.constraint(equalTo: contentView.topAnchor),
            pillView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            titleLabel.leadingAnchor.constraint(equalTo: pillView.leadingAnchor, constant: UX.horizontalInset),
            titleLabel.trailingAnchor.constraint(equalTo: pillView.trailingAnchor, constant: -UX.horizontalInset),
            titleLabel.centerYAnchor.constraint(equalTo: pillView.centerYAnchor),
        ])
    }
    
    // MARK: - Layout
    
    private func updatePillShape() {
        let cornerRadius = pillView.bounds.height > 0 ? pillView.bounds.height / 2 : UX.pillCornerRadius
        pillView.layer.cornerRadius = cornerRadius
        layer.cornerRadius = cornerRadius
    }
    
    private func updatePillShadow() {
        let cornerRadius = bounds.height > 0 ? bounds.height / 2 : UX.pillCornerRadius
        layer.shadowPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: cornerRadius
        ).cgPath
    }
    
    // MARK: - Appearance
    
    private func updateAppearance() {
        pillView.backgroundColor = traitCollection.userInterfaceStyle == .dark
        ? .systemGray5
        : .systemBackground
        titleLabel.textColor = .label
        layer.shadowColor = traitCollection.userInterfaceStyle == .dark
        ? UIColor.white.cgColor
        : UIColor.black.cgColor
    }
}

//
//  CustomNewTabURLCell.swift
//  Reynard
//
//  Created by Minh Ton on 22/6/26.
//

import UIKit

final class CustomNewTabURLCell: UITableViewCell {
    private enum UX {
        static let horizontalSpacing: CGFloat = 16
    }
    
    let textField = UITextField()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureTextField()
        configureHierarchy()
        configureConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configureTextField() {
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.clearButtonMode = .whileEditing
        textField.keyboardType = .URL
        textField.returnKeyType = .done
    }
    
    private func configureHierarchy() {
        textField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textField)
    }
    
    private func configureConstraints() {
        NSLayoutConstraint.activate([
            textField.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            textField.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor, constant: -UX.horizontalSpacing),
            textField.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
        ])
    }
}

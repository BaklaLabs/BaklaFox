//
//  FavoriteSiteIconView.swift
//  Reynard
//
//  Created by Minh Ton on 22/6/26.
//

import UIKit

final class FavoriteSiteIconView: UIView {
    private let imageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        view.tintColor = .secondaryLabel
        return view
    }()
    
    private lazy var faviconLoader = HomepageFaviconLoader { [weak self] image, tintColor in
        self?.applyIcon(image, tintColor: tintColor)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(bookmark: BookmarkSnapshot) {
        faviconLoader.loadIcon(for: bookmark.url)
    }
    
    func reset() {
        faviconLoader.reset()
    }
    
    private func configureView() {
        backgroundColor = .clear
        addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        
        faviconLoader.reset()
    }
    
    private func applyIcon(_ image: UIImage?, tintColor: UIColor?) {
        imageView.image = image
        imageView.tintColor = tintColor
    }
}

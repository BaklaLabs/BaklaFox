//
//  HomepageFaviconLoader.swift
//  Reynard
//
//  Created by Minh Ton on 24/6/26.
//

import UIKit

final class HomepageFaviconLoader {
    private static let faviconStore = FaviconStore.shared
    private static let fallbackIconName = "reynard.globe"
    
    private let updateIcon: (UIImage?, UIColor?) -> Void
    private var representedURL: URL?
    private var loadTask: Task<Void, Never>?
    
    init(_ updateIcon: @escaping (UIImage?, UIColor?) -> Void) {
        self.updateIcon = updateIcon
    }
    
    deinit {
        loadTask?.cancel()
    }
    
    func loadIcon(for url: URL) {
        representedURL = url
        loadTask?.cancel()
        loadTask = nil
        
        if let bundledImage = UIImage(named: Self.bundledIconName(for: url)) {
            updateIcon(bundledImage, nil)
            return
        }
        
        if let cachedImage = Self.faviconStore.cachedFavicon(for: url) {
            updateIcon(cachedImage, nil)
            return
        }
        
        applyFallbackIcon()
        let loadingURL = url
        loadTask = Task { [weak self] in
            guard let self else {
                return
            }
            
            let loadedImage = await Self.faviconStore.favicon(for: loadingURL)
            guard !Task.isCancelled else {
                return
            }
            
            await MainActor.run {
                guard self.representedURL == loadingURL else {
                    return
                }
                
                self.updateIcon(
                    loadedImage ?? UIImage(named: Self.fallbackIconName),
                    loadedImage == nil ? .secondaryLabel : nil
                )
            }
        }
    }
    
    func reset() {
        representedURL = nil
        loadTask?.cancel()
        loadTask = nil
        applyFallbackIcon()
    }
    
    private func applyFallbackIcon() {
        updateIcon(UIImage(named: Self.fallbackIconName), .secondaryLabel)
    }
    
    private static func bundledIconName(for url: URL) -> String {
        var iconName = url.absoluteString
        
        if let schemeRange = iconName.range(of: "://") {
            iconName.removeSubrange(iconName.startIndex..<schemeRange.upperBound)
        }
        
        if iconName.hasPrefix("www.") {
            iconName.removeFirst(4)
        }
        
        while iconName.hasSuffix("/") {
            iconName.removeLast()
        }
        
        return iconName
    }
}

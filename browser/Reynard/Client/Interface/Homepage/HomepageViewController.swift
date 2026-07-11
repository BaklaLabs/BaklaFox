//
//  HomepageViewController.swift
//  Reynard
//
//  Created by Minh Ton on 21/6/26.
//

import UIKit

protocol HomepageViewControllerDelegate: AnyObject {
    func homepageViewController(_ controller: HomepageViewController, didRequestOpenURL url: URL, disposition: TabOpenDisposition)
    func homepageViewController(_ controller: HomepageViewController, didRequestShareURL url: URL)
    func homepageViewController(_ controller: HomepageViewController, didRequestHideFromSuggestions siteID: Int64)
    func homepageViewController(_ controller: HomepageViewController, didSelectRecentlyClosedTab id: UUID)
    func homepageViewControllerDidSelectSettings(_ controller: HomepageViewController)
    func homepageViewControllerDidStartScrolling()
}

final class HomepageViewController: UINavigationController {
    weak var homepageDelegate: HomepageViewControllerDelegate?
    
    private let rootViewController: HomepageRootViewController
    private let bookmarkStore: BookmarkStore
    private var isPrivateBrowsing: Bool
    private var contentMode: HomepageContentMode = .embeddedNarrow
    private var showsBackground = false
    
    // MARK: - Lifecycle
    
    init(bookmarkStore: BookmarkStore = .shared, isPrivateBrowsing: Bool = false) {
        self.bookmarkStore = bookmarkStore
        self.isPrivateBrowsing = isPrivateBrowsing
        rootViewController = HomepageRootViewController(
            bookmarkStore: bookmarkStore,
            isPrivateBrowsing: isPrivateBrowsing
        )
        super.init(rootViewController: rootViewController)
        rootViewController.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureAppearance()
    }
    
    override func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
        super.setViewControllers(viewControllers, animated: animated)
        viewControllers.forEach { viewController in
            (viewController as? HomepageRootViewController)?.delegate = self
        }
    }
    
    // MARK: - Public API
    
    func setContentMode(_ contentMode: HomepageContentMode) {
        self.contentMode = contentMode
        viewControllers.forEach { viewController in
            (viewController as? HomepageRootViewController)?.setContentMode(contentMode)
        }
    }
    
    func setShowsBackground(_ showsBackground: Bool) {
        self.showsBackground = showsBackground
        updateBackgroundColor()
    }
    
    func setPrivateBrowsing(_ isPrivateBrowsing: Bool) {
        guard self.isPrivateBrowsing != isPrivateBrowsing else {
            return
        }
        
        self.isPrivateBrowsing = isPrivateBrowsing
        viewControllers.forEach { viewController in
            (viewController as? HomepageRootViewController)?.setPrivateBrowsing(isPrivateBrowsing)
        }
    }
    
    func prepareForPresentation(resetNavigation: Bool) {
        loadViewIfNeeded()
        if resetNavigation {
            popToRootViewController(animated: false)
        }
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
    
    // MARK: - Configuration
    
    private func configureAppearance() {
        updateBackgroundColor()
        delegate = self
        navigationBar.isTranslucent = false
        setNavigationBarHidden(true, animated: false)
    }
    
    private func updateBackgroundColor() {
        view.backgroundColor = showsBackground ? .systemBackground : .clear
    }
}

extension HomepageViewController: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        setNavigationBarHidden(viewController === rootViewController, animated: false)
    }
}

extension HomepageViewController: HomepageRootViewControllerDelegate {
    func homepageRootViewController(_ controller: HomepageRootViewController, didRequestOpenURL url: URL, disposition: TabOpenDisposition) {
        homepageDelegate?.homepageViewController(self, didRequestOpenURL: url, disposition: disposition)
    }
    
    func homepageRootViewController(_ controller: HomepageRootViewController, didRequestShareURL url: URL) {
        homepageDelegate?.homepageViewController(self, didRequestShareURL: url)
    }
    
    func homepageRootViewController(_ controller: HomepageRootViewController, didRequestHideFromSuggestions siteID: Int64) {
        homepageDelegate?.homepageViewController(self, didRequestHideFromSuggestions: siteID)
    }
    
    func homepageRootViewController(_ controller: HomepageRootViewController, didSelectRecentlyClosedTab id: UUID) {
        homepageDelegate?.homepageViewController(self, didSelectRecentlyClosedTab: id)
    }
    
    func homepageRootViewControllerDidSelectSettings(_ controller: HomepageRootViewController) {
        homepageDelegate?.homepageViewControllerDidSelectSettings(self)
    }
    
    func homepageRootViewControllerDidSelectFolder(_ folder: BookmarkFolderSnapshot) {
        let viewController = HomepageRootViewController(
            bookmarkStore: bookmarkStore,
            folder: folder,
            sections: [.favorites],
            isPrivateBrowsing: isPrivateBrowsing
        )
        viewController.delegate = self
        viewController.setContentMode(contentMode)
        setNavigationBarHidden(false, animated: false)
        pushViewController(viewController, animated: true)
    }
    
    func homepageRootViewControllerDidStartScrolling() {
        homepageDelegate?.homepageViewControllerDidStartScrolling()
    }
}

//
//  TabOverviewCollectionLayout.swift
//  Reynard
//
//  Created by Minh Ton on 10/6/26.
//

import UIKit

final class TabOverviewCollectionLayout: UICollectionViewFlowLayout {
    private enum UX {
        static let insertedTabCardInitialScale: CGFloat = 0.85
    }
    
    private var insertedCardIndexPaths = Set<IndexPath>()
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let collectionView else {
            return super.shouldInvalidateLayout(forBoundsChange: newBounds)
        }
        
        return collectionView.bounds.size != newBounds.size
        || super.shouldInvalidateLayout(forBoundsChange: newBounds)
    }
    
    override func invalidationContext(forBoundsChange newBounds: CGRect) -> UICollectionViewLayoutInvalidationContext {
        let context = super.invalidationContext(forBoundsChange: newBounds)
        guard let flowContext = context as? UICollectionViewFlowLayoutInvalidationContext,
              let collectionView else {
            return context
        }
        
        flowContext.invalidateFlowLayoutDelegateMetrics = collectionView.bounds.size != newBounds.size
        return flowContext
    }
    
    override func prepare(forCollectionViewUpdates updateItems: [UICollectionViewUpdateItem]) {
        super.prepare(forCollectionViewUpdates: updateItems)
        insertedCardIndexPaths = Set(updateItems.compactMap { updateItem in
            updateItem.updateAction == .insert ? updateItem.indexPathAfterUpdate : nil
        })
    }
    
    override func initialLayoutAttributesForAppearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let attributes = super.initialLayoutAttributesForAppearingItem(at: itemIndexPath)?.copy() as? UICollectionViewLayoutAttributes
        ?? layoutAttributesForItem(at: itemIndexPath)?.copy() as? UICollectionViewLayoutAttributes
        if insertedCardIndexPaths.contains(itemIndexPath) {
            attributes?.alpha = 0
            attributes?.transform = CGAffineTransform(
                scaleX: UX.insertedTabCardInitialScale,
                y: UX.insertedTabCardInitialScale
            )
        }
        return attributes
    }
    
    override func finalizeCollectionViewUpdates() {
        super.finalizeCollectionViewUpdates()
        insertedCardIndexPaths.removeAll()
    }
}

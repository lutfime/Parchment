import UIKit
import SwiftUI

@available(iOS 14.0, *)
struct PagingControllerRepresentableView: UIViewControllerRepresentable {
    let items: [PagingItem]
    let content: ((PagingItem) -> UIViewController)?
    let options: PagingOptions
    var onWillScroll: ((PagingItem) -> Void)?
    var onDidScroll: ((PagingItem) -> Void)?
    var onDidSelect: ((PagingItem) -> Void)?

    @Binding var selectedIndex: Int

    func makeCoordinator() -> PageViewCoordinator {
        PageViewCoordinator(self)
    }

    func makeUIViewController(
        context: UIViewControllerRepresentableContext<PagingControllerRepresentableView>
    ) -> PagingViewController {
        let pagingViewController = PagingViewController(options: options)
        pagingViewController.dataSource = context.coordinator
        pagingViewController.delegate = context.coordinator
        pagingViewController.indicatorClass = PagingHostingIndicatorView.self
        pagingViewController.collectionView.clipsToBounds = false

        if let items = items as? [PageItem] {
            for item in items {
                pagingViewController.collectionView.register(
                    PageItemCell.self,
                    forCellWithReuseIdentifier: item.page.reuseIdentifier
                )
            }
        }

        return pagingViewController
    }

    func updateUIViewController(
        _ pagingViewController: PagingViewController,
        context: UIViewControllerRepresentableContext<PagingControllerRepresentableView>
    ) {
        // Capture OLD identifiers before we update the coordinator's parent
        var oldIdentifiers: Set<Int> = []
        for old in context.coordinator.parent.items {
            if let pageItem = old as? PageItem { oldIdentifiers.insert(pageItem.identifier) }
        }

        // Build a lookup for the UPDATED items (after SwiftUI state change)
        var newItemsById: [Int: PagingItem] = [:]
        var newIdentifiers: Set<Int> = []
        for newItem in items {
            if let pageItem = newItem as? PageItem {
                newItemsById[pageItem.identifier] = pageItem
                newIdentifiers.insert(pageItem.identifier)
            }
        }

        context.coordinator.parent = self
        

        if pagingViewController.dataSource == nil {
            pagingViewController.dataSource = context.coordinator
        }
        
        // Apply updated options. If menuItemSize changes (e.g., when tab count
        // goes from many to few), downstream observers in PagingController will
        // clear size cache and invalidate layout via didSet logic.
        pagingViewController.options = options
        pagingViewController.indicatorClass = PagingHostingIndicatorView.self

        // Ensure collection view registers cells for any new page identifiers
        if let items = items as? [PageItem] {
            for item in items {
                pagingViewController.collectionView.register(
                    PageItemCell.self,
                    forCellWithReuseIdentifier: item.page.reuseIdentifier
                )
            }
        }

        // Keep selection only if the current item still exists in the NEW items.
        // Otherwise, reload around the first available item.
        // If the identifiers changed, clear content to avoid stale flash, but only
        // when there is existing content; avoid wiping initial presentation.
        var didRemoveContent = false
        if oldIdentifiers != newIdentifiers, pagingViewController.state.currentPagingItem != nil {
            
            pagingViewController.removeContent()
            didRemoveContent = true
        }

        if didRemoveContent {
            pagingViewController.reloadData()
        } else if let currentItem = pagingViewController.state.currentPagingItem,
                  let pageItem = currentItem as? PageItem,
                  newItemsById[pageItem.identifier] != nil {
            pagingViewController.reloadMenu()
        } else {
            pagingViewController.reloadData()
        }

        // Refresh currently visible page content if identity is unchanged and we didn't just clear it
        if !didRemoveContent,
           let currentItem = pagingViewController.state.currentPagingItem as? PageItem,
           let viewController = context.coordinator.controllers[currentItem.identifier]?.value {
            
            currentItem.page.update(viewController)
        }

        // HACK: If the user don't pass a selectedIndex binding, the
        // default parameter is set to .constant(Int.max) which allows
        // us to check here if a binding was passed in or not (it
        // doesn't seem possible to make the binding itself optional).
        // This check is needed because we cannot update a .constant
        // value. When the user scroll to another page, the
        // selectedIndex binding will always be the same, so calling
        // `select(index:)` will select the wrong page. This fixes a bug
        // where the wrong page would be selected when rotating.
        guard selectedIndex != Int.max else {
            return
        }

        // Clamp and apply selected index after data reload.
        let count = items.count
        if count > 0 {
            let clamped = max(0, min(selectedIndex, count - 1))
            if didRemoveContent {
                // Force reselect to reattach content even if the index didn't change
                pagingViewController.select(index: clamped, animated: false)
            } else {
                if let current = pagingViewController.state.currentPagingItem as? PageItem,
                   current.index == clamped {
                } else {
                    pagingViewController.select(index: clamped, animated: true)
                }
            }
        } else {
            
        }
    }
}


//
//  FieldGridScrollView.swift
//  CherryBombSweeper
//
//  Created by Duy Nguyen on 1/19/18.
//  Copyright © 2018 Duy.Ninja. All rights reserved.
//

import UIKit

class FieldGridScrollView: UIScrollView {
    fileprivate var fieldGridCollection: FieldGridCollectionView?

    private var minScaleFactor: CGFloat = GameGeneralService.Constant.defaultMinScaleFactor
    
//    private var maxContentOffset: CGFloat = 0
    
    private var cellTapHandler: CellTapHandler?
    
    private var rowCount: Int = 0
    private var columnCount: Int = 0
    private var fieldWidth: CGFloat = 0
    private var fieldHeight: CGFloat = 0
    private var modifiedIndexPaths: Set<IndexPath> = []
    
    lazy private var setUpOnce: Void = {
        self.delegate = self
        
        self.isScrollEnabled = true
        self.showsVerticalScrollIndicator = false
        self.showsHorizontalScrollIndicator = false
        
        let fieldGrid = FieldGridCollectionView(frame: self.frame, collectionViewLayout: FieldGridCollectionViewLayout())
        fieldGrid.layer.borderWidth = GameGeneralService.Constant.fieldBorderWidth
        fieldGrid.layer.borderColor = UIColor.black.cgColor
        self.fieldGridCollection = fieldGrid
        
        fieldGrid.isHidden = true
        
        self.addSubview(fieldGrid)
    }()
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let _ = setUpOnce
    }
    
    func setupFieldGrid(rows: Int, columns: Int,
                        dataSource: UICollectionViewDataSource,
                        cellTapHandler: @escaping CellTapHandler,
                        completionHandler: FieldSetupCompletionHandler?) {
        
        guard let fieldGridCollection = self.fieldGridCollection else { return }
        
        if rows == self.rowCount, columns == self.columnCount {
            // Dimension didn't change, so just reset it
            fieldGridCollection.dataSource = dataSource
            fieldGridCollection.cellTapHandler = cellTapHandler
            
            // Show and reload only what's been affected
            fieldGridCollection.isHidden = false
            fieldGridCollection.reloadItems(at: Array(self.modifiedIndexPaths))
            self.modifiedIndexPaths.removeAll()
            
            completionHandler?(self.fieldWidth, self.fieldHeight)
            
            DispatchQueue.main.async {
                self.setZoomScale(1.0, animated: true)
                if !self.recenterFieldGrid() {
                    self.setContentOffset(CGPoint(x: 0, y: 0), animated: false)
                }
            }
            return
        }
        
        self.rowCount = rows
        self.columnCount = columns
        self.modifiedIndexPaths.removeAll()
        
        fieldGridCollection.setupFieldGrid(rows: rows, columns: columns, dataSource: dataSource, cellTapHandler: cellTapHandler) { [weak self] (fieldWidth, fieldHeight) in
            guard let `self` = self else { return }
            
            self.fieldWidth = fieldWidth
            self.fieldHeight = fieldHeight
            
            let windowWidth = self.frame.width
            let windowHeight = self.frame.height
    
            // Figure out which dimension is wider than screen when normalized, that dimension would determine the mininum scale factor
            // to fit the entire field into the container
            let screenAspect = windowWidth / windowHeight
            let fieldAspect = fieldWidth / fieldHeight
            
            self.minScaleFactor = (fieldAspect > screenAspect) ? windowWidth / fieldWidth : windowHeight / fieldHeight
            
            self.minimumZoomScale = self.minScaleFactor
            self.maximumZoomScale = GameGeneralService.Constant.defaultMaxScaleFactor
            self.contentSize = CGSize(width: fieldWidth, height: fieldHeight)

            // Show and reload
            fieldGridCollection.isHidden = false
            fieldGridCollection.reloadData()
            
            DispatchQueue.main.async {
                self.setZoomScale(1.0, animated: true)
                if !self.recenterFieldGrid() {
                    self.setContentOffset(CGPoint(x: 0, y: 0), animated: false)
                }
                completionHandler?(fieldWidth, fieldHeight)
            }
        }
    }
    
    func showEntireField() {
        self.setZoomScale(self.minScaleFactor, animated: true)
    }
    
    func updateCells(at indexPaths: [IndexPath]) {
        guard let fieldGridCollection = self.fieldGridCollection else { return }
        // keep track of which cell has been affected
        self.modifiedIndexPaths = self.modifiedIndexPaths.union(indexPaths)
        DispatchQueue.main.async {
            fieldGridCollection.reloadItems(at: indexPaths)
        }
    }
    
    func recenterFieldGrid() -> Bool {
        let fieldWidth = self.contentSize.width
        let fieldHeight = self.contentSize.height
        
        let windowWidth = self.frame.width
        let windowHeight = self.frame.height
        
        if fieldWidth > windowWidth, fieldHeight > windowHeight { return false }
        
        var xOffset: CGFloat = self.contentOffset.x
        var yOffset: CGFloat = self.contentOffset.y
        
        if fieldWidth < windowWidth {
            xOffset = (fieldWidth - windowWidth) / 2
        }
        
        if fieldHeight < windowHeight {
            yOffset = (fieldHeight - windowHeight) / 2
        }
        
        self.setContentOffset(CGPoint(x: xOffset, y: yOffset), animated: true)
        
        return true
    }
}

extension FieldGridScrollView: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.fieldGridCollection
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        let _ = self.recenterFieldGrid()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard !decelerate else { return }
        
        let _ = self.recenterFieldGrid()
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let _ = self.recenterFieldGrid()
    }
}

extension FieldGridScrollView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}


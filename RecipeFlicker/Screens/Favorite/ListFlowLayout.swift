//
//  ListFlowLayout.swift
//  RecipeFlicker
//
//  Created by minami on 2018-10-30.
//  Copyright © 2018 Kenta Kodashima. All rights reserved.
//

import UIKit

class ListFlowLayout: UICollectionViewFlowLayout {
  
  let itemHeight: CGFloat = 80

  func itemWidth() -> CGFloat {
    return collectionView!.frame.width
  }
  
  override var itemSize: CGSize {
    set {
      self.itemSize = CGSize(width: itemWidth(), height:itemHeight)
    }
    get {
      return CGSize(width: itemWidth(), height: itemHeight)
    }
  }
  
  override init() {
    super.init()
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    setupLayout()
  }
  
  func setupLayout() {
    minimumLineSpacing = 0
    minimumLineSpacing = 1
    scrollDirection = .vertical
  }
  
  override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
    return collectionView!.contentOffset
  }
}

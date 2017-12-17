//
//  PhotoCollectionViewCell.swift
//  VirtualTourist
//
//  Created by Mauricio Cabreira on 15/12/17.
//  Copyright © 2017 Mauricio Cabreira. All rights reserved.
//

import UIKit

class PhotoCollectionViewCell: UICollectionViewCell {
  
  // MARK: Outlets
  
  @IBOutlet weak var collectionCellImageView: UIImageView!
  
  @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
  
  // Change alpha of selected cells to show selected images
    override var isSelected: Bool {
    didSet {
      collectionCellImageView.alpha = isSelected ? 0.3 : 1.0
    }
  }
}


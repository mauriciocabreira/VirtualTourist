//
//  PhotoViewController.swift
//  VirtualTourist
//
//  Created by Mauricio Cabreira on 15/12/17.
//  Copyright © 2017 Mauricio Cabreira. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class PhotoViewController: UIViewController, MKMapViewDelegate, UICollectionViewDelegate, UICollectionViewDataSource, NSFetchedResultsControllerDelegate {
  
  
  // MARK: Photo Fetched Results Controller (executed during viewDidLoad())
  lazy var photoFetchedResultsController: NSFetchedResultsController<Photo> = { () -> NSFetchedResultsController<Photo> in
    
    let photoFetchRequest = NSFetchRequest<Photo>(entityName: "Photo")
    photoFetchRequest.sortDescriptors = []
    
    if let pin = selectedPin {
      let predicate = NSPredicate(format: "pin == %@", pin)
      photoFetchRequest.predicate = predicate
    }
    
    let photoFetchedResultsController = NSFetchedResultsController(fetchRequest: photoFetchRequest, managedObjectContext: self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
    photoFetchedResultsController.delegate = self
    
    return photoFetchedResultsController
  }()
  
  // MARK: Shared managed object context
  
  var sharedContext = CoreDataStack.sharedInstance().context
  
  // MARK: Properties
  
  var selectedPin: Pin?
  
//  Array of selected images in Collection view that can be deleted
  var selectedCellIndexPaths = [IndexPath]()
  
  var insertedCellIndexPaths: [IndexPath]!
  var deletedCellIndexPaths: [IndexPath]!
  
  
  // MARK: IBOutlets
  
  @IBOutlet weak var collectionView: UICollectionView!
  @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
  @IBOutlet weak var pinMapView: MKMapView!
  @IBOutlet weak var newCollectionButton: UIBarButtonItem!
  
  
  //   MARK : Actions
  
  @IBAction func returnToMainScreen(_ sender: Any) {
    let controller = self.navigationController!.viewControllers[0]
    let _ = self.navigationController?.popToViewController(controller, animated: true)
  }
  
  @IBAction func getNewCollectionOrdeleteSelectedPhotos(_ sender: Any) {
    
    if isBottomButtonWithDeleteText() {
      deleteSelectedPhotos()
    } else {
      getNewCollection()
    }
  }
  
  
  // MARK: Life Cycle
  
  // MARK: viewDidLoad() with VC initializations
  override func viewDidLoad() {
    super.viewDidLoad()
    setLayout()
    
    displayPinInMapView(pin: selectedPin!)
    
    // Enable collection view to select multiple items
    collectionView.allowsMultipleSelection = true
    
    // Fetch the pin's photos from core data.
    performPhotoFetchRequest(photoFetchedResultsController)
    
    // Fetch photos from flicker if none stored. Then save it under Pin CD
    if photoFetchedResultsController.fetchedObjects?.count == 0 {
      FlickrClient.sharedInstance().getAndStoreFlickrPhotoURLsForPin(selectedPin!)
    }
  }
  
  // MARK: Generic functions
  
  // MARK: Returns bottom button status
  func isBottomButtonWithDeleteText() -> Bool {
    if newCollectionButton.title == "New Collection" {
      return false
    } else {
      return true
    }
  }
  
  // MARK: Get new set of photos and delete current ones
  func getNewCollection() {
  
    // 1st: Clear the photos stored in the data structure.
    if let storedPhotos = photoFetchedResultsController.fetchedObjects {
      for photo in storedPhotos {
        sharedContext.delete(photo)
      }
      // Update CD on background
      performUIUpdatesOnMain {
        CoreDataStack.sharedInstance().save()
      }
    }
    
    //  2nd: now get a new set of photos
    FlickrClient.sharedInstance().getAndStoreFlickrPhotoURLsForPin(self.selectedPin!)
  }
  
  
  // MARK: Delete selected photos from CD.
  func deleteSelectedPhotos() {
    for indexPath in selectedCellIndexPaths {
      if let photos = photoFetchedResultsController.fetchedObjects {
        sharedContext.delete(photos[(indexPath as NSIndexPath).item])
        performUIUpdatesOnMain {
          CoreDataStack.sharedInstance().save()
        }
      }
    }
    
    // Reset array since no images are more selected (have been deleted)
    selectedCellIndexPaths.removeAll()
    
    updateBottomButtonTitle()
  }
  
  // MARK: Display pin in map
  func displayPinInMapView(pin: Pin) {
    
    let pinAnnotation = MKPointAnnotation()
    
    pinAnnotation.coordinate.latitude = pin.latitude
    pinAnnotation.coordinate.longitude = pin.longitude
    pinMapView.addAnnotation(pinAnnotation)
    pinMapView.camera.altitude = 750.0
    pinMapView.centerCoordinate = pinAnnotation.coordinate
    
  }
  
  // MARK: Perform photo fetch request
  func performPhotoFetchRequest(_ photoFetchedResultsController: NSFetchedResultsController<Photo>?) {
    if let photoFetchedResultsController = photoFetchedResultsController {
      do {
        try photoFetchedResultsController.performFetch()
      } catch let error as NSError {
        print("Error while fetching photos : \(error)")
      }
    }
  }
}

// MARK: UICollectionViewDelegate

extension PhotoViewController {
  
  // MARK: Sets images layout in ColletionVC
  func setLayout() {
    
    let space:CGFloat = 2.0
    
    let wDimension = (view.frame.size.width - (2 * space)) / 3.0
    //let hDimension = ((view.frame.size.width - (2 * space)) / 3.0)
    
    flowLayout.minimumInteritemSpacing = space
    flowLayout.minimumLineSpacing = space
    flowLayout.itemSize = CGSize(width: wDimension, height: 100)
    
  }
  
  // MARK: Return number of photos that will be shown in the Collection VC
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    
    return photoFetchedResultsController.fetchedObjects!.count
  }
  
  // MARK: Display cells
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    
    // The cell to be dequeued
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCollectionViewCell", for: indexPath) as! PhotoCollectionViewCell
    
    // Display the placeholder image in the cell, unitl photo is downloaded/retrieved
    cell.collectionCellImageView?.image = UIImage(named: "photo-placeholder")
    
    cell.activityIndicator.startAnimating()
    
    // Display photos that were previously stored in CD
    if let fetchedPhotos = photoFetchedResultsController.fetchedObjects, fetchedPhotos.count > 0 {
      
      // The Photo stored in core data that corresponds to this particular cell
      let storedPhotoForCell = fetchedPhotos[(indexPath as NSIndexPath).item]
      
      // If stored image data is present for the cell's Photo, then convert to a
      // UIImage and display within cell's imageview.
      if let storedImageDataForPhoto = storedPhotoForCell.image {
        
        cell.collectionCellImageView?.image = UIImage(data: storedImageDataForPhoto as Data)
        cell.activityIndicator.hidesWhenStopped = true
        cell.activityIndicator.stopAnimating()
        
      } else {
        
        // No photo has been store in CD. Download it from flicker with stored URL
        if storedPhotoForCell.url != nil {
          
          // Download the phothe data and store in CD
          FlickrClient.sharedInstance().downloadAndStoreFlickrPhoto(storedPhotoForCell) { (success, errorString) in
            if success {
              // If image data download and storage successful, retrieve the latest
              // photos data for the pin.
              self.performPhotoFetchRequest(self.photoFetchedResultsController)
              // Then reload the Collection VC to display new data.
              performUIUpdatesOnMain {
                self.collectionView.reloadData()
              }
            }
            else {
              print(errorString!)
            }
          }
        }
      }
    }
    return cell
  }
  
  // MARK: Selecting one or more photos
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    
    // Store in array the selected photo.
    selectedCellIndexPaths.append(indexPath)
    updateBottomButtonTitle()
  }
  
  // MARK: Deselecting photos
  func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
    
    if let pathToRemove = selectedCellIndexPaths.index(of: indexPath) {
      selectedCellIndexPaths.remove(at: pathToRemove)
    }
    updateBottomButtonTitle()
  }
  
  // MARK: Bottom button treatment
  func updateBottomButtonTitle() {
    if selectedCellIndexPaths.count > 0 {
      newCollectionButton.title = "Remove Selected Photos"
    } else {
      newCollectionButton.title = "New Collection"
    }
  }
}

// MARK: Fetched Results Controller Delegate. Methods are invoked when CD is changed.

extension PhotoViewController {
  
  //   MARK: Creates two fresh arrays to record the index paths that will be changed.
  func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    
    // Reset arrays that tracks cells.
    insertedCellIndexPaths = [IndexPath]()
    deletedCellIndexPaths = [IndexPath]()
  }
  
  // MARK: Keep track of everytime a Photo object is added or deleted.
  func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
    
    switch type {
      
    case .insert:
      // Tracking when a new Photo object has been added to core data.
      insertedCellIndexPaths.append(newIndexPath!)
      break
    case .delete:
      // Tracking when a Photo object has been deleted from Core Data.
      deletedCellIndexPaths.append(indexPath!)
      break
    default:
      break
    }
  }
  
  //   MARK: Invoked when contents have changed
  func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    
    collectionView.performBatchUpdates({() -> Void in
      for indexPath in self.insertedCellIndexPaths {
        self.collectionView.insertItems(at: [indexPath])
      }
      for indexPath in self.deletedCellIndexPaths {
        self.collectionView.deleteItems(at: [indexPath])
      }
    }, completion: nil)
  }
}

// MARK: MKMapViewDelegate

extension PhotoViewController {
  
  // MARK: Define the style of the pins that appear on the map.
  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    
    let reuseId = "pin"
    
    var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView
    
    if pinView == nil {
      pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
      pinView!.canShowCallout = true
      pinView!.pinTintColor = .blue
      pinView!.animatesDrop = true
    } else {
      pinView!.annotation = annotation
    }
    
    return pinView
  }

}


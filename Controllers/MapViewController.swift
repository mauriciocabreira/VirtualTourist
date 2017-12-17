//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Mauricio Cabreira on 14/12/17.
//  Copyright © 2017 Mauricio Cabreira. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class MapViewController: UIViewController, MKMapViewDelegate, NSFetchedResultsControllerDelegate{

  
  var sharedContext = CoreDataStack.sharedInstance().context
  
  // MARK: Properties
  
  @IBOutlet weak var mapView: MKMapView!
  
  // MARK: Actions
  
  @IBAction func pinDropped(_ sender: UILongPressGestureRecognizer) {
    
    //    this avoid multiple pins. Creates only when it begins
    if sender.state == .began {
      
      let locationTouched = sender.location(in: mapView)
      let coordinates = mapView.convert(locationTouched, toCoordinateFrom: mapView)
      let newPin = MKPointAnnotation()
      newPin.coordinate = coordinates
      
      //    add pin to map
      mapView.addAnnotation(newPin)
      
      //    add pin to core data
      let pinCD = Pin(context: sharedContext)
      pinCD.latitude = coordinates.latitude
      pinCD.longitude = coordinates.longitude
      CoreDataStack.sharedInstance().save()
    }
  }
  
  // MARK: Life Cycle
  
  override func viewDidLoad() {
    
    super.viewDidLoad()
    checkIfFirstLaunch()
    
    // Fetch saved pins. A: Create a fetchPinRequest B: Then perform the actual PIN retrieval
    if let pinFetchedResultsController = createPinFetchedResultsController(nil, nil) {
      
      performPinFetchRequest(pinFetchedResultsController)
      
      if let pins = pinFetchedResultsController.fetchedObjects {
      
        for pin in pins {
          let pinMKPointAnnotation = MKPointAnnotation()
          pinMKPointAnnotation.coordinate.latitude = pin.latitude
          pinMKPointAnnotation.coordinate.longitude = pin.longitude
          
          mapView.addAnnotation(pinMKPointAnnotation)
        }
      }
    }
  }
  
  // MARK: Find the selected pin in coredata
  func findPinCoreData(selectedPinView: MKAnnotationView) -> Pin? {
    
    if let pinFetchedResultsController = createPinFetchedResultsController(selectedPinView.annotation?.coordinate.latitude, selectedPinView.annotation?.coordinate.longitude) {
      
      performPinFetchRequest(pinFetchedResultsController)
      
      // Make sure there is at least one pin in coredata
      if let matchingPins = pinFetchedResultsController.fetchedObjects, matchingPins.count > 0 {
        let correspondingPinInCoreData = matchingPins.first!
        return correspondingPinInCoreData
      }
    }
    return nil
  }
  
  
  // MARK: Build the fetch request controller, which will fetch pins. it looks for a specific PIN or bring all pins stored in core data
  func createPinFetchedResultsController(_ pinLatitude: Double?, _ pinLongitude: Double?) -> NSFetchedResultsController<Pin>? {
    
    let fetchRequest = NSFetchRequest<Pin>(entityName: "Pin")
    fetchRequest.sortDescriptors = []
    
    //    if PIN data, add a predicate to bring just a single PIN
    if let latitude = pinLatitude, let longitude = pinLongitude {
      let predicate = NSPredicate(format: "latitude = %@ && longitude = %@", argumentArray: [latitude, longitude])
      fetchRequest.predicate = predicate
    }
    
    let pinFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
    pinFetchedResultsController.delegate = self
    
    return pinFetchedResultsController
  }
  
  // MARK: Run pin fetch request.
  func performPinFetchRequest(_ pinFetchedResultsController: NSFetchedResultsController<Pin>?) {
    
    if let pinFetchedResultsController = pinFetchedResultsController {
      do {
        try pinFetchedResultsController.performFetch()
      } catch let pinFetchError as NSError {
        print("Error performing initial fetch: \(pinFetchError)")
      }
    }
  }
}


// MARK: MKMapViewDelegate

extension MapViewController {
  
  
  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    
    let reuseId = "pin"
    
    var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView
    
    if pinView == nil {
      pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
      pinView!.canShowCallout = false
      pinView!.pinTintColor = UIColor.blue
       
      pinView!.animatesDrop = true
    } else {
      pinView!.annotation = annotation
    }
    
    return pinView
  }
  
  func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
    
    let controller = self.storyboard!.instantiateViewController(withIdentifier: "PhotoViewController") as! PhotoViewController
    
    // Find the pin in core data.
    if let correspondingPinInCoreData = findPinCoreData(selectedPinView: view) {
      
      // And if it exists, send this pin to the view controller that will be pushed.
      controller.selectedPin = correspondingPinInCoreData
      
      // Push the view controller.
      self.navigationController?.pushViewController(controller, animated: true)
    }
  }
  
  
  func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
    updateMapViewCurrentStatus(mapView)
  }
  
  // MARK: Load/Save map location
  func checkIfFirstLaunch() {
    
    if UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
      let mapSavedLatitude = UserDefaults.standard.double(forKey: "mapSavedLatitude")
      let mapSavedLongitude = UserDefaults.standard.double(forKey: "mapSavedLongitude")
      let mapZoomLatitude = UserDefaults.standard.double(forKey: "mapZoomLatitude")
      let mapZoomLongitude = UserDefaults.standard.double(forKey: "mapZoomLongitude")
      
      let mapLocation = CLLocationCoordinate2D(latitude: mapSavedLatitude, longitude: mapSavedLongitude)
      let mapZoom = MKCoordinateSpanMake(mapZoomLatitude, mapZoomLongitude)
      
      let mapRegion = MKCoordinateRegionMake(mapLocation, mapZoom)
      mapView.setRegion(mapRegion, animated: false)
      
    } else {
      UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
      updateMapViewCurrentStatus(mapView)
    }
  }
  
  
  // MARK: update CD map location
  func updateMapViewCurrentStatus(_ mapView: MKMapView) {
    
    UserDefaults.standard.set(mapView.region.center.latitude, forKey: "mapSavedLatitude")
    UserDefaults.standard.set(mapView.region.center.longitude, forKey: "mapSavedLongitude")
    UserDefaults.standard.set(mapView.region.span.latitudeDelta, forKey: "mapZoomLatitude")
    UserDefaults.standard.set(mapView.region.span.longitudeDelta, forKey: "mapZoomLongitude")
    UserDefaults.standard.synchronize()
  }
}




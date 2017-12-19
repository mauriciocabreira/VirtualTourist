//
//  FlickrClient.swift
//  
//
//  Created by Mauricio Cabreira on 15/12/17.
//

import UIKit
import CoreData

class FlickrClient: NSObject {
  
  // MARK: Shared Instance
  class func sharedInstance() -> FlickrClient {
    struct Singleton {
      static var sharedInstance = FlickrClient()
    }
    return Singleton.sharedInstance
  }
  
  // MARK: Shared CD object context
  var sharedContext = CoreDataStack.sharedInstance().context
  
  // Shared session
  let session = URLSession.shared
  
  // MARK: Get Flicker photos for a dropped pin
  func downloadFlickrImages(_ pin: Pin) {
    
    // Method parameters for Flickr API calls.
    let methodParameters =
      [
        Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod,
        Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
        Constants.FlickrParameterKeys.BoundingBox: latLongBoundaryBoxString(pin.latitude, pin.longitude),
        Constants.FlickrParameterKeys.SafeSearch: Constants.FlickrParameterValues.UseSafeSearch,
        Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL,
        Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
        Constants.FlickrParameterKeys.PerPage: String(Constants.FlickrParameterValues.NumberofPhotosToRetrievePerPin),
        Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback
    ]
    
    // 1st: choose a Flickr page from the query result.
    chooseRandomPageOfFlickrPhotoResults(methodParameters as [String:AnyObject]) { (pageNumber, success, errorString) in
      if success {
        // Retrieve an array describing the photos on that page of search results.
        self.getFlickrPhotosFromPageInResults(methodParameters as [String : AnyObject], pageNumber: pageNumber!) { (flickrPhotoArrayForPage, success, errorString) in
          if success {
            // Choose photos at random from that page, and store its URLs in CD.
            self.randomlyChooseAndStorePhotoURLsFromFlickrPage(pin: pin, flickrPhotoArrayForPage: flickrPhotoArrayForPage!)
          } else {
            print(errorString as Any)
          }
        }
      } else {
        print(errorString as Any)
      }
    }
  }
  
  // MARK: Boundary box from the pin's lat-long coordinate to send to Flickr.
  private func latLongBoundaryBoxString(_ latitude: Double, _ longitude: Double) -> String {
    
    let minimumLon = max(longitude - Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.0)
    let minimumLat = max(latitude - Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.0)
    let maximumLon = min(longitude + Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.1)
    let maximumLat = min(latitude + Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.1)
    return "\(minimumLon),\(minimumLat),\(maximumLon),\(maximumLat)"
  }
  
  // MARK: Download and store a photo from Flickr
  func downloadAndStoreFlickrPhoto(_ photo: Photo, completionHandlerForDownloadAndStoreFlickrPhoto: @escaping (_ success: Bool, _ errorString: String?) -> Void) {
    // Download the photo in background
    if let photoURL = photo.url {
      let imageURL = URL(string: photoURL)
      DispatchQueue.global(qos: .background).async {
        if let imageData = try? Data(contentsOf: imageURL!) {
       
          // Store image in CD
          self.sharedContext.performAndWait {
            photo.image = imageData as NSData
            CoreDataStack.sharedInstance().save()
          }
        
          // Inform completion handler that download has been successful.
          self.sharedContext.performAndWait {
            completionHandlerForDownloadAndStoreFlickrPhoto(true, nil)
          }
        } else {
          self.sharedContext.performAndWait {
            let errorString = "Unable to download image from URL: \(imageURL!)"
            completionHandlerForDownloadAndStoreFlickrPhoto(false, errorString)
          }
        }
      }
    }
  }
  
  // MARK: Randomly choose a page of Flickr for the specific pin
  private func chooseRandomPageOfFlickrPhotoResults(_ methodParameters: [String: AnyObject], completionHandlerForChooseRandomPageOfFlickrPhotoResults: @escaping (_ pageNumber: Int?, _ success: Bool, _ errorString: String?) -> Void) {
    
    let request = URLRequest(url: flickrURLFromParameters(methodParameters))
    
    let task = session.dataTask(with: request) { (data, response, error) in
      
      func displayError(_ errorString: String) {
        completionHandlerForChooseRandomPageOfFlickrPhotoResults(nil, false, errorString)
      }
      
      // Parse the data and response from the Flickr API task
      self.flickrTaskAndDataParsingHelper(data: data, response: response, error: error) { (photosDictionary, success, errorString) in
        if success {
          /* GUARD: Is the "pages" key in the photosDictionary? */
          guard let totalPages = photosDictionary![Constants.FlickrResponseKeys.Pages] as? Int else {
            displayError("Cannot find key '\(Constants.FlickrResponseKeys.Pages)' in \(photosDictionary!)")
            return
          }
          
          // Pick a random page, then X photos from that page
          let pageLimit = min(totalPages, 30)
          let randomPage = Int(arc4random_uniform(UInt32(pageLimit))) + 1
          completionHandlerForChooseRandomPageOfFlickrPhotoResults(randomPage, true, nil)
        } else {
          displayError(errorString!)
        }
      }
    }
    task.resume()
  }
  
  // MARK: Get photos from the randomly chosen Flickr search results page.
  private func getFlickrPhotosFromPageInResults(_ methodParameters: [String: AnyObject], pageNumber: Int, completionHandlerForGetFlickrPhotosFromPageInResults: @escaping (_ flickrPhotoArrayForPage: [[String:AnyObject]]?, _ success: Bool, _ errorString: String?) -> Void) {
    
    // Add the Flickr results page number to the method's parameters.
    var methodParametersWithPageNumber = methodParameters
    methodParametersWithPageNumber[Constants.FlickrParameterKeys.Page] = pageNumber as AnyObject?
    
    let request = URLRequest(url: flickrURLFromParameters(methodParameters))
    let task = session.dataTask(with: request) { (data, response, error) in
      
      func displayError(_ errorString: String) {
        completionHandlerForGetFlickrPhotosFromPageInResults(nil, false, errorString)
      }
      
      self.flickrTaskAndDataParsingHelper(data: data, response: response, error: error) { (photosDictionary, success, errorString) in
        if success {
          /* GUARD: Is the "photo" key in photosDictionary? */
          guard let flickrPhotoArrayForPage = photosDictionary![Constants.FlickrResponseKeys.Photo] as? [[String: AnyObject]] else {
            displayError("Cannot find key '\(Constants.FlickrResponseKeys.Photo)' in \(photosDictionary!)")
            return
          }
          guard flickrPhotoArrayForPage.count != 0 else {
            displayError("This pin has no images.")
            return
          }
          
          completionHandlerForGetFlickrPhotosFromPageInResults(flickrPhotoArrayForPage, true, nil)
        } else {
          displayError(errorString!)
        }
      }
    }
    task.resume()
  }
  
  // MARK: Randomly load photos from Flickr results page.
  private func randomlyChooseAndStorePhotoURLsFromFlickrPage(pin: Pin, flickrPhotoArrayForPage: [[String:AnyObject]?]) {
    
    // The number of photos on the Flickr results page.
    let numberOfPhotosOnPage = flickrPhotoArrayForPage.count
    
    // Randomly select at most X photos from the Flickr results page:
    
    // If less than x photos on results page, select them all.
    if numberOfPhotosOnPage < FlickrClient.Constants.FlickrParameterValues.NumberofPhotosToRetrievePerPin {
      for entry in flickrPhotoArrayForPage {
        if let entry = entry, let photoURLString = entry[Constants.FlickrResponseKeys.MediumURL] as? String {
          
          // save photo URL. Note that image has not been downloaded yet.
          savePhotoURLToCD(pin: pin, photoURL: photoURLString)
        }
      }
      performUIUpdatesOnMain {
        CoreDataStack.sharedInstance().save()
      }
      
    } else {
      // If more than X photos, randomly pick them
      var indicesOfPhotosAlreadyChosen: [Int] = []
      while indicesOfPhotosAlreadyChosen.count < FlickrClient.Constants.FlickrParameterValues.NumberofPhotosToRetrievePerPin {
        let randomUniqueIndex = generateUniqueRandomIndexNumber(upperLimit: numberOfPhotosOnPage, indicesOfPhotosAlreadyChosen: indicesOfPhotosAlreadyChosen)
        
        indicesOfPhotosAlreadyChosen.append(randomUniqueIndex)
        
        // apagar - comecou a dar merda antes de chegar aqui!!!
        // Does the photo have a key 'url_m'?
        if let randomlyChosenPhotoEntry = flickrPhotoArrayForPage[randomUniqueIndex], let randomlyChosenPhotoURLString = randomlyChosenPhotoEntry[Constants.FlickrResponseKeys.MediumURL] as? String {
          savePhotoURLToCD(pin: pin, photoURL: randomlyChosenPhotoURLString)
        }
      }
    
      performUIUpdatesOnMain {
        CoreDataStack.sharedInstance().save()
      }
 
    }
  }
  
  // MARK: Save photo URL to CD
  func savePhotoURLToCD(pin: Pin, photoURL: String) {
    
    performUIUpdatesOnMain {
      let photoToSave = Photo(context: self.sharedContext)
      photoToSave.url = photoURL
      photoToSave.pin = pin
    }
  }
  
  // MARK: Generate a unique random index number
  func generateUniqueRandomIndexNumber(upperLimit: Int, indicesOfPhotosAlreadyChosen: [Int]) -> Int {
    let randomIndexNumber = Int(arc4random_uniform(UInt32(upperLimit)))
    
    // Return the random number if it hasn't already been used.
    if !indicesOfPhotosAlreadyChosen.contains(randomIndexNumber) {
      return randomIndexNumber
    } else {
      // If the number has been used already, try again and choose a new number.
      return generateUniqueRandomIndexNumber(upperLimit: upperLimit, indicesOfPhotosAlreadyChosen: indicesOfPhotosAlreadyChosen)
    }
  }
  
  // MARK: Helper for Creating a URL from Parameters
  private func flickrURLFromParameters(_ parameters: [String:AnyObject]) -> URL {
    
    var components = URLComponents()
    components.scheme = Constants.Flickr.APIScheme
    components.host = Constants.Flickr.APIHost
    components.path = Constants.Flickr.APIPath
    components.queryItems = [URLQueryItem]()
    
    for (key, value) in parameters {
      let queryItem = URLQueryItem(name: key, value: "\(value)")
      components.queryItems!.append(queryItem)
    }
    
    return components.url!
  }
}

// MARK: Flickr API task data parsing helper method
extension FlickrClient {
  
  func flickrTaskAndDataParsingHelper(data: Data?, response: URLResponse?, error: Error?, completionHandlerForFlickrTaskAndDataParsingHelper: @escaping (_ photosDictionary: [String:AnyObject]?, _ success: Bool, _ errorString: String?) -> Void) {
    /* GUARD: Was there an error? */
    guard (error == nil) else {
      let errorString = "There was an error with your request: \(String(describing: error))"
      completionHandlerForFlickrTaskAndDataParsingHelper(nil, false, errorString)
      return
    }
    
    /* GUARD: Did we get a successful 2XX response? */
    guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
      let errorString = "Your request returned a status code other than 2xx!"
      completionHandlerForFlickrTaskAndDataParsingHelper(nil, false, errorString)
      return
    }
    
    /* GUARD: Was there any data returned? */
    guard let data = data else {
      let errorString = "No data was returned by the request!"
      completionHandlerForFlickrTaskAndDataParsingHelper(nil, false, errorString)
      return
    }
    
    // Parse the data.
    let parsedResult: [String:AnyObject]!
    do {
      parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
    } catch {
      let errorString = "Could not parse the data as JSON: '\(data)'"
      completionHandlerForFlickrTaskAndDataParsingHelper(nil, false, errorString)
      return
    }
    
    /* GUARD: Did Flickr return an error (stat != ok)? */
    guard let stat = parsedResult[Constants.FlickrResponseKeys.Status] as? String, stat == Constants.FlickrResponseValues.OKStatus else {
      let errorString = "Flickr API returned an error. See error code and message in \(parsedResult)"
      completionHandlerForFlickrTaskAndDataParsingHelper(nil, false, errorString)
      return
    }
    
    /* GUARD: Is "photos" key in our result? */
    guard let photosDictionary = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String:AnyObject] else {
      let errorString = "Cannot find keys '\(Constants.FlickrResponseKeys.Photos)' in \(parsedResult)"
      completionHandlerForFlickrTaskAndDataParsingHelper(nil, false, errorString)
      return
    }
    
    completionHandlerForFlickrTaskAndDataParsingHelper(photosDictionary, true, nil)
  }
}




//
//  FlickrContants.swift
//  
//
//  Created by Mauricio Cabreira on 15/12/17.
//

import UIKit

// MARK: FlickrClient (Constants)

extension FlickrClient {
  
  struct Constants {
    
    // MARK: Flickr
    struct Flickr {
      static let APIScheme = "https"
      static let APIHost = "api.flickr.com"
      static let APIPath = "/services/rest"
      
      static let SearchBBoxHalfWidth = 1.0
      static let SearchBBoxHalfHeight = 1.0
      static let SearchLatRange = (-90.0, 90.0)
      static let SearchLonRange = (-180.0, 180.0)
    }
    
    // MARK: Flickr Parameter Keys
    struct FlickrParameterKeys {
      static let Method = "method"
      static let APIKey = "api_key"
      static let GalleryID = "gallery_id"
      static let Extras = "extras"
      static let Format = "format"
      static let NoJSONCallback = "nojsoncallback"
      static let SafeSearch = "safe_search"
      static let Text = "text"
      static let BoundingBox = "bbox"
      static let Page = "page"
    }
    
    // MARK: Flickr Parameter Values
    struct FlickrParameterValues {
      static let SearchMethod = "flickr.photos.search"
      static let APIKey = "d225ac226f4b555d19bcb0b133f1b150"
      static let ResponseFormat = "json"
      static let DisableJSONCallback = "1"
      static let GalleryPhotosMethod = "flickr.galleries.getPhotos"
      static let GalleryID = "5704-72157622566655097"
      static let MediumURL = "url_m"
      static let UseSafeSearch = "1"
      static let NumberofPhotosToRetrievePerPin = 30
    }
    
    // MARK: Flickr Response Keys
    struct FlickrResponseKeys {
      static let Status = "stat"
      static let Photos = "photos"
      static let Photo = "photo"
      static let Title = "title"
      static let MediumURL = "url_m"
      static let Pages = "pages"
      static let PerPage = "perpage"
      static let Total = "total"
    }
    
    // MARK: Flickr Response Values
    struct FlickrResponseValues {
      static let OKStatus = "ok"
    }
    
  }
  
}




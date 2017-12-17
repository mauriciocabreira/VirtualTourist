//
//  Photo+CoreDataClass.swift
//  VirtualTourist
//
//  Created by Mauricio Cabreira on 14/12/17.
//  Copyright © 2017 Mauricio Cabreira. All rights reserved.
//
//

import Foundation
import CoreData

@objc(Photo)
public class Photo: NSManagedObject {
  convenience init(url: String, image: NSData, context: NSManagedObjectContext) {
    if let entity = NSEntityDescription.entity(forEntityName: "Photo", in: context) {
      self.init(entity: entity, insertInto: context)
      self.url = url
      self.image = image
    } else {
      fatalError("Unable to find entity name!")
    }
  }
}

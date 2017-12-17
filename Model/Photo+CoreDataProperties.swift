//
//  Photo+CoreDataProperties.swift
//  VirtualTourist
//
//  Created by Mauricio Cabreira on 14/12/17.
//  Copyright © 2017 Mauricio Cabreira. All rights reserved.
//
//

import Foundation
import CoreData


extension Photo {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Photo> {
        return NSFetchRequest<Photo>(entityName: "Photo")
    }

    @NSManaged public var url: String?
    @NSManaged public var image: NSData?
    @NSManaged public var pin: Pin?

}

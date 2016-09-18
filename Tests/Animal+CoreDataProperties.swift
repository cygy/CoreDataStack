//
//  Animal+CoreDataProperties.swift
//  CoreDataStack
//
//  Created by Cyril on 17/09/2016.
//  Copyright © 2016 Cyril GY. All rights reserved.
//

import Foundation
import CoreData


extension Animal {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Animal> {
        return NSFetchRequest<Animal>(entityName: "Animal");
    }

    @NSManaged public var name: String?
    @NSManaged public var type: String?

}

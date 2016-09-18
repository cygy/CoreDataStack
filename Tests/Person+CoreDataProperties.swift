//
//  Person+CoreDataProperties.swift
//  CoreDataStack
//
//  Created by Cyril on 17/09/2016.
//  Copyright © 2016 Cyril GY. All rights reserved.
//

import Foundation
import CoreData


extension Person {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Person> {
        return NSFetchRequest<Person>(entityName: "Person");
    }

    @NSManaged public var age: Int16
    @NSManaged public var firstName: String?
    @NSManaged public var lastName: String?

}

//
//  Person+CoreDataProperties.swift
//  CoreDataStack-Example
//
//  Created by Cyril on 05/04/2016.
//  Copyright © 2016 Cyril GY. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Person {

    @NSManaged var lastName: String?
    @NSManaged var firstName: String?
    @NSManaged var age: Int16

}

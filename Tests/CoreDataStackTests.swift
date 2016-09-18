//
//  CoreDataStackTests.swift
//  CoreDataStackTests
//
//  Created by Cyril on 03/04/2016.
//
//  The MIT License (MIT)
//
//  Copyright (c) 2016 Cyril Gy
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import XCTest
import CoreData
@testable import CoreDataStack

class CoreDataStackTests: XCTestCase {
    
    // MARK: - Private static properties
    
    private static let multipleModelsFileName = "two-models.sqlite"
    private static let oneModelFileName = "tests.sqlite"
    
    private static let personFirstName = "John"
    private static let personLastName = "Doe"
    private static let personAge: Int16 = 20
    
    private static let animalName = "Chucky"
    private static let animalType = "Dog"
    
    
    // MARK: - Private static methods
    
    private class func filePath(withName name: String) -> String? {
        guard let directoryPath = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first else {
            return nil
        }
        
        return URL(fileURLWithPath: directoryPath).appendingPathComponent(name).path
    }
    
    
    // MARK: - Life cycle
    
    override class func setUp() {
        super.setUp()
        
        // This method is called before the invocation of all test methods in the class.
        
        // Remove the files created by the previous tests.
        [CoreDataStackTests.multipleModelsFileName, CoreDataStackTests.oneModelFileName].forEach { (fileName) in
            if let path = CoreDataStackTests.filePath(withName: fileName) {
                do {
                    try FileManager.default.removeItem(atPath: path)
                }
                catch let e {
                    debugPrint("Can not remove the file at \(path): \(e)")
                }
            }
        }
    }
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    
    // MARK: - Private methods
    
    private func createStackFromModels(withNames modelFileNames: [String], andWithFileName fileName: String) -> CoreDataStack? {
        let stack = CoreDataStack(modelFileNames: modelFileNames, persistentFileName: fileName, persistentStoreType: NSSQLiteStoreType, persistentStoreConfigration: nil, persistentStoreOptions: [NSMigratePersistentStoresAutomaticallyOption: true as AnyObject, NSInferMappingModelAutomaticallyOption: true as AnyObject], bundle: Bundle(for: type(of: self)))
        
        if let filePath = CoreDataStackTests.filePath(withName: fileName) {
            XCTAssertTrue(FileManager.default.fileExists(atPath: filePath), "Create a stack must create the store file to the disk.")
        }
        else {
            XCTFail("Can not get the path of the persistent store file.")
        }
        
        return stack
    }
    
    private func checkDefaultContext(fromStack stack: CoreDataStack) {
        XCTAssertNotNil(stack.defaultContext, "Default context must not be nil.")
        XCTAssertNotNil(stack.defaultContext.parent, "The parent of the default context must not be nil, parent context must be the writer context.")
        XCTAssertNotNil(stack.defaultContext.persistentStoreCoordinator, "The persistent store coordinator of the default context must not be nil.")
        XCTAssertEqual(stack.defaultContext.concurrencyType, .mainQueueConcurrencyType, "Default context concurrency type must be MainQueue.")
    }
    
    private func newContexts(fromStack stack: CoreDataStack) -> (NSManagedObjectContext, NSManagedObjectContext, NSManagedObjectContext) {
        let newContext = stack.newContext()
        let backgroundContext = stack.newContextForBackgroundTask()
        let batchContext = stack.newContextForBatchTask()
        
        XCTAssertNotEqual(stack.defaultContext, newContext, "Context created by a CoreDataStack object must be different that its the default context.")
        XCTAssertNotEqual(stack.defaultContext, backgroundContext, "Context for background task created by a CoreDataStack object must be different that its the default context.")
        XCTAssertNotEqual(stack.defaultContext, batchContext, "Context for batch task created by a CoreDataStack object must be different that its the default context.")
        
        XCTAssertEqual(newContext.parent, stack.defaultContext, "The parent context of a context created by a CoreDataStack object must be its default context.")
        XCTAssertNotEqual(backgroundContext.parent, stack.defaultContext, "The parent context of a context for background task created by a CoreDataStack object must not be its default context.")
        XCTAssertEqual(backgroundContext.parent, stack.defaultContext.parent, "The parent context of a context for background task created by a CoreDataStack object must be the same as its parent default context.")
        XCTAssertNil(batchContext.parent, "The parent context of a context for batch task created by a CoreDataStack object must be nil.")
        
        XCTAssertEqual(backgroundContext.persistentStoreCoordinator, stack.defaultContext.persistentStoreCoordinator, "The persistent store coordinator of a context for background task created by a CoreDataStack object must be the same as its default context.")
        XCTAssertNotEqual(batchContext.persistentStoreCoordinator, stack.defaultContext.persistentStoreCoordinator, "The persistent store coordinator of a context for batch task created by a CoreDataStack object must not be the same as its default context.")
        
        XCTAssertEqual(newContext.concurrencyType, .privateQueueConcurrencyType, "The concurrency type of a context created by a CoreDataStack object must be PrivateQueue.")
        XCTAssertEqual(backgroundContext.concurrencyType, .privateQueueConcurrencyType, "The concurrency type of a context for background task created by a CoreDataStack object must be PrivateQueue.")
        XCTAssertEqual(batchContext.concurrencyType, .privateQueueConcurrencyType, "The concurrency type of a context for batch task created by a CoreDataStack object must be PrivateQueue.")
        
        return (newContext, backgroundContext, batchContext)
    }
    
    private func createPerson(withFirstName firstName: String, lastName: String, andAge age: Int16, inContext context: NSManagedObjectContext, withLabel label: String) {
        context.performAndWait {
            let person = NSEntityDescription.insertNewObject(forEntityName: "Person", into: context) as! Person
            person.firstName = firstName
            person.lastName = lastName
            person.age = age
            
            if let error = context.saveToParent() {
                XCTFail("Can not save the context '\(label)': \(error).")
            }
        }
    }
    
    // TODO: Update person.
    
    private func checkIfPerson(withFirstName firstName: String, lastName: String, andAge age: Int16, exists: Bool, inContext context: NSManagedObjectContext, withLabel label: String, andDeleteIt delete: Bool) {
        let request: NSFetchRequest<Person> = Person.fetchRequest()
        request.predicate = NSPredicate(format: "%K =[cd] %@ && %K =[cd] %@", "firstName", firstName, "lastName", lastName)
        request.shouldRefreshRefetchedObjects = true
        
        context.performAndWait {
            context.reset()
            
            do {
                let persons = try context.fetch(request)
                
                guard exists else {
                    XCTAssertEqual(persons.count, 0, "No person must be returned from context '\(label)' if the object does not exist anymore.")
                    return
                }
                
                let action = delete ? "delete" : "check exist"
                
                guard let person = persons.first else {
                    XCTFail("One person must be returned from context '\(label)' (action: \(action)).")
                    return
                }
                
                if exists && !delete {
                    XCTAssertEqual(person.firstName, firstName, "Property of a person must not be modified when it fetched from context '\(label)'.")
                    XCTAssertEqual(person.lastName, lastName, "Property of a person must not be modified when it fetched from context '\(label)'.")
                    XCTAssertEqual(person.age, age, "Property of a person must not be modified when it fetched from context '\(label)'.")
                }
                
                if delete {
                    context.delete(person)
                    
                    if let error = context.saveToParent() {
                        XCTFail("Delete a person must not return an error from context '\(label)': \(error).")
                    }
                }
            }
            catch let e {
                XCTFail("Fetching persons must not throw error from context '\(label)': \(e)")
            }
        }
    }
    
    private func checkIfPerson(withFirstName firstName: String, lastName: String, andAge age: Int16, existsInContext context: NSManagedObjectContext, withLabel label: String) {
        checkIfPerson(withFirstName: firstName, lastName: lastName, andAge: age, exists: true, inContext: context, withLabel: label, andDeleteIt: false)
    }
    
    private func checkIfPerson(withFirstName firstName: String, lastName: String, andAge age: Int16, doesNotExistInContext context: NSManagedObjectContext, withLabel label: String) {
        checkIfPerson(withFirstName: firstName, lastName: lastName, andAge: age, exists: false, inContext: context, withLabel: label, andDeleteIt: false)
    }
    
    private func deletePerson(withFirstName firstName: String, lastName: String, andAge age: Int16, fromContext context: NSManagedObjectContext, withLabel label: String) {
        checkIfPerson(withFirstName: firstName, lastName: lastName, andAge: age, exists: true, inContext: context, withLabel: label, andDeleteIt: true)
    }
    
    private func createAnimal(withName name: String, andType type: String, inContext context: NSManagedObjectContext, withLabel label: String) {
        context.performAndWait {
            let animal = NSEntityDescription.insertNewObject(forEntityName: "Animal", into: context) as! Animal
            animal.name = name
            animal.type = type
            
            if let error = context.saveToParent() {
                XCTFail("Can not save the context '\(label)': \(error).")
            }
        }
    }
    
    // TODO: Update animal.
    
    private func checkIfAnimal(withName name: String, andType type: String, exists: Bool, inContext context: NSManagedObjectContext, withLabel label: String, andDeleteIt delete: Bool) {
        let request: NSFetchRequest<Animal> = Animal.fetchRequest()
        request.predicate = NSPredicate(format: "%K =[cd] %@ && %K =[cd] %@", "name", name, "type", type)
        request.shouldRefreshRefetchedObjects = true
        
        context.performAndWait {
            context.reset()
            
            do {
                let animals = try context.fetch(request)
                
                guard exists else {
                    XCTAssertEqual(animals.count, 0, "No animal must be returned from context '\(label)' if the object does not exist anymore.")
                    return
                }
                
                let action = delete ? "delete" : "check exist"
                
                guard let animal = animals.first else {
                    XCTFail("One animal must be returned from context '\(label)' (action: \(action)).")
                    return
                }
                
                if exists && !delete {
                    XCTAssertEqual(animal.name, name, "Property of an animal must not be modified when it fetched from context '\(label)'.")
                    XCTAssertEqual(animal.type, type, "Property of an animal must not be modified when it fetched from context '\(label)'.")
                }
                
                if delete {
                    context.delete(animal)
                    
                    if let error = context.saveToParent() {
                        XCTFail("Delete an animal must not return an error from context '\(label)': \(error).")
                    }
                }
            }
            catch let e {
                XCTFail("Fetching animals must not throw error from context '\(label)': \(e)")
            }
        }
    }
    
    private func checkIfAnimal(withName name: String, andType type: String, existsInContext context: NSManagedObjectContext, withLabel label: String) {
        checkIfAnimal(withName: name, andType: type, exists: true, inContext: context, withLabel: label, andDeleteIt: false)
    }
    
    private func checkIfAnimal(withName name: String, andType type: String, doesNotExistInContext context: NSManagedObjectContext, withLabel label: String) {
        checkIfAnimal(withName: name, andType: type, exists: false, inContext: context, withLabel: label, andDeleteIt: false)
    }
    
    private func deleteAnimal(withName name: String, andType type: String, fromContext context: NSManagedObjectContext, withLabel label: String) {
        checkIfAnimal(withName: name, andType: type, exists: true, inContext: context, withLabel: label, andDeleteIt: true)
    }
    
    
    // MARK: - Tests
    
    func testStackWithOneModel() {
        if let stack = createStackFromModels(withNames: ["CoreDataStack-Tests"], andWithFileName: CoreDataStackTests.oneModelFileName) {
            checkDefaultContext(fromStack: stack)
            
            let defaultContext = stack.defaultContext
            let (newContext, backgroundContext, batchContext) = newContexts(fromStack: stack)
            
            let contexts = [defaultContext, newContext, backgroundContext, batchContext]
            
            // Create, update and delete a person.
            let firstName = CoreDataStackTests.personFirstName
            let lastName = CoreDataStackTests.personLastName
            let age = CoreDataStackTests.personAge
            
            contexts.forEach({ (context) in
                var contextLabel: String?
                switch context {
                case defaultContext:
                    contextLabel = "defaultContext"
                    break
                case newContext:
                    contextLabel = "newContext"
                    break
                case backgroundContext:
                    contextLabel = "backgroundContext"
                    break
                case batchContext:
                    contextLabel = "batchContext"
                    break
                default:
                    break
                }
                
                guard let label = contextLabel else {
                    XCTFail("Label for context must be defined.")
                    return
                }
                
                createPerson(withFirstName: firstName, lastName: lastName, andAge: age, inContext: context, withLabel: label)
                checkIfPerson(withFirstName: firstName, lastName: lastName, andAge: age, existsInContext: context, withLabel: label)
                checkIfPerson(withFirstName: firstName, lastName: lastName, andAge: age, existsInContext: defaultContext, withLabel: "defaultContext (object created with context '\(label)')")
                deletePerson(withFirstName: firstName, lastName: lastName, andAge: age, fromContext: context, withLabel: label)
                checkIfPerson(withFirstName: firstName, lastName: lastName, andAge: age, doesNotExistInContext: context, withLabel: label)
                checkIfPerson(withFirstName: firstName, lastName: lastName, andAge: age, doesNotExistInContext: defaultContext, withLabel: "defaultContext (object created with context '\(label)')")
            })
            
        }
    }
    
    func testStackWithTwoModels() {
        if let stack = createStackFromModels(withNames: ["CoreDataStack-Tests","CoreDataStack-Tests2"], andWithFileName: CoreDataStackTests.multipleModelsFileName) {
            checkDefaultContext(fromStack: stack)
            
            let defaultContext = stack.defaultContext
            let (newContext, backgroundContext, batchContext) = newContexts(fromStack: stack)
            
            let contexts = [defaultContext, newContext, backgroundContext, batchContext]
            
            // Create, update and delete a person and an animal.
            let firstName = CoreDataStackTests.personFirstName
            let lastName = CoreDataStackTests.personLastName
            let age = CoreDataStackTests.personAge
            
            let animalName = CoreDataStackTests.animalName
            let animalType = CoreDataStackTests.animalType
            
            contexts.forEach({ (context) in
                var contextLabel: String?
                switch context {
                case defaultContext:
                    contextLabel = "defaultContext"
                    break
                case newContext:
                    contextLabel = "newContext"
                    break
                case backgroundContext:
                    contextLabel = "backgroundContext"
                    break
                case batchContext:
                    contextLabel = "batchContext"
                    break
                default:
                    break
                }
                
                guard let label = contextLabel else {
                    XCTFail("Label for context must be defined.")
                    return
                }
                
                createPerson(withFirstName: firstName, lastName: lastName, andAge: age, inContext: context, withLabel: label)
                
                contexts.forEach({ (context) in
                    checkIfPerson(withFirstName: firstName, lastName: lastName, andAge: age, existsInContext: context, withLabel: label)
                })
                
                deletePerson(withFirstName: firstName, lastName: lastName, andAge: age, fromContext: context, withLabel: label)
                
                contexts.forEach({ (context) in
                    checkIfPerson(withFirstName: firstName, lastName: lastName, andAge: age, doesNotExistInContext: context, withLabel: label)
                })
                
                createAnimal(withName: animalName, andType: animalType, inContext: context, withLabel: label)
                
                contexts.forEach({ (context) in
                    checkIfAnimal(withName: animalName, andType: animalType, existsInContext: context, withLabel: label)
                })
                
                deleteAnimal(withName: animalName, andType: animalType, fromContext: context, withLabel: label)
                
                contexts.forEach({ (context) in
                    checkIfAnimal(withName: animalName, andType: animalType, doesNotExistInContext: context, withLabel: label)
                })
            })
            
        }
    }
    
}

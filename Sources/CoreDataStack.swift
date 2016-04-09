//
//  CoreDataStack.swift
//  CoreDataStack
//
//  Created by Cyril on 03/04/2016.
//  Copyright © 2016 Cyril GY. All rights reserved.
//

import CoreData

final public class CoreDataStack {
    
    // MARK: - Properties
    
    /**
    Casual CoreData objects.
    */
    private let managedObjectModel: NSManagedObjectModel
    private let persistentStoreCoodinator: NSPersistentStoreCoordinator
    
    /**
     This NSManagedObjectContext is responsible to write to the store.
     */
    private let writerManagedObjectContext: NSManagedObjectContext
    
    /**
     This NSManagedObjectContext is the main context, running into the main thread.
     Use it with the NSFetchedResultsController objects.
     It will not write directly to the store, this is delegated to the writerManagedObjectContext object.
     Do not use this context directly to update/delete/create NSManagedObject objects,
     call the getNewManagedObjectContextForLongRunningTask() or getNewManagedObjectContext() methods instead.
     */
    public let defaultManagedObjectContext: NSManagedObjectContext
    
    
    // MARK: - Methods
    
    /**
    Create a new NSManagedObjectContext object bound to the defaultManagedObjectContext object.
    Call this method to get a NSManagedObjectContext object in order to execute a small amount of CoreData operations.
    
    - returns: the new NSManagedObjectContext used to update/create some NSManagedObject objects.
    */
    public func getNewManagedObjectContext() -> NSManagedObjectContext {
        return getNewManagedObjectContextBoundToWriterContext(false)
    }
    
    /**
     Create a new NSManagedObjectContext object bound to the writerManagedObjectContext object directly.
     Call this method to get a NSManagedObjectContext object in order to execute a large amount of CoreData operations
     or execute some operations in background.
     
     - returns: the new NSManagedObjectContext used to update/create some NSManagedObject objects.
     */
    public func getNewManagedObjectContextForLongRunningTask() -> NSManagedObjectContext {
        return getNewManagedObjectContextBoundToWriterContext(true)
    }
    
    /**
     Save a context and save its parent context if needed.
     Please call this method in order to save the NSManagedObjectContext objects created by this manager.
     
     - parameter context: the context to save.
     - throws: save operations can throw errors.
     */
    public func saveContext(context: NSManagedObjectContext) throws {
        try context.save()
        
        if context.parentContext == defaultManagedObjectContext {
            try context.parentContext?.save()
        }
    }
    
    /**
     Call this method to save the changes to persistent store.
     This must be called in the 'applicationWillTerminate' and/or 'applicationWillResignActive' methods.
     
     - throws: save operations can throw errors.
     */
    public func saveContexts() throws {
        try defaultManagedObjectContext.save()
        try writerManagedObjectContext.save()
    }
    
    
    // MARK: - Private methods
    
    /**
    Create a new NSManagedObjectContext object bound or not to the writerManagedObjectContext object.
    
    - parameter boundToWriterContext: bool to know if this NSManagedObjectContext object must be bound to the writerManagedObjectContext object.
    - returns: the new NSManagedObjectContext used to update/create some NSManagedObject objects.
    */
    private func getNewManagedObjectContextBoundToWriterContext(boundToWriterContext: Bool) -> NSManagedObjectContext {
        let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        context.undoManager = nil
        
        context.parentContext = boundToWriterContext ? writerManagedObjectContext : defaultManagedObjectContext
        
        return context
    }
    
    
    // MARK: - Lifecycle
    
    /**
    Create a new CoreDataManager object.
    
    - parameter modelFileNames: Name of the .momd files (usually at the root of the bundle).
    - parameter persistentFileName: name of the persistent file of the CoreData.
    - parameter persistentStoreType: type of the persistent store (default = NSSQLiteStoreType)
    - parameter persistentStoreConfigration: configuration of the persistent store (default = nil)
    - parameter persistentStoreOptions: options of the persistent store (default = [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true])
    - returns: the new NSManagedObjectContext used to update/create some NSManagedObject objects.
    */
    public init(modelFileNames: [String], persistentFileName: String, persistentStoreType: String = NSSQLiteStoreType, persistentStoreConfigration: String? = nil, persistentStoreOptions: [String:AnyObject]? = [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]) {
        // Create the managed object model.
        var models = [NSManagedObjectModel]()
        for modelFileName in modelFileNames {
            guard let path = NSBundle.mainBundle().pathForResource(modelFileName, ofType: "momd") else {
                fatalError("Can not create managed object model with name: \(modelFileName)")
            }
            
            guard let model = NSManagedObjectModel(contentsOfURL: NSURL(fileURLWithPath: path)) else {
                fatalError("Can not create managed object model from path: \(path)")
            }
            
            models.append(model)
        }
        
        guard let model = NSManagedObjectModel(byMergingModels: models) else {
            fatalError("Can not merge the managed object models")
        }
        
        managedObjectModel = model
        
        // Create the persistent store coordinator.
        guard let directoryPath = NSSearchPathForDirectoriesInDomains(.ApplicationSupportDirectory, .UserDomainMask, true).first else {
            fatalError("Can not initialize the persistent store coordinator.")
        }
        
        let fileManager = NSFileManager.defaultManager()
        if !fileManager.fileExistsAtPath(directoryPath) {
            do {
                try fileManager.createDirectoryAtPath(directoryPath, withIntermediateDirectories: true, attributes: nil)
            } catch let error {
                fatalError("Can not create the persistent store coordinator directory: \(error).")
            }
        }
        
        persistentStoreCoodinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
        
        do {
            let storeURL = NSURL(fileURLWithPath: directoryPath).URLByAppendingPathComponent(persistentFileName)
            try persistentStoreCoodinator.addPersistentStoreWithType(persistentStoreType, configuration: persistentStoreConfigration, URL: storeURL, options: persistentStoreOptions)
        } catch let error {
            fatalError("Can not create the persistent store coordinator file: \(error).")
        }
        
        // Create the writer managed object context.
        writerManagedObjectContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.PrivateQueueConcurrencyType)
        writerManagedObjectContext.undoManager = nil
        writerManagedObjectContext.persistentStoreCoordinator = persistentStoreCoodinator
        
        // Create the default managed object contexte.
        defaultManagedObjectContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.MainQueueConcurrencyType)
        defaultManagedObjectContext.undoManager = nil
        defaultManagedObjectContext.parentContext = writerManagedObjectContext
    }
}

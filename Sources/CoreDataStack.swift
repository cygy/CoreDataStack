//
//  CoreDataStack.swift
//  CoreDataStack
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

import CoreData

final public class CoreDataStack {
    
    // MARK: - Properties
    
    /**
     Casual CoreData objects.
     See Apple documentation to more details: https://developer.apple.com/library/ios/documentation/Cocoa/Conceptual/CoreData/index.html#//apple_ref/doc/uid/TP40001075
     */
    private let managedObjectModel: NSManagedObjectModel
    private let defaultPersistentStoreCoodinator: NSPersistentStoreCoordinator
    private let batchPersistentStoreCoodinator: NSPersistentStoreCoordinator
    
    /**
     This NSManagedObjectContext is responsible to write to the persistent store.
     */
    private let writerManagedObjectContext: NSManagedObjectContext
    
    /**
     This NSManagedObjectContext is the main context, running into the main thread.
     Use it with the NSFetchedResultsController objects.
     It will not write directly to the store, this is delegated to the writerManagedObjectContext object.
     Do not use this context directly to update/delete/create NSManagedObject objects,
     call the getNewManagedObjectContextForLongRunningTask(), getNewManagedObjectContextForBatchTask()
     or getNewManagedObjectContext() methods instead.
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
     Call this method to get a NSManagedObjectContext object in order to execute some operations in background.
     
     - returns: the new NSManagedObjectContext used to update/create some NSManagedObject objects.
     */
    public func getNewManagedObjectContextForBackgroundTask() -> NSManagedObjectContext {
        return getNewManagedObjectContextBoundToWriterContext(true)
    }
    
    /**
     Create a new NSManagedObjectContext object bound to the batchPersistentStoreCoodinator object.
     Call this method to get a NSManagedObjectContext object in order to execute a large amount of CoreData operations
     like import, deleting, etc. You must refetch from the defaultManagedObjectContext object to see the changes.
     
     - returns: the new NSManagedObjectContext used to update/create some NSManagedObject objects.
     */
    public func getNewManagedObjectContextForBatchTask() -> NSManagedObjectContext {
        let context = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.PrivateQueueConcurrencyType)
        context.persistentStoreCoordinator = batchPersistentStoreCoodinator
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.undoManager = nil
        
        return context
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
            defaultManagedObjectContext.performBlock { [unowned self] in
                do {
                    try self.defaultManagedObjectContext.save()
                }
                catch let e {
                    fatalError("Can not save the context: \(e)")
                }
            }
        }
    }
    
    /**
     Call this method to save the changes to persistent store.
     This must be called in the 'applicationWillTerminate' and/or 'applicationWillResignActive' methods.
     
     - throws: save operations can throw errors.
     */
    public func saveContexts() throws {
        let saveContext = { (context: NSManagedObjectContext) in
            context.performBlock {
                do {
                    try context.save()
                }
                catch let e {
                    fatalError("Can not save the context: \(e)")
                }
            }
        }
        
        saveContext(defaultManagedObjectContext)
        saveContext(writerManagedObjectContext)
    }
    
    /**
     Shorthand method to create a NSManagedObjectContext object, to perform block, to save the context and to perform a block in the main thread.
     
     - parameter contextBlock: the block to perform with the NSManagedObjectContext object, the save block is passed in argument.
     - parameter mainThreadBlock: the block to save the NSManagedObjectContext object.
     */
    public func performBlockInContext(contextBlock: (NSManagedObjectContext -> Void), andInMainThread mainThreadBlock:(() -> Void)? = nil) {
        let context = getNewManagedObjectContext()
        performBlock(contextBlock, orContextBlockForBackgroundTask: nil, inContext: context, wait: false, andInMainThread: mainThreadBlock)
    }
    
    /**
     Shorthand method to create a NSManagedObjectContext object, to perform block and to wait it ends, to save the context and to perform a block in the main thread.
     
     - parameter contextBlock: the block to perform with the NSManagedObjectContext object, the save block is passed in argument.
     - parameter mainThreadBlock: the block to save the NSManagedObjectContext object.
     */
    public func performBlockAndWaitInContext(contextBlock: (NSManagedObjectContext -> Void), andInMainThread mainThreadBlock:(() -> Void)? = nil) {
        let context = getNewManagedObjectContext()
        performBlock(contextBlock, orContextBlockForBackgroundTask: nil, inContext: context, wait: true, andInMainThread: mainThreadBlock)
    }
    
    /**
     Shorthand method to create a NSManagedObjectContext object, to perform block, to save the context and to perform a block in the main thread.
     
     - parameter contextBlock: the block to perform with the NSManagedObjectContext object.
     - parameter mainThreadBlock: the block to save the NSManagedObjectContext object.
     */
    public func performBlockInContextForBackgroundTask(contextBlock: ((context: NSManagedObjectContext, saveBlock: ((Bool) -> ErrorType?)) -> Void), andInMainThread mainThreadBlock:(() -> Void)? = nil) {
        let context = getNewManagedObjectContextForBackgroundTask()
        performBlock(nil, orContextBlockForBackgroundTask: contextBlock, inContext: context, wait: false, andInMainThread: mainThreadBlock)
    }
    
    /**
     Shorthand method to create a NSManagedObjectContext object, to perform block and to wait it ends, to save the context and to perform a block in the main thread.
     
     - parameter contextBlock: the block to perform with the NSManagedObjectContext object.
     - parameter mainThreadBlock: the block to save the NSManagedObjectContext object.
     */
    public func performBlockAndWaitInContextForBackgroundTask(contextBlock: ((context: NSManagedObjectContext, saveBlock: ((Bool) -> ErrorType?)) -> Void), andInMainThread mainThreadBlock:(() -> Void)? = nil) {
        let context = getNewManagedObjectContextForBackgroundTask()
        performBlock(nil, orContextBlockForBackgroundTask: contextBlock, inContext: context, wait: true, andInMainThread: mainThreadBlock)
    }
    
    /**
     Shorthand method to create a NSManagedObjectContext object, to perform block, to save the context and to perform a block in the main thread.
     
     - parameter contextBlock: the block to perform with the NSManagedObjectContext object.
     - parameter mainThreadBlock: the block to save the NSManagedObjectContext object.
     */
    public func performBlockInContextForBatchTask(contextBlock: ((context: NSManagedObjectContext, saveBlock: (() -> ErrorType?)) -> Void), andInMainThread mainThreadBlock:(() -> Void)? = nil) {
        performBlockForBatchTask(contextBlock, wait: false, andInMainThread: mainThreadBlock)
    }
    
    /**
     Shorthand method to create a NSManagedObjectContext object, to perform block and to wait it ends, to save the context and to perform a block in the main thread.
     
     - parameter contextBlock: the block to perform with the NSManagedObjectContext object.
     - parameter mainThreadBlock: the block to save the NSManagedObjectContext object.
     */
    public func performBlockAndWaitInContextForBatchTask(contextBlock: ((context: NSManagedObjectContext, saveBlock: (() -> ErrorType?)) -> Void), andInMainThread mainThreadBlock:(() -> Void)? = nil) {
        performBlockForBatchTask(contextBlock, wait: true, andInMainThread: mainThreadBlock)
    }
    
    
    // MARK: - Private methods
    
    /**
     Create a new NSManagedObjectContext object bound or not to the writerManagedObjectContext object.
     
     - parameter boundToWriterContext: bool to know if this NSManagedObjectContext object must be bound to the writerManagedObjectContext object.
     - returns: the new NSManagedObjectContext used to update/create some NSManagedObject objects.
     */
    private func getNewManagedObjectContextBoundToWriterContext(boundToWriterContext: Bool) -> NSManagedObjectContext {
        let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.undoManager = nil
        
        context.parentContext = boundToWriterContext ? writerManagedObjectContext : defaultManagedObjectContext
        
        return context
    }
    
    /**
     Shorthand method to create a NSManagedObjectContext object, perform block, save the context and perform a block in the main thread.
     
     - parameter contextBlock: the block to perform with the NSManagedObjectContext object.
     - parameter contextBlockForBackgroundTask: the block to perform with the NSManagedObjectContext object, the save block is passed in argument.
     - parameter context: the NSManagedObjectContext object.
     - parameter wait: flag to set the contextBlock blocking or not the thread.
     - parameter mainThreadBlock: the block to save the NSManagedObjectContext object.
     */
    private func performBlock(contextBlock: (NSManagedObjectContext -> Void)?, orContextBlockForBackgroundTask contextBlockForBackgroundTask: ((context: NSManagedObjectContext, saveBlock: ((Bool) -> ErrorType?)) -> Void)?, inContext context:NSManagedObjectContext, wait: Bool, andInMainThread mainThreadBlock:(() -> Void)?) {
        // Define the block which saves the context.
        let saveBlock : ((Bool) -> ErrorType?) = { [unowned self] mergeChangesInDefaultManagedObjectContext in
            var error: ErrorType?
            
            do {
                if mergeChangesInDefaultManagedObjectContext {
                    NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.mergeChanges), name: NSManagedObjectContextDidSaveNotification, object: context)
                }
                try self.saveContext(context)
            }
            catch let e {
                error = e
            }
            
            if mergeChangesInDefaultManagedObjectContext {
                NSNotificationCenter.defaultCenter().removeObserver(self, name: NSManagedObjectContextDidSaveNotification, object: context)
            }
            
            return error
        }
        
        // Perform the block with the context.
        let blockToPerform = {
            if let contextBlock = contextBlock {
                contextBlock(context)
            }
            else if let contextBlock = contextBlockForBackgroundTask {
                contextBlock(context: context, saveBlock: saveBlock)
            }
            
            saveBlock(false)
            
            if let mainThreadBlock = mainThreadBlock {
                dispatch_async(dispatch_get_main_queue(), mainThreadBlock)
            }
        }
        
        if wait {
            context.performBlockAndWait(blockToPerform)
        }
        else {
            context.performBlock(blockToPerform)
        }
    }
    
    /**
     Shorthand method to create a NSManagedObjectContext object, to perform block, to save the context and to perform a block in the main thread.
     
     - parameter contextBlock: the block to perform with the NSManagedObjectContext object.
     - parameter wait: flag to set the contextBlock blocking or not the thread.
     - parameter mainThreadBlock: the block to save the NSManagedObjectContext object.
     */
    private func performBlockForBatchTask(contextBlock: ((context: NSManagedObjectContext, saveBlock: (() -> ErrorType?)) -> Void), wait: Bool, andInMainThread mainThreadBlock:(() -> Void)? = nil) {
        // Get a new context.
        let context = getNewManagedObjectContextForBatchTask()
        
        // Define the block which saves the context.
        let saveBlock : (() -> ErrorType?) = { [unowned self] in
            var error: ErrorType?
            
            do {
                try self.saveContext(context)
            }
            catch let e {
                error = e
            }
            
            return error
        }
        
        // Perform the block with the context.
        let blockToPerform = {
            contextBlock(context: context, saveBlock: saveBlock)
            saveBlock()
            
            if let mainThreadBlock = mainThreadBlock {
                dispatch_async(dispatch_get_main_queue(), mainThreadBlock)
            }
        }
        
        if wait {
            context.performBlockAndWait(blockToPerform)
        }
        else {
            context.performBlock(blockToPerform)
        }
    }
    
    /**
     Merges the changes from a NSManagedObjectContext object to the defaultManagedObjectContext object.
     
     - parameter notification: notification containing hte changes sent by the NSManagedObjectContext object.
     */
    @objc private func mergeChanges(notification: NSNotification) {
        if let sender = notification.object as? NSManagedObjectContext where sender != defaultManagedObjectContext && sender != writerManagedObjectContext && sender.parentContext == writerManagedObjectContext {
            defaultManagedObjectContext.performBlock { [unowned self] in
                self.defaultManagedObjectContext.mergeChangesFromContextDidSaveNotification(notification)
            }
        }
    }
    
    
    // MARK: - Lifecycle
    
    /**
     Create a new CoreDataStack object.
     
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
            }
            catch let error {
                fatalError("Can not create the persistent store coordinator directory: \(error).")
            }
        }
        
        defaultPersistentStoreCoodinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
        batchPersistentStoreCoodinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
        
        do {
            let storeURL = NSURL(fileURLWithPath: directoryPath).URLByAppendingPathComponent(persistentFileName)
            try defaultPersistentStoreCoodinator.addPersistentStoreWithType(persistentStoreType, configuration: persistentStoreConfigration, URL: storeURL, options: persistentStoreOptions)
            try batchPersistentStoreCoodinator.addPersistentStoreWithType(persistentStoreType, configuration: persistentStoreConfigration, URL: storeURL, options: persistentStoreOptions)
        }
        catch let error {
            fatalError("Can not create the persistent store coordinator file: \(error).")
        }
        
        // Create the writer managed object context.
        writerManagedObjectContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.PrivateQueueConcurrencyType)
        writerManagedObjectContext.undoManager = nil
        writerManagedObjectContext.persistentStoreCoordinator = defaultPersistentStoreCoodinator
        
        // Create the default managed object contexte.
        defaultManagedObjectContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.MainQueueConcurrencyType)
        defaultManagedObjectContext.undoManager = nil
        defaultManagedObjectContext.parentContext = writerManagedObjectContext
    }
}

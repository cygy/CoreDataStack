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
     See Apple documentation to have more details: https://developer.apple.com/library/ios/documentation/Cocoa/Conceptual/CoreData/index.html#//apple_ref/doc/uid/TP40001075
     */
    private let model: NSManagedObjectModel
    private let defaultCoodinator: NSPersistentStoreCoordinator
    private let batchCoodinator: NSPersistentStoreCoordinator
    
    /**
     This NSManagedObjectContext object is responsible to write to the persistent store.
     */
    private let writerContext: NSManagedObjectContext
    
    /**
     This NSManagedObjectContext object is the main context, running into the main thread.
     Use it with the NSFetchedResultsController objects.
     It will not write directly to the store, this is delegated to the writerManagedObjectContext object.
     Do not use this context directly to update/delete/create NSManagedObject objects,
     call the newContextForBackgroundTask(), newContextForBatchTask()
     or newContext() methods instead.
     */
    public let defaultContext: NSManagedObjectContext
    
    
    // MARK: - Methods
    
    /**
     Create a new NSManagedObjectContext object bound to the defaultManagedObjectContext object.
     Call this method to get a NSManagedObjectContext object in order to execute a small amount of CoreData operations.
     
     - returns: the new NSManagedObjectContext used to update/create some NSManagedObject objects.
     */
    public func newContext() -> NSManagedObjectContext {
        return newContext(boundToWriterContext: false)
    }
    
    /**
     Create a new NSManagedObjectContext object bound to the writerManagedObjectContext object directly.
     Call this method to get a NSManagedObjectContext object in order to execute some operations in background.
     
     - returns: the new NSManagedObjectContext used to update/create some NSManagedObject objects.
     */
    public func newContextForBackgroundTask() -> NSManagedObjectContext {
        return newContext(boundToWriterContext: true)
    }
    
    /**
     Create a new NSManagedObjectContext object bound to the batchPersistentStoreCoodinator object.
     Call this method to get a NSManagedObjectContext object in order to execute a large amount of CoreData operations
     like import, deleting, etc. You must refetch from the defaultManagedObjectContext object to see the changes.
     
     - returns: the new NSManagedObjectContext used to update/create some NSManagedObject objects.
     */
    public func newContextForBatchTask() -> NSManagedObjectContext {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = batchCoodinator
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.undoManager = nil
        
        return context
    }
    
    /**
     Call this method to save the changes to persistent store.
     This must be called in the 'applicationWillTerminate' and/or 'applicationWillResignActive' methods.
     
     - throws: save operations can throw errors.
     */
    public func saveContexts() {
        let context = defaultContext
        context.perform {
            context.saveToParent()
        }
    }
    
    /**
     Shorthand method to create a NSManagedObjectContext object, to perform block, to save the context and to perform a block in the main thread.
     
     - parameter contextBlock: the block to perform with the NSManagedObjectContext object, the save block is passed in argument.
     - parameter mainThreadBlock: the block to save the NSManagedObjectContext object.
     */
    public func perform(inContext contextBlock: @escaping ((NSManagedObjectContext) -> Void), andInMainThread mainThreadBlock:(() -> Void)? = nil) {
        let context = newContext()
        perform(contextBlock: contextBlock, orContextBlockForBackgroundTask: nil, inContext: context, wait: false, andInMainThread: mainThreadBlock)
    }
    
    /**
     Shorthand method to create a NSManagedObjectContext object, to perform block and to wait it ends, to save the context and to perform a block in the main thread.
     
     - parameter contextBlock: the block to perform with the NSManagedObjectContext object, the save block is passed in argument.
     - parameter mainThreadBlock: the block to save the NSManagedObjectContext object.
     */
    public func performAndWait(inContext contextBlock: @escaping ((NSManagedObjectContext) -> Void), andInMainThread mainThreadBlock:(() -> Void)? = nil) {
        let context = newContext()
        perform(contextBlock: contextBlock, orContextBlockForBackgroundTask: nil, inContext: context, wait: true, andInMainThread: mainThreadBlock)
    }
    
    /**
     Shorthand method to create a NSManagedObjectContext object, to perform block, to save the context and to perform a block in the main thread.
     
     - parameter contextBlock: the block to perform with the NSManagedObjectContext object.
     - parameter mainThreadBlock: the block to save the NSManagedObjectContext object.
     */
    public func performBackgroundTask(inContext contextBlock: @escaping ((NSManagedObjectContext, ((Bool) -> Error?)) -> Void), andInMainThread mainThreadBlock:(() -> Void)? = nil) {
        let context = newContextForBackgroundTask()
        perform(contextBlock: nil, orContextBlockForBackgroundTask: contextBlock, inContext: context, wait: false, andInMainThread: mainThreadBlock)
    }
    
    /**
     Shorthand method to create a NSManagedObjectContext object, to perform block and to wait it ends, to save the context and to perform a block in the main thread.
     
     - parameter contextBlock: the block to perform with the NSManagedObjectContext object.
     - parameter mainThreadBlock: the block to save the NSManagedObjectContext object.
     */
    public func performAndWaitBackgroundTask(inContext contextBlock: @escaping ((NSManagedObjectContext, ((Bool) -> Error?)) -> Void), andInMainThread mainThreadBlock:(() -> Void)? = nil) {
        let context = newContextForBackgroundTask()
        perform(contextBlock: nil, orContextBlockForBackgroundTask: contextBlock, inContext: context, wait: true, andInMainThread: mainThreadBlock)
    }
    
    /**
     Shorthand method to create a NSManagedObjectContext object, to perform block, to save the context and to perform a block in the main thread.
     
     - parameter contextBlock: the block to perform with the NSManagedObjectContext object.
     - parameter mainThreadBlock: the block to save the NSManagedObjectContext object.
     */
    public func performBatchTask(inContext contextBlock: @escaping ((NSManagedObjectContext, (() -> Error?)) -> Void), andInMainThread mainThreadBlock:(() -> Void)? = nil) {
        performBlockForBatchTask(contextBlock, wait: false, andInMainThread: mainThreadBlock)
    }
    
    /**
     Shorthand method to create a NSManagedObjectContext object, to perform block and to wait it ends, to save the context and to perform a block in the main thread.
     
     - parameter contextBlock: the block to perform with the NSManagedObjectContext object.
     - parameter mainThreadBlock: the block to save the NSManagedObjectContext object.
     */
    public func performAndWaitBatchTask(inContext contextBlock: @escaping ((NSManagedObjectContext, (() -> Error?)) -> Void), andInMainThread mainThreadBlock:(() -> Void)? = nil) {
        performBlockForBatchTask(contextBlock, wait: true, andInMainThread: mainThreadBlock)
    }
    
    
    // MARK: - Private methods
    
    /**
     Create a new NSManagedObjectContext object bound or not to the writerManagedObjectContext object.
     
     - parameter boundToWriterContext: bool to know if this NSManagedObjectContext object must be bound to the writerManagedObjectContext object.
     - returns: the new NSManagedObjectContext used to update/create some NSManagedObject objects.
     */
    fileprivate func newContext(boundToWriterContext bound: Bool) -> NSManagedObjectContext {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.undoManager = nil
        
        context.parent = bound ? writerContext : defaultContext
        
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
    fileprivate func perform(contextBlock: ((NSManagedObjectContext) -> Void)?, orContextBlockForBackgroundTask contextBlockForBackgroundTask: ((_ context: NSManagedObjectContext, _ saveBlock: ((Bool) -> Error?)) -> Void)?, inContext context:NSManagedObjectContext, wait: Bool, andInMainThread mainThreadBlock:(() -> Void)?) {
        // Define the block which saves the context.
        let saveBlock : ((Bool) -> Error?) = { [unowned self] mergeChangesInDefaultManagedObjectContext in
            if mergeChangesInDefaultManagedObjectContext {
                NotificationCenter.default.addObserver(self, selector: #selector(self.mergeChanges), name: NSNotification.Name.NSManagedObjectContextDidSave, object: context)
            }
            
            let error = context.saveToParent()
            
            if mergeChangesInDefaultManagedObjectContext {
                NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NSManagedObjectContextDidSave, object: context)
            }
            
            return error
        }
        
        // Perform the block with the context.
        let blockToPerform = {
            if let contextBlock = contextBlock {
                contextBlock(context)
            }
            else if let contextBlock = contextBlockForBackgroundTask {
                contextBlock(context, saveBlock)
            }
            
            saveBlock(false)
            
            if let mainThreadBlock = mainThreadBlock {
                DispatchQueue.main.async(execute: mainThreadBlock)
            }
        }
        
        if wait {
            context.performAndWait(blockToPerform)
        }
        else {
            context.perform(blockToPerform)
        }
    }
    
    /**
     Shorthand method to create a NSManagedObjectContext object, to perform block, to save the context and to perform a block in the main thread.
     
     - parameter contextBlock: the block to perform with the NSManagedObjectContext object.
     - parameter wait: flag to set the contextBlock blocking or not the thread.
     - parameter mainThreadBlock: the block to save the NSManagedObjectContext object.
     */
    fileprivate func performBlockForBatchTask(_ contextBlock: @escaping ((_ context: NSManagedObjectContext, _ saveBlock: (() -> Error?)) -> Void), wait: Bool, andInMainThread mainThreadBlock:(() -> Void)? = nil) {
        // Get a new context.
        let context = newContextForBatchTask()
        
        // Define the block which saves the context and its parents.
        let saveBlock : (() -> Error?) = {
            return context.saveToParent()
        }
        
        // Perform the block with the context.
        let blockToPerform = {
            contextBlock(context, saveBlock)
            saveBlock()
            
            if let mainThreadBlock = mainThreadBlock {
                DispatchQueue.main.async(execute: mainThreadBlock)
            }
        }
        
        if wait {
            context.performAndWait(blockToPerform)
        }
        else {
            context.perform(blockToPerform)
        }
    }
    
    /**
     Merges the changes from a NSManagedObjectContext object to the defaultManagedObjectContext object.
     
     - parameter notification: notification containing hte changes sent by the NSManagedObjectContext object.
     */
    @objc fileprivate func mergeChanges(fromNotification notification: Notification) {
        if let sender = notification.object as? NSManagedObjectContext , sender != defaultContext && sender != writerContext && sender.parent == writerContext {
            let context = defaultContext
            context.perform {
                context.mergeChanges(fromContextDidSave: notification)
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
     - parameter bundle: bundle where the .momd files are, useful for the unit tests, you will never use it.
     - returns: the new NSManagedObjectContext used to update/create some NSManagedObject objects.
     */
    public init(modelFileNames: [String], persistentFileName: String, persistentStoreType: String = NSSQLiteStoreType, persistentStoreConfigration: String? = nil, persistentStoreOptions: [String:AnyObject]? = [NSMigratePersistentStoresAutomaticallyOption: true as AnyObject, NSInferMappingModelAutomaticallyOption: true as AnyObject], bundle: Bundle = Bundle.main) {
        // Create the managed object model.
        var models = [NSManagedObjectModel]()
        for modelFileName in modelFileNames {
            guard let path = bundle.path(forResource: modelFileName, ofType: "momd") else {
                fatalError("Can not create managed object model with name: \(modelFileName)")
            }
            
            guard let model = NSManagedObjectModel(contentsOf: URL(fileURLWithPath: path)) else {
                fatalError("Can not create managed object model from path: \(path)")
            }
            
            models.append(model)
        }
        
        guard let objectModel = NSManagedObjectModel(byMerging: models) else {
            fatalError("Can not merge the managed object models")
        }
        
        model = objectModel
        
        // Create the persistent store coordinator.
        guard let directoryPath = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first else {
            fatalError("Can not initialize the persistent store coordinator.")
        }
        
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: directoryPath) {
            do {
                try fileManager.createDirectory(atPath: directoryPath, withIntermediateDirectories: true, attributes: nil)
            }
            catch let error {
                fatalError("Can not create the persistent store coordinator directory: \(error).")
            }
        }
        
        defaultCoodinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        batchCoodinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        
        do {
            let storeURL = URL(fileURLWithPath: directoryPath).appendingPathComponent(persistentFileName)
            try defaultCoodinator.addPersistentStore(ofType: persistentStoreType, configurationName: persistentStoreConfigration, at: storeURL, options: persistentStoreOptions)
            try batchCoodinator.addPersistentStore(ofType: persistentStoreType, configurationName: persistentStoreConfigration, at: storeURL, options: persistentStoreOptions)
        }
        catch let error {
            fatalError("Can not create the persistent store coordinator file: \(error).")
        }
        
        // Create the writer managed object context.
        writerContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        writerContext.persistentStoreCoordinator = defaultCoodinator
        writerContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        writerContext.undoManager = nil
        
        // Create the default managed object contexte.
        defaultContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        defaultContext.parent = writerContext
        defaultContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        defaultContext.undoManager = nil
    }
}

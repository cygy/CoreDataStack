//
//  CoreDataStack.swift
//  CoreDataStack
//
//  Created by Cyril on 05/09/2016.
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

/**
 This extension defines a extra function to the NSManagedObjectContext objects
 in order to save the context and its parents.
 */
extension NSManagedObjectContext {
    
    /**
     Asynchronously save the changes of the context to its parent(s).
     Use this method with the NSManagedObject contexts bound to the main thread.
     */
    public func saveToParents(withCompletion completion: ((Error?) -> Void)?) {
        // A completion block is defined to call the original completion block into the main thread.
        let completionInMainThread: (Error?) -> Void = { error in
            if let completion = completion {
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
        
        // If the context has no changes no need to continue.
        guard hasChanges else {
            completionInMainThread(nil)
            return
        }
        
        do {
            try save()
            
            // If this context has no parent no need to continue.
            guard let parent = parent else {
                completionInMainThread(nil)
                return
            }
            
            // Now save to its parent context.
            parent.perform {
                parent.saveToParents(withCompletion: completion)
            }
        }
        catch let e {
            completionInMainThread(e)
        }
    }
    
    /**
     Synchronously save the changes of the context to its parent(s)
     */
    public func saveToParentsAndWait() -> Error? {
        // If the context has no changes no need to continue.
        guard hasChanges else {
            return nil
        }
        
        do {
            try save()
            
            // If this context has no parent no need to continue.
            guard let parent = parent else {
                return nil
            }
            
            // Now save to its parent context.
            var error: Error?
            parent.performAndWait {
                error = parent.saveToParentsAndWait()
            }
            
            return error
        }
        catch let e {
            return e
        }
    }
}

//
//  ViewController.swift
//  CoreDataStack-Example
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

import UIKit
import CoreData

class ViewController: UITableViewController, NSFetchedResultsControllerDelegate {
    
    let coreDataStack = (UIApplication.sharedApplication().delegate as! AppDelegate).coreDataStack
    
    /*
     In this example, the NSFetchedResultsController is using the defaultManagedObjectContext object
     of the main CoreDataStask object which is bound to the main thread.
     The defaultManagedObjectContext is mainly used to 'pull' and 'read' the objects.
     */
    lazy private var fetchedResultsController: NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "Person")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "lastName", ascending: true), NSSortDescriptor(key: "firstName", ascending: true)]
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.coreDataStack.defaultManagedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController.delegate = self
        
        return fetchedResultsController
    }()
    
    /*
     The persons are generated from scratch to a ManagedObjectContext object bound to a background thread
     and they are loaded from the defaultManagedObjectContext object which is bound to the main thread.
     */
    @IBAction func refreshPersons(sender: UIRefreshControl) {
        coreDataStack.performBlockInContextForLongRunningTask({ (context, saveBlock) in
            for i in 0...10000 {
                let person = NSEntityDescription.insertNewObjectForEntityForName("Person", inManagedObjectContext: context) as! Person
                person.firstName = "John\(i)"
                person.lastName = "Doe\(i)"
                
                if i%1000 == 0 {
                    if let error = saveBlock() {
                        print("Can not save the context: \(error)")
                    }
                }
            }
            }) { 
                self.fetch()
                self.tableView.reloadData()
                sender.endRefreshing()
        }
    }
    
    /*
     A single persons is generated to a ManagedObjectContext object bound to a background thread
     which its parent context is the defaultManagedObjectContext object which is bound to the main thread.
     */
    @IBAction func addPerson(sender: UIBarButtonItem) {
        coreDataStack.performBlockInContext({ context in
            let person = NSEntityDescription.insertNewObjectForEntityForName("Person", inManagedObjectContext: context) as! Person
            person.firstName = "John00"
            person.lastName = "Doe00"
        }) {}
    }
    
    private func fetch() {
        do {
            try self.fetchedResultsController.performFetch()
        } catch let e {
            print("Can not load the persons: \(e)")
        }
    }
    
    private func configureCell(cell: UITableViewCell, indexPath: NSIndexPath) {
        let person = fetchedResultsController.objectAtIndexPath(indexPath) as! Person
        cell.textLabel?.text = "\(person.firstName!) \(person.lastName!)"
    }
    
    /*
     Table view related methods
     */
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        if let sections = fetchedResultsController.sections {
            return sections.count
        }
        
        return 0
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let sections = fetchedResultsController.sections {
            return sections[section].numberOfObjects
        }
        
        return 0
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("personCell", forIndexPath: indexPath)
        configureCell(cell, indexPath: indexPath)
        
        return cell
    }
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Save the ID of the object to delete.
            // Do not forget that the NSManagedObject objects can not be passed through distinct threads, use the objectID instead.
            let objectID = self.fetchedResultsController.objectAtIndexPath(indexPath).objectID
            
            // Here a single object is deleted, so a managed object context directly bound to the defaultManagedObjectContext is used.
            coreDataStack.performBlockInContext({ context in
                let objectToDelete = context.objectWithID(objectID)
                context.deleteObject(objectToDelete)
            }) {}
        }
    }
    
    /*
     NSFetchedResultsController related methods
     */
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        tableView.beginUpdates()
    }
    
    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        switch type {
        case .Insert:
            tableView.insertSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
        case .Delete:
            tableView.deleteSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
        case .Move:
            break
        case .Update:
            break
        }
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type {
        case .Insert:
            tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
        case .Delete:
            tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
        case .Update:
            configureCell(self.tableView.cellForRowAtIndexPath(indexPath!)!, indexPath: indexPath!)
        case .Move:
            tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
            tableView.insertRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        tableView.endUpdates()
    }
    
    /*
     UIViewController related methods
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.fetch()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}


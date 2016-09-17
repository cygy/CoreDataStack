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
import Foundation

class ViewController: UITableViewController, NSFetchedResultsControllerDelegate {
    
    private let coreDataStack = (UIApplication.shared.delegate as! AppDelegate).coreDataStack
    
    /*
     In this example, the NSFetchedResultsController is using the defaultManagedObjectContext object
     of the main CoreDataStask object which is bound to the main thread.
     The defaultManagedObjectContext is mainly used to 'pull' and 'read' the objects.
     */
    lazy private var fetchedResultsController: NSFetchedResultsController<Person> = {
        let fetchRequest = NSFetchRequest<Person>(entityName: "Person")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "lastName", ascending: true), NSSortDescriptor(key: "firstName", ascending: true)]
        
        let fetchedResultsController = NSFetchedResultsController<Person>(fetchRequest: fetchRequest, managedObjectContext: self.coreDataStack.defaultContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController.delegate = self
        return fetchedResultsController
    }()
    
    /*
     The persons are generated from scratch to a ManagedObjectContext object bound to a background thread
     and they are loaded from the defaultManagedObjectContext object which is bound to the main thread.
     */
    @IBAction func refreshPersons(_ sender: UIRefreshControl) {
        coreDataStack.performBatchTask(inContext: { (context, saveBlock) in
            for i in 0...10000 {
                let person = NSEntityDescription.insertNewObject(forEntityName: "Person", into: context) as! Person
                person.firstName = "John\(i)"
                person.lastName = "Doe\(i)"
                
                if i%1000 == 0 {
                    if let error = saveBlock() {
                        debugPrint("Can not save the context: \(error)")
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
    @IBAction func addPerson(_ sender: UIBarButtonItem) {
        coreDataStack.perform(inContext: { context in
            let person = NSEntityDescription.insertNewObject(forEntityName: "Person", into: context) as! Person
            person.firstName = "John00"
            person.lastName = "Doe00"
        }) {}
    }
    
    private func fetch() {
        do {
            try fetchedResultsController.performFetch()
        }
        catch let e {
            debugPrint("Can not load the persons: \(e)")
        }
    }
    
    private func configure(cell: UITableViewCell, at indexPath: IndexPath) {
        let person = fetchedResultsController.object(at: indexPath)
        
        if let firstName = person.firstName, let lastName = person.lastName {
            cell.textLabel?.text = "\(firstName) \(lastName)"
        }
        else {
            cell.textLabel?.text = "Unknown"
        }
    }
    
    /*
     Table view related methods
     */
    override func numberOfSections(in tableView: UITableView) -> Int {
        if let sections = fetchedResultsController.sections {
            return sections.count
        }
        
        return 0
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let sections = fetchedResultsController.sections {
            return sections[section].numberOfObjects
        }
        
        return 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "personCell", for: indexPath)
        configure(cell: cell, at: indexPath)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Save the ID of the object to delete.
            // Do not forget that the NSManagedObject objects can not be passed through distinct threads, use the objectID instead.
            let objectID = fetchedResultsController.object(at: indexPath).objectID
            
            // Here a single object is deleted, so a managed object context directly bound to the defaultManagedObjectContext is used.
            coreDataStack.perform(inContext: { context in
                let object = context.object(with: objectID)
                context.delete(object)
            }) {}
        }
    }
    
    /*
     NSFetchedResultsController related methods
     */
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
        case .delete:
            tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
        case .move:
            break
        case .update:
            break
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            tableView.insertRows(at: [newIndexPath!], with: .fade)
        case .delete:
            tableView.deleteRows(at: [indexPath!], with: .fade)
        case .update:
            configure(cell: tableView.cellForRow(at: indexPath!)!, at: indexPath!)
        case .move:
            tableView.deleteRows(at: [indexPath!], with: .fade)
            tableView.insertRows(at: [newIndexPath!], with: .fade)
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
    
    /*
     UIViewController related methods
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        fetch()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}


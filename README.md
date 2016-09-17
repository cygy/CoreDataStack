# CoreDataStack

Helper to set up a CoreData stack, fetch, create and save `NSManagedObject` objects for your iOS/tvOS/watchOS/OSX projects.
You continue using `NSManagedObject`, `NSFetchedResultsController` classes... Not magic, just a helper :)

`CoreDataStack` instances provide a default `NSManagedObjectContext` object to use with the `NSFetchedResultsController` objects.
`CoreDataStack` instances provide also convenient methods to execute the recurring pattern: create a `NSManagedObjectContext` object, create  some `NSManagedObject` objects, save them and update the user interface in the main thread.

> **The syntax from the version 2.0 is not compatible with the syntax from version < 2.0.**
> **Swift 3 is supported since the version 2.0. To use it with Swift 2 use the version 1.6.2.**

Example:

```swift
import CoreDataStack

// The first block is used to perform actions on the context's thread.
// This block provides a context and save it.
// The second block is used to update the user interface, it runs on the main thread.
myStack.perform(inContext: { context in
    let person = NSEntityDescription.insertNewObject(forEntityName: "Person", into: context) as! Person
    person.firstName = "John"
    person.lastName = "Doe"
}) {
    self.tableView.reloadData()
}
```

## Platforms

iOS, OSX, tvOS, watchOS

## Requirements

### System

- iOS 9.0+ / Mac OS X 10.10+ / tvOS 9.0+ / watchOS 2.0+
- Xcode 7.3+

## Installation

> **Embedded frameworks require a minimum deployment target of iOS 8.0 or OS X Yosemite (10.9).**

### Carthage

- You can install [Carthage](https://github.com/Carthage/Carthage) with [Homebrew](http://brew.sh/):

```bash
$ sudo brew update
$ sudo brew install carthage
```

- Create a [Cartfile](https://github.com/Carthage/Carthage/blob/master/Documentation/Artifacts.md#cartfile) at the root of your Xcode project:

```bash
github "cygy/CoreDataStack"
```

- Run the command `carthage update`, the CoreDataStack framework will be downloaded and built.

- Drag the files `Carthage/Build/[platform]/*.framework` into your Xcode project.

- Go to the "Build Phases" panel, create a Run Script with the following contents:

```bash
/usr/local/bin/carthage copy-frameworks
```

and add the paths to the frameworks under “Input Files”, e.g.:

```
$(SRCROOT)/Carthage/Build/iOS/CoreDataStack.framework
```

### Manually (embedded framework)

- Your project must be initialized as a git repository, if not open up a Terminal console, go to your project folder:

```bash
$ git init
```

- Add CoreDataStack as a git [submodule](http://git-scm.com/docs/git-submodule).

```bash
$ git submodule add https://github.com/cygy/CoreDataStack.git
$ git submodule update --init --recursive
```

- Drag the file `CoreDataStack/CoreDataStack.xcodeproj` into the Project Navigator of your application's Xcode project.

- Go to the "General" panel and for each target of your project, add the corresponding `CoreDataStack.framework` as an "Embedding Binaries".

- The framework must appear under the sections "Embedding Binaries" and "Linked Frameworks and Libraries".

- Go to the "Build Phases" panel, the framework must appear under the sections "Target dependencies" and "Embed Frameworks".

- Done! Now you can compile your project with CoreDataStack as a dependency.

## Usage

### Initialize a CoreDataStack object

```swift
import CoreDataStack

let myStack = CoreDataStack(modelFileNames: ["CoreDataStack_Example"], persistentFileName: "example.sqlite")
```

You pass the names of the .mom files (without the extension) as arguments. CoreDataStack will create the model by merging the .mom files.
The second argument is the name of the persistent file.
The other arguments are optional (see code source)

> Each file name must be passed as argument. By experience I do not recommend to automatically merge all the .mom files in the bundle.

### Pull and display objects in UI from CoreData

To pull and display objects from CoreData, use the `defaultContext` property of `CoreDataStack`, i.e. with the `NSFetchedResultsController` objects. As the `defaultContext` is using the main thread it is fit to be used with the UI objects like the `UITableView` objects.

```swift
import CoreDataStack

let fetchedResultsController = NSFetchedResultsController<MyObject>(fetchRequest: fetchRequest, managedObjectContext: myStack.defaultContext, sectionNameKeyPath: nil, cacheName: nil)
```

### Execute a few operations on NSManagedObject objects

If you want to do a few operations on `NSManagedObject` objects (like create one object, or delete one object) use a simple `NSManagedObjectContext` for this task.
Execute your tasks and save the context. The changes will be updated to the `defaultContext` object too.

```swift
import CoreDataStack

let context = myStack.newContext()

context.perform {
    // Do your operations here.
    ...

    // Save the context.
    if let error = context.saveToParent() {
        // Handle error here.
        ...
    }
}
```

This shorthand is equivalent:

```swift
import CoreDataStack

myStack.perform(inContext: { context in
    // Do your operations here.
    ...

    // The context is saved at the end of this block, no need to call the `saveToParent` method.
}) {
    // This block is run after the first block is done and the context is saved.
    // This block is run in the main thread and can be used to update the UI.
    ...
}
```

> Behind the scene, a `NSManagedObjectContext` object that its parent context is the `defaultContext` object is created.

### Execute operations on NSManagedObject objects on background

If you want to do operations on `NSManagedObject` objects on a background thread, use a dedicated `NSManagedObjectContext` for this task.
Once the operations are done, you have to refresh to `defaultContext` to update the UI (i.e. refetch from `NSFetchedResultsController` objects).

```swift
import CoreDataStack

let context = myStack.newContextForBackgroundTask()

context.perform {
    // Do your operations here.
    ...

    // Save the context.
    if let error = context.saveToParent() {
        // Handle error here.
        ...
    }

    // Now update the 'defaultContext' object.
    OperationQueue.main.addOperation {
        do {
            try fetchedResultsController.performFetch()
        }
        catch let e {
            // Handle error here.
        }
    }
}
```

This shorthand is equivalent:

```swift
import CoreDataStack

myStack.performBackgroundTask(inContext: { (context, saveBlock) in
    // Do your operations here.
    ...

    // For long running tasks you can save the context occasionally thanks the `saveBlock`.
    if let error = saveBlock(false) {
        // Handle error here.
    }

    // The context is saved at the end of this block, no need to call the `saveContext` method.
}) {
    // This block is run after the first block is done and the context is saved.
    // This block is run in the main thread and can be used to update the UI.
    ...
}
```

> Behind the scene, a `NSManagedObjectContext` object that its parent context is the `writerContext` object and not the `defaultContext` object is created.

### Execute a batch of operations on NSManagedObject objects

If you want to do a batch of operations on `NSManagedObject` objects (like large import and create, or delete), use a dedicated `NSManagedObjectContext` for this task.
Once the operations are done, you have to refresh to `defaultContext` to update the UI (i.e. refetch from `NSFetchedResultsController` objects).

This is also useful to import a large amount of data that are not related to the UI.

```swift
import CoreDataStack

let context = myStack.newContextForBatchTask()

context.perform {
    // Do your operations here.
    ...

    // Save the context.
    if let error = context.saveToParent() {
        // Handle error here.
        ...
    }

    // Now update the 'defaultContext' object.
    OperationQueue.main.addOperation {
        do {
            try fetchedResultsController.performFetch()
        }
        catch let e {
            // Handle error here.
        }
    }
}
```

This shorthand is equivalent:

```swift
import CoreDataStack

myStack.performBatchTask (inContext: { (context, saveBlock) in
    // Do your operations here.
    ...

    // For long running tasks you can save the context occasionally thanks the `saveBlock`.
    if let error = saveBlock() {
        // Handle error here.
    }

    // The context is saved at the end of this block, no need to call the `saveContext` method.
}) {
    // This block is run after the first block is done and the context is saved.
    // This block is run in the main thread and can be used to update the UI.
    ...
}
```

> Behind the scene, a `NSManagedObjectContext` object that its parent persistent store is different than the `defaultContext` object is created.

### Save the contexts

You can save the contexts before the application terminates.

```swift
import CoreDataStack

func applicationWillTerminate(application: UIApplication) {
    myStack.saveContexts()
}
```

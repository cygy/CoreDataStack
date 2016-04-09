# CoreDataStack

Helper to set up CoreData stack on iOS/tvOS/watchOS/OSX projects.
You continue using `NSManagedObject`, `NSFetchedResultsController` classes... Not magic, just a helper :)

This helper is based on two `NSManagedObjectContext` objects. A writer and a default.
The default `NSManagedObjectContext` is exclusively used to fetch to objects from the UI. Its parent context is the writer `NSManagedObjectContext`.

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

let coreDataStack = CoreDataStack(modelFileNames: ["CoreDataStack_Example"], persistentFileName: "example.sqlite")
```

You pass the names of the .mom files (without the extension) as arguments. CoreDataStack will create the model by merging the .mom files.
The second argument is the name of the persistent file.
The other arguments are optioinal (see code source)

> Each file name must be passed as argument. By experience I do not recommend to automatically merge all the .mom files in the bundle.

### Pull and display objects in UI from CoreData

To pull and display objects from CoreData, use the `defaultManagedObjectContext` property of `CoreDataStack`, i.e. with the `NSFetchedResultsController` objects. As the `defaultManagedObjectContext` is using the main thread it is fit to be used with the UI objects like the `UITableView` objects.

```swift
import CoreDataStack

let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: coreDataStack.defaultManagedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
```

### Execute a few operations on NSManagedObject objects

If you want to do a few operations on `NSManagedObject` objects (like create one object, or delete one object) use a simple `NSManagedObjectContext` for this task.
Execute your tasks and save the context. The changes will be updated to the `defaultManagedObjectContext` object too.

```swift
import CoreDataStack

let context = coreDataStack.getNewManagedObjectContext()

context.performBlock {
    // Do your operations here.
    ...

    // Save the context.
    do {
        try coreDataStack.saveContext(context)
    } catch let e {
        // Handle error here.
    }
}
```

> Behind the scene, a NSManagedObjectContext object that its parent context is the `defaultManagedObjectContext` object is created.

### Execute a lot of operations on NSManagedObject objects

If you want to do a lot of operations on `NSManagedObject` objects (like import and create, or delete) use a dedicated `NSManagedObjectContext` for this task.
Once the operations are done, you have to refresh to `defaultManagedObjectContext` to update the UI (i.e. refetch from `NSFetchedResultsController` objects).

This is also useful to import a large amount of data that are not related to the UI.

```swift
import CoreDataStack

let context = coreDataStack.getNewManagedObjectContextForLongRunningTask()

context.performBlock {
    // Do your operations here.
    ...

    // Save the context.
    do {
        try coreDataStack.saveContext(context)
    } catch let e {
        // Handle error here.
    }

    // Now update the 'defaultManagedObjectContext' object.
    NSOperationQueue.mainQueue().addOperationWithBlock() {
        do {
            try fetchedResultsController.performFetch()
        } catch let e {
            // Handle error here.
        }
    }
}
```

> Behind the scene, a NSManagedObjectContext object that its parent context is not the `defaultManagedObjectContext` object is created.

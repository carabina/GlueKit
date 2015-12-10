# GlueKit

A Swift framework for 
[reactive programming](https://en.wikipedia.org/wiki/Reactive_programming)
that lets you create observable values and connect them up in interesting and useful ways.
It is called GlueKit because it lets you stick stuff together. 

GlueKit contains type-safe analogues for Cocoa's 
[Key-Value Coding](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/KeyValueCoding/Articles/Overview.html) 
and 
[Key-Value Observing](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/KeyValueObserving/KeyValueObserving.html)
subsystems, written in pure Swift.
Besides providing the basic observation mechanism, it also supports full-blown *key path*
observing, where you're observing a value that's not directly available, but can be looked up
via a sequence of nested observables, some of which may represent one-to-one or one-to-many
relationships between model objects. 

GlueKit will also provide a rich set of observable combinators
as a more flexible and extensible Swift version of KVC's 
[collection operators](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/KeyValueCoding/Articles/CollectionOperators.html). (These are being actively developed.)

GlueKit does not rely on the Objective-C runtime for its basic functionality, but on Apple platforms
it does provide easy-to-use adapters for observing KVO-compatible key paths on NSObjects and 
NSNotificationCenter notifications.

A major design goal for GlueKit is to eventually serve as the underlying observer implementation
for a future model object graph (and perhaps persistence) project.

## Overview

[The GlueKit Overview](https://github.com/lorentey/GlueKit/blob/master/Documentation/Overview.md)
describes the basic concepts of GlueKit.

## Appetizer

Let's say you're writing a bug tracker application that has a list of projects, each with its own 
set of issues. With GlueKit, you'd use `Variable`s to define your model's attributes and relationships:

```Swift
class Project {
    let name: Variable<String>
    let issues: ArrayVariable<Issue>
}

class Account {
    let name: Variable<String>
    let email: Variable<String>
}

class Issue {
    let identifier: Variable<String>
    let owner: Variable<Account>
    let isOpen: Variable<Bool>
    let created: Variable<NSDate>
}

class Document {
    let accounts: ArrayVariable<Account>
    let projects: ArrayVariable<Project>
}
```

You can use a `let observable: Variable<Foo>` like you would a `var raw: Foo` property, except 
you need to write `observable.value` whenever you'd write `raw`:

```Swift
// Raw Swift       ===>      // GlueKit                                    
var a = 42          ;        let b = Variable<Int>(42) 
print("a = \(a)")   ;        print("b = \(b.value\)")
a = 7               ;        b.value = 7
```

Given the model above, in Cocoa you could specify key paths for accessing various parts of the model from a
`Document` instance. For example, to get the email addresses of all issue owners in one big unsorted array, 
you'd use the Cocoa key path `"projects.issues.owner.email"`. GlueKit is able to do this too, although
it uses a specially constructed Swift closure to represent the key path:

```Swift
let cocoaKeyPath: String = "projects.issues.owner.email"

let swiftKeyPath: Document -> Observable<[String]> = { document in 
    document.projects.selectEach{$0.issues}.selectEach{$0.owner}.select{email} 
}
```

(The type declarations are included to make it clear that GlueKit is fully type-safe. Swift's type inference is able
to find these out automatically, so typically you'd omit specifying types in declarations like this.)
The GlueKit syntax is certainly much more verbose, but in exchange it is typesafe, much more flexible, and also extensible. 
Plus, there is a visual difference between selecting a single value (`select`) or a collection of values (`selectEach`), 
which alerts you that using this key path might be more expensive than usual. (GlueKit's key paths are really just 
combinations of observables. `select` is a combinator that is used to build one-to-one key paths; there are many other
interesting combinators available.)

In Cocoa, you would get the current list of emails using KVC's accessor method. In GlueKit, if you give the key path a
document instance, it returns an `Observable` that has a `value` property that you can get. 

```Swift
let document: Document = ...
let cocoaEmails: AnyObject? = document.valueForKeyPath(cocoaKeyPath)
let swiftEmails: [String] = swiftKeyPath(document).value
```

In both cases, you get an array of strings. However, Cocoa returns it as an optional `AnyObject` that you'll need to
unwrap and cast to the correct type yourself (you'll want to hold your nose while doing so). Boo! 
GlueKit knows what type the result is going to be, so it gives it to you straight. Yay!

Neither Cocoa nor GlueKit allows you to update the value at the end of this key path; however, with Cocoa, you only find
this out at runtime, while with GlueKit, you get a nice compiler error:

```Swift
// Cocoa: Compiles fine, but oops, crash at runtime
document.setValue("karoly@example.com", forKeyPath: cocoaKeyPath)
// GlueKit/Swift: error: cannot assign to property: 'value' is a get-only property
swiftKeyPath(document).value = "karoly@example.com"
```

You'll be happy to know that one-to-one key paths are assignable in both Cocoa and GlueKit:

```Swift
let issue: Issue = ...
/* Cocoa */   issue.setValue("karoly@example.com", forKeyPath: "owner.email") // OK
/* GlueKit */ issue.owner.select{$0.email}.value = "karoly@example.com"  // OK
```

(In GlueKit, you generally just use the observable combinators directly instead of creating key path entities.
So we're going to do that from now on. Serializable type-safe key paths require additional work, which is better
provided by a potentional future model object framework built on top of GlueKit.)

More interestingly, you can ask to be notified whenever a key path changes its value.

```Swift
// GlueKit
let c = document.projects.selectEach{$0.issues}.selectEach{$0.owner}.select{$0.name}.connect { emails in 
    print("Owners' email addresses are: \(emails)")
}
// Call c.disconnect() when you get bored of getting so many emails.

// Cocoa
class Foo {
    static let context: Int8 = 0
    let document: Document
    
    init(document: Document) {
        self.document = document
        document.addObserver(self, forKeyPath: "projects.issues.owner.email", options: .New, context:&context)
    }
    deinit {
        document.removeObserver(self, forKeyPath: "projects.issues.owner.email", context: &context)
    }
    func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, 
                                change change: [String : AnyObject]?, 
                                context context: UnsafeMutablePointer<Void>) {
        if context == &self.context {
	    print("Owners' email addresses are: \(change[NSKeyValueChangeNewKey]))
        }
        else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
}
```

Well, Cocoa is a mouthful, but people tend to wrap this up in their own abstractions. In both cases, a new set of emails is
printed whenever the list of projects changes, or the list of issues belonging to any project changes, or the owner of any
issue changes, or if the email address is changed on an individual account.


To present a more down-to-earth example, let's say you want to create a view model for a project summary screen that
displays various useful data about the currently selected project. GlueKit's observable combinators make it simple to
put together data derived from our model objects. The resulting fields in the view model are themselves observable,
and react to changes to any of their dependencies on their own.

```Swift
class ProjectSummaryViewModel {
    let currentDocument: Variable<Document> = ...
    let currentAccount: Variable<Account?> = ...
    
    let project: Variable<Project> = ...
    
    /// The name of the current project.
	var projectName: Updatable<String> { 
	    return project.select { $0.name } 
	}
	
    /// The number of issues (open and closed) in the current project.
	var isssueCount: Observable<Int> { 
	    return project.selectCount { $0.issues }
	}
	
    /// The number of open issues in the current project.
	var openIssueCount: Observable<Int> { 
	    return project.selectCount({ $0.issues }, filteredBy: { $0.isOpen })
	}
	
    /// The ratio of open issues to all issues, in percentage points.
    var percentageOfOpenIssues: Observable<Int> {
        // You can use the standard arithmetic operators to combine observables.
    	return Observable.constant(100) * openIssueCount / issueCount
    }
    
    /// The number of open issues assigned to the current account.
    var yourOpenIssues: Observable<Int> {
        return project
            .selectCount({ $0.issues }, 
                filteredBy: { $0.isOpen && $0.owner == self.currentAccount })
    }
    
    /// The five most recently created issues assigned to the current account.
    var yourFiveMostRecentIssues: Observable<[Issue]> {
        return project
            .selectFirstN(5, { $0.issues }, 
                filteredBy: { $0.isOpen && $0.owner == currentAccount }),
                orderBy: { $0.created < $1.created })
    }

    /// An observable version of NSLocale.currentLocale().
    var currentLocale: Observable<NSLocale> {
        let center = NSNotificationCenter.defaultCenter()
		let localeSource = center
		    .sourceForNotification(NSCurrentLocaleDidChangeNotification)
		    .map { _ in NSLocale.currentLocale() }
        return Observable(getter: { NSLocale.currentLocale() }, futureValues: localeSource)
    }
    
    /// An observable localized string.
    var localizedIssueCountFormat: Observable<String> {
        return currentLocale.map { _ in 
            return NSLocalizedString("%1$d of %2$d issues open (%3$d%%)",
                comment: "Summary of open issues in a project")
        }
    }
    
    /// An observable text for a label.
    var localizedIssueCountString: Observable<String> {
        return Observable
            // Create an observable of tuples containing values of four observables
            .combine(localizedIssueCountFormat, issueCount, openIssueCount, percentageOfOpenIssues)
            // Then convert each tuple into a single localized string
            .map { format, all, open, percent in 
                return String(format: format, open, all, percent)
            }
    }
}
```

(Note that some of the operations above aren't implemented yet. Stay tuned!)

Whenever the model is updated or another project or account is selected, the affected `Observable`s 
in the view model are recalculated accordingly, and their subscribers are notified with the updated
values. 
GlueKit does this in a surprisingly efficient manner---for example, closing an issue in
a project will simply decrement a counter inside `openIssueCount`; it won't recalculate the issue
count from scratch. (Obviously, if the user switches to a new project, that change will trigger a recalculation of that project's issue counts from scratch.) Observables aren't actually calculating anything until and unless they have subscribers.

Once you have this view model, the view controller can simply connect its observables to various
labels displayed in the view hierarchy:

```Swift
class ProjectSummaryViewController: UIViewController {
    private let visibleConnections = Connector()
    let viewModel: ProjectSummaryViewModel
    
    // ...
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
	    viewModel.projectName.values
	        .connect { name in
	            self.titleLabel.text = name
	        }
	        .putInto(visibleConnections)
	     
	    viewModel.localizedIssueCountString.values
	        .connect { text in
	            self.subtitleLabel.text = text
	        }
	        .putInto(visibleConnections)
	        
        // etc. for the rest of the observables in the view model
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        visibleConnections.disconnect()
    }
}
```

Setting up the connections in `viewWillAppear` ensures that the view model's complex observer
combinations are kept up to date only while the project summary is displayed on screen.

The `projectName` property in `ProjectSummaryViewModel` is declared an `Updatable`, so you can 
modify its value. Doing that updates the name of the current project: 

```Swift
viewModel.projectName.value = "GlueKit"   // Sets the current project's name via a key path
print(viewModel.project.name.value)       // Prints "GlueKit"
```



## Similar frameworks

Some of GlueKit's constructs can be matched with those in discrete reactive frameworks, such as 
[ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa), 
[RxSwift](https://github.com/ReactiveX/RxSwift), 
[ReactKit](https://github.com/ReactKit/ReactKit),
[Interstellar](https://github.com/JensRavens/Interstellar), and others. 
Sometimes GlueKit even uses the same name for the same concept. But often it doesn't (sorry).

GlueKit concentrates on creating a useful model for observables, rather than trying to unify 
observable-like things with task-like things. 
GlueKit explicitly does not attempt to directly model networking operations 
(although a networking support library could certainly use GlueKit to implement some of its features).
As such, GlueKit's source/signal/stream concept transmits simple values; it doesn't wrap them in
 `Event`s. 


I have several reasons I chose to create GlueKit instead of just using a better established and
bug-free library:

- I wanted to have some experience with reactive stuff, and you can learn a lot about a paradigm by 
  trying to construct its foundations on your own. The idea is that I start simple and add things as 
  I find I need them. I want to see if I arrive at the same problems and solutions as the 
  Smart People who created the popular frameworks. Some common reactive patterns are not obviously 
  right at first glance.
- I wanted to experiment with reentrant observables, where an observer is allowed to trigger updates 
  to the observable to which it's connected. I found no well-known implementation of Observable that 
  gets this *just right*.
- Building a library is a really fun diversion!


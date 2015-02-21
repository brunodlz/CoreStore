//
//  NSManagedObjectContext+HardcoreData.swift
//  HardcoreData
//
//  Copyright (c) 2014 John Rommel Estropia
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

import Foundation
import CoreData
import GCDKit


// MARK: - NSManagedObjectContext+HardcoreData

public extension NSManagedObjectContext {
    
    // MARK: - Public
    
    // MARK: Transactions
    
    public func temporaryContext() -> NSManagedObjectContext {
        
        let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        context.parentContext = self
        context.setupForHardcoreDataWithContextName("com.hardcoredata.temporarycontext")
        context.shouldCascadeSavesToParent = true
        context.parentStack = self.parentStack
        context.parentTransaction = self.parentTransaction
        
        return context
    }
    
    
    // MARK: - Internal
    
    internal weak var parentStack: DataStack? {
        
        get {
            
            return self.getAssociatedObjectForKey(&PropertyKeys.parentStack)
        }
        set {
            
            self.setAssociatedWeakObject(
                newValue,
                forKey: &PropertyKeys.parentStack)
        }
    }
    
    internal weak var parentTransaction: DataTransaction? {
        
        get {
            
            return self.getAssociatedObjectForKey(&PropertyKeys.parentTransaction)
        }
        set {
            
            self.setAssociatedWeakObject(
                newValue,
                forKey: &PropertyKeys.parentTransaction)
        }
    }
    
    internal func temporaryContextInTransaction(transaction: DataTransaction?) -> NSManagedObjectContext {
        
        let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        context.parentContext = self
        context.setupForHardcoreDataWithContextName("com.hardcoredata.temporarycontext")
        context.shouldCascadeSavesToParent = true
        
        return context
    }
    
    internal func saveSynchronously() -> SaveResult {
        
        var result = SaveResult(hasChanges: false)
        self.performBlockAndWait {
            [unowned self] () -> Void in
            
            if !self.hasChanges {
                
                self.reset()
                return
            }
            
            var saveError: NSError?
            if self.save(&saveError) {
                
                if self.shouldCascadeSavesToParent {
                    
                    if let parentContext = self.parentContext {
                        
                        switch parentContext.saveSynchronously() {
                            
                        case .Success(let hasChanges):
                            result = SaveResult(hasChanges: true)
                        case .Failure(let error):
                            result = SaveResult(error)
                        }
                        return
                    }
                }
                
                result = SaveResult(hasChanges: true)
            }
            else if let error = saveError {
                
                HardcoreData.handleError(
                    error,
                    "Failed to save NSManagedObjectContext.")
                result = SaveResult(error)
            }
            else {
                
                result = SaveResult(hasChanges: false)
            }
        }
        
        return result
    }
    
    internal func saveAsynchronouslyWithCompletion(completion: ((result: SaveResult) -> Void)?) {
        
        self.performBlock { () -> Void in
            
            if !self.hasChanges {
                
                if let completion = completion {
                    
                    GCDQueue.Main.async {
                        
                        completion(result: SaveResult(hasChanges: false))
                    }
                }
                return
            }
            
            var saveError: NSError?
            if self.save(&saveError) {
                
                if self.shouldCascadeSavesToParent {
                    
                    if let parentContext = self.parentContext {
                        
                        parentContext.saveAsynchronouslyWithCompletion(completion)
                        return
                    }
                }
                
                if let completion = completion {
                    
                    GCDQueue.Main.async {
                        
                        completion(result: SaveResult(hasChanges: true))
                    }
                }
            }
            else if let error = saveError {
                
                HardcoreData.handleError(
                    error,
                    "Failed to save NSManagedObjectContext.")
                if let completion = completion {
                    
                    GCDQueue.Main.async {
                        
                        completion(result: SaveResult(error))
                    }
                }
            }
            else if let completion = completion {
                
                GCDQueue.Main.async {
                    
                    completion(result: SaveResult(hasChanges: false))
                }
            }
        }
    }
    
    internal class func rootSavingContextForCoordinator(coordinator: NSPersistentStoreCoordinator) -> NSManagedObjectContext {
        
        let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.setupForHardcoreDataWithContextName("com.hardcoredata.rootcontext")
        
        return context
    }
    
    internal class func mainContextForRootContext(rootContext: NSManagedObjectContext) -> NSManagedObjectContext {
        
        let context = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        context.parentContext = rootContext
        context.setupForHardcoreDataWithContextName("com.hardcoredata.maincontext")
        context.shouldCascadeSavesToParent = true
        context.observerForDidSaveNotification = NotificationObserver(
            notificationName: NSManagedObjectContextDidSaveNotification,
            object: rootContext,
            closure: { [weak context] (note) -> Void in
                
                context?.mergeChangesFromContextDidSaveNotification(note)
                return
        })
        
        return context
    }
    
    
    // MARK: - Private
    
    private struct PropertyKeys {
        
        static var observerForWillSaveNotification: Void?
        static var observerForDidSaveNotification: Void?
        static var shouldCascadeSavesToParent: Void?
        static var parentStack: Void?
        static var parentTransaction: Void?
    }
    
    private var observerForWillSaveNotification: NotificationObserver? {
        
        get {
            
            return self.getAssociatedObjectForKey(&PropertyKeys.observerForWillSaveNotification)
        }
        set {
            
            self.setAssociatedRetainedObject(
                newValue,
                forKey: &PropertyKeys.observerForWillSaveNotification)
        }
    }
    
    private var observerForDidSaveNotification: NotificationObserver? {
        
        get {
            
            return self.getAssociatedObjectForKey(&PropertyKeys.observerForDidSaveNotification)
        }
        set {
        
            self.setAssociatedRetainedObject(
                newValue,
                forKey: &PropertyKeys.observerForDidSaveNotification)
        }
    }
    
    private var shouldCascadeSavesToParent: Bool {
        
        get {
            
            let number: NSNumber? = self.getAssociatedObjectForKey(&PropertyKeys.observerForDidSaveNotification)
            return number?.boolValue ?? false
        }
        set {
            
            self.setAssociatedCopiedObject(
                NSNumber(bool: newValue),
                forKey: &PropertyKeys.shouldCascadeSavesToParent)
        }
    }
    
    private func setupForHardcoreDataWithContextName(contextName: String) {
        
        if self.respondsToSelector("setName:") {
            
            self.name = contextName
        }
        
        self.observerForWillSaveNotification = NotificationObserver(
            notificationName: NSManagedObjectContextWillSaveNotification,
            object: self,
            closure: { (note) -> Void in
                
                let context = note.object as! NSManagedObjectContext
                let insertedObjects = context.insertedObjects
                if insertedObjects.count <= 0 {
                    
                    return
                }
                
                var permanentIDError: NSError?
                if context.obtainPermanentIDsForObjects(Array(insertedObjects), error: &permanentIDError) {
                    
                    return
                }
                
                if let error = permanentIDError {
                    
                    HardcoreData.handleError(
                        error,
                        "Failed to obtain permanent IDs for inserted objects.")
                }
        })
    }
}


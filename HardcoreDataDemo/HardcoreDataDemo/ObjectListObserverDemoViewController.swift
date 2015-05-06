//
//  ObjectListObserverDemoViewController.swift
//  HardcoreDataDemo
//
//  Created by John Rommel Estropia on 2015/05/02.
//  Copyright (c) 2015 John Rommel Estropia. All rights reserved.
//

import UIKit
import HardcoreData


// MARK: - ObjectListObserverDemoViewController

class ObjectListObserverDemoViewController: UITableViewController, ManagedObjectListSectionObserver {
    
    // MARK: NSObject
    
    deinit {
        
        paletteList.removeObserver(self)
    }
    
    
    // MARK: UIViewController

    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        self.navigationItem.leftBarButtonItems = [
            self.editButtonItem(),
            UIBarButtonItem(
                barButtonSystemItem: .Trash,
                target: self,
                action: "resetBarButtonItemTouched:"
            )
        ]
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .Add,
            target: self,
            action: "addBarButtonItemTouched:"
        )
    }
    
    override func viewWillAppear(animated: Bool) {
        
        super.viewWillAppear(animated)
        
        paletteList.addObserver(self)
        self.tableView.reloadData()
    }
    
    override func viewDidDisappear(animated: Bool) {
        
        super.viewDidDisappear(animated)
        
        paletteList.removeObserver(self)
    }
    
    
    // MARK: UITableViewDataSource
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        
        return paletteList.numberOfSections()
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return paletteList.numberOfObjectsInSection(section)
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCellWithIdentifier("PaletteTableViewCell") as! PaletteTableViewCell
        
        let palette = paletteList[indexPath]
        cell.colorView?.backgroundColor = palette.color
        cell.label?.text = palette.colorText
        
        return cell
    }
    
    
    // MARK: UITableViewDelegate
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        
        switch editingStyle {
            
        case .Delete:
            let palette = paletteList[indexPath]
            HardcoreData.beginAsynchronous{ (transaction) -> Void in
                
                transaction.delete(palette)
                transaction.commit { (result) -> Void in }
            }
            
        default:
            break
        }
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        return paletteList.sectionInfoAtIndex(section).name
    }
    
    
    // MARK: ManagedObjectListChangeObserver
    
    func managedObjectListWillChange(listController: ManagedObjectListController<Palette>) {
        
        self.tableView.beginUpdates()
    }
    
    func managedObjectListDidChange(listController: ManagedObjectListController<Palette>) {
        
        self.tableView.endUpdates()
    }
    
    
    // MARK: ManagedObjectListObjectObserver
    
    func managedObjectList(listController: ManagedObjectListController<Palette>, didInsertObject object: Palette, toIndexPath indexPath: NSIndexPath) {
        
        self.tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
    }
    
    func managedObjectList(listController: ManagedObjectListController<Palette>, didDeleteObject object: Palette, fromIndexPath indexPath: NSIndexPath) {
        
        self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
    }
    
    func managedObjectList(listController: ManagedObjectListController<Palette>, didUpdateObject object: Palette, atIndexPath indexPath: NSIndexPath) {
        
        self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
    }
    
    func managedObjectList(listController: ManagedObjectListController<Palette>, didMoveObject object: Palette, fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {
        
        self.tableView.moveRowAtIndexPath(fromIndexPath, toIndexPath: toIndexPath)
    }
    
    
    // MARK: ManagedObjectListSectionObserver
    
    func managedObjectList(listController: ManagedObjectListController<Palette>, didInsertSection sectionInfo: NSFetchedResultsSectionInfo, toSectionIndex sectionIndex: Int) {
        
        self.tableView.insertSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Automatic)
    }
    
    func managedObjectList(listController: ManagedObjectListController<Palette>, didDeleteSection sectionInfo: NSFetchedResultsSectionInfo, fromSectionIndex sectionIndex: Int) {
        
        self.tableView.deleteSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Automatic)
    }
    
    
    // MARK: Private
    
    @IBAction dynamic func resetBarButtonItemTouched(sender: AnyObject?) {
        
        HardcoreData.beginAsynchronous { (transaction) -> Void in
            
            transaction.deleteAll(From(Palette))
            transaction.commit { (result) -> Void in }
        }
    }
    
    @IBAction dynamic func addBarButtonItemTouched(sender: AnyObject?) {
        
        HardcoreData.beginAsynchronous { (transaction) -> Void in
            
            for _ in 0 ... 2 {
                
                let palette = transaction.create(Palette)
                palette.setInitialValues()
            }
            
            transaction.commit { (result) -> Void in }
        }
    }
}


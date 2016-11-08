//
//  WARCache.swift
//  FlickrSearch
//
//  Created by Warif Akhand Rishi on 10/30/16.
//  Copyright © 2016 Richard Turton. All rights reserved.
//

import UIKit

open class WARCache: NSCache<AnyObject, AnyObject> {
    
    // MARK: - Properties
    open static let shared = WARCache()
    
    private var inProgressList: [InProgress] = []     // when complete, check any other item with same url if found execute finishBlock then delete the item
    private var downloadedList: [Downloaded] = []     // insert new entry from top and delete from bottom also remove associated cache when deleting if max limit reached
    private var queue: [InQueue] = []                 // items to download after inPorgressList finish some downloading
    
    private override init() {
        super.init()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationDidReceiveMemoryWarning, object: nil, queue: nil) { [weak self] notification in
            
            self?.clearAll()
        }
    }
    
    private subscript(key: AnyObject) -> AnyObject? {
        
        get {
            let value = object(forKey: key)
            return value
        }
        
        set (newValue) {
            if let object = newValue {
                setObject(object, forKey: key)
            } else {
                removeObject(forKey: key)
            }
        }
    }
    
    private func removeInProgressFor(url: URL) {
        objc_sync_enter(inProgressList)
        inProgressList = inProgressList.filter {$0.url.absoluteString != url.absoluteString}
        objc_sync_exit(inProgressList)
    }
    
    /// The singleton will never be deallocated, but as a matter of defensive programming (in case this is
    /// later refactored to not be a singleton), let's remove the observer if deallocated.
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public
    open func clearAll() {
        removeAllObjects()
        inProgressList.removeAll()
        downloadedList.removeAll()
        queue.removeAll()
    }
    
    open func fetch(url: URL, onFinish:@escaping (Data?, NSError?) -> ()) {
        
        if let value = self[url as AnyObject] {
            onFinish(value as? Data, nil)
            print("From cache")
            return
        }
        
        let inProgress = InProgress(url: url, finishBlock: onFinish)
        inProgressList.append(inProgress)
        
        let matchedItems = inProgressList.filter {$0.url.absoluteString == url.absoluteString}
        
        if matchedItems.count == 1 {
            
            print("Downloading...")
            
            URLSession.shared.dataTask(with: url, completionHandler: { [weak self] (data, response, error) in
            
                guard let strongSelf = self else {
                    return
                }
                
                guard error == nil, let _ = response as? HTTPURLResponse, let data = data else {
                    
                    strongSelf.removeInProgressFor(url: url)
                    
                    let APIError = NSError(domain: "WarCacheFech", code: 0, userInfo: [NSLocalizedFailureReasonErrorKey:"Unknown API response"])
                    
                    OperationQueue.main.addOperation({
                        onFinish(nil, APIError)
                    })
                    
                    return
                }
                
                OperationQueue.main.addOperation({
                    
                    strongSelf[url as AnyObject] = data as AnyObject?
                    
                    strongSelf.inProgressList.filter {$0.url.absoluteString == url.absoluteString}.forEach({ inProgress in
                        inProgress.finishBlock(data, nil)
                    })
                    
                    // TODO: append in downloadedList
                    // need to track oldest cache for remove
                    
                    strongSelf.removeInProgressFor(url: url)
                })
            }).resume()
            
        } else {
            print("Already in progress")
        }
    }
}

private struct InProgress {
    var url: URL
    var finishBlock: (Data?, NSError?) -> ()
}

private struct Downloaded {
    var url: URL
    var dateTime = Date()
}

private struct InQueue {
    var url: URL
    var dateTime = Date()
    var finishBlock: (() -> ())?
}

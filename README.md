# WARCache

This NSCache subclass tries to cache data in memory. 

## Setup

- Xcode 8 
- Swift 3
- Simply drag and drop the "WARCache.swift" in your project. 

## How to use

WARCache.shared.fech(url: searchURL) { (data, error) in
    // cached data or new data from server
}

## How to test
- Search with same string more than once. The first time it will take more time as it fetch from server.
- To test same image requested by multiple sources simultaneously (even before it has loaded) uncomment line 100 of `Flickr.swift`
- Logs on debuger console will also help


## Reference

Reason for NSCache subclass:
NSCache is basically just an NSMutableDictionary that automatically evicts objects in order to free  up space in memory as needed.
Source: [NSCache](http://nshipster.com/nscache/)

Set number of concurrent downloads (Not implemented)
`HTTPMaximumConnectionsPerHost` has some limitation. see [Set number of concurrent downloads](http://stackoverflow.com/q/20888841/1378447) also [How do I use NSOperationQueue with NSURLSession](http://stackoverflow.com/q/21918722/1378447)

There is a popular open source: [HanekeSwift](https://github.com/Haneke/HanekeSwift)

Initial Project taken from [UICollectionView Tutorial: Getting Started](https://www.raywenderlich.com/136159/uicollectionview-tutorial-getting-started) and then modified `Flickr.swift` and added `WARCache.swift` remaining files are untouched


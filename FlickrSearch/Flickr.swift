/**
 * Copyright (c) 2016 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
	
import UIKit

let apiKey = "6d925dd3c898c7fc5defef38328a54d4"

class Flickr {
    
    let processingQueue = OperationQueue()
    
    func searchFlickrForTerm(_ searchTerm: String, completion : @escaping (_ results: FlickrSearchResults?, _ error : NSError?) -> Void){
        
        guard let searchURL = flickrSearchURLForSearchTerm(searchTerm) else {
            let APIError = NSError(domain: "FlickrSearch", code: 0, userInfo: [NSLocalizedFailureReasonErrorKey:"Unknown API response"])
            completion(nil, APIError)
            return
        }
        
        WARCache.shared.fetch(url: searchURL) { (data, error) in
            
            guard error == nil, let data = data else {
                return
            }
            
            do {
                guard let resultsDictionary = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions(rawValue: 0)) as? [String: AnyObject],
                    let stat = resultsDictionary["stat"] as? String else {
                        
                        let APIError = NSError(domain: "FlickrSearch", code: 0, userInfo: [NSLocalizedFailureReasonErrorKey:"Unknown API response"])
                        OperationQueue.main.addOperation({
                            completion(nil, APIError)
                        })
                        return
                }
                
                switch (stat) {
                case "ok":
                    print("Results processed OK")
                case "fail":
                    if let message = resultsDictionary["message"] {
                        
                        let APIError = NSError(domain: "FlickrSearch", code: 0, userInfo: [NSLocalizedFailureReasonErrorKey:message])
                        
                        OperationQueue.main.addOperation({
                            completion(nil, APIError)
                        })
                    }
                    
                    let APIError = NSError(domain: "FlickrSearch", code: 0, userInfo: nil)
                    
                    OperationQueue.main.addOperation({
                        completion(nil, APIError)
                    })
                    
                    return
                default:
                    let APIError = NSError(domain: "FlickrSearch", code: 0, userInfo: [NSLocalizedFailureReasonErrorKey:"Unknown API response"])
                    OperationQueue.main.addOperation({
                        completion(nil, APIError)
                    })
                    return
                }
                
                guard let photosContainer = resultsDictionary["photos"] as? [String: AnyObject], let photosReceived = photosContainer["photo"] as? [[String: AnyObject]] else {
                    
                    let APIError = NSError(domain: "FlickrSearch", code: 0, userInfo: [NSLocalizedFailureReasonErrorKey:"Unknown API response"])
                    OperationQueue.main.addOperation({
                        completion(nil, APIError)
                    })
                    return
                }
                
                var flickrPhotos = [FlickrPhoto]()
                
                let downloadGroup = DispatchGroup()
                
                for var photoObject in photosReceived {
                    
                    // TODO: Uncomment this line to test only one download for same URL
                    //photoObject = photosReceived.first!
                    
                    guard let photoID = photoObject["id"] as? String,
                        let farm = photoObject["farm"] as? Int ,
                        let server = photoObject["server"] as? String ,
                        let secret = photoObject["secret"] as? String else {
                            break
                    }
                    let flickrPhoto = FlickrPhoto(photoID: photoID, farm: farm, server: server, secret: secret)
                    
                    guard let url = flickrPhoto.flickrImageURL() else {
                        break
                    }
                    
                    // for test purpose using DispatchGroup
                    // previous implementedtation was sync opereation using 
                    // dataWithContentsOfURL which blocks thered
                    
                    downloadGroup.enter()
                    WARCache.shared.fetch(url: url, onFinish: { (data, error) in
                        
                        guard error == nil, let imageData = data else {
                            return
                        }
                        
                        if let image = UIImage(data: imageData) {
                            flickrPhoto.thumbnail = image
                            flickrPhotos.append(flickrPhoto)
                        }
                        
                        downloadGroup.leave()
                    })
                }
                
                DispatchQueue.global(qos: .background).async {
                    downloadGroup.wait()
                    DispatchQueue.main.async {
                        completion(FlickrSearchResults(searchTerm: searchTerm, searchResults: flickrPhotos), nil)
                    }
                }
                
            } catch _ {
                completion(nil, nil)
                return
            }
        }
    }
    
    func flickrSearchURLForSearchTerm(_ searchTerm:String) -> URL? {
        
        guard let escapedTerm = searchTerm.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics) else {
            return nil
        }
        
        let URLString = "https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=\(apiKey)&text=\(escapedTerm)&per_page=50&format=json&nojsoncallback=1"
        
        guard let url = URL(string:URLString) else {
            return nil
        }
        
        return url
    }
}

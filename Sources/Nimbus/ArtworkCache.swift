import Foundation
import AppKit

class ArtworkCache: ObservableObject {
    static let shared = ArtworkCache()
    
    @Published var cachedImages: [String: NSImage] = [:]
    private let lock = NSLock()
    
    private init() {}
    
    func fetchArtwork(title: String, artist: String) {
        let key = "\(title)-\(artist)"
        
        lock.lock()
        let alreadyCached = cachedImages[key] != nil
        lock.unlock()
        
        if alreadyCached || title.isEmpty || title == "Not Playing" {
            return
        }
        
        let query = "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://itunes.apple.com/search?term=\(query)&limit=1&media=music") else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let urlString = first["artworkUrl100"] as? String,
                  // Get high-res version of the artwork
                  let highResUrl = URL(string: urlString.replacingOccurrences(of: "100x100bb", with: "300x300bb")),
                  let artworkData = try? Data(contentsOf: highResUrl),
                  let image = NSImage(data: artworkData) else {
                return
            }
            
            DispatchQueue.main.async {
                self.lock.lock()
                self.cachedImages[key] = image
                self.lock.unlock()
            }
        }.resume()
    }
    
    func get(title: String, artist: String) -> NSImage? {
        let key = "\(title)-\(artist)"
        lock.lock()
        defer { lock.unlock() }
        return cachedImages[key]
    }
}

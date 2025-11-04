import SwiftUI

/// A cached AsyncImage that uses URLCache for image caching and shows a placeholder during loading
struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL?
    let placeholder: () -> Placeholder
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = true
    
    init(url: URL?, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.placeholder = placeholder
        
        // Try to load from cache synchronously during initialization
        // This prevents showing placeholder if image is already cached
        // We check cache immediately and set initial state if found
        if let url = url {
            let request = URLRequest(url: url)
            if let cachedResponse = URLCache.shared.cachedResponse(for: request) {
                // Decode image synchronously on main thread
                if let image = UIImage(data: cachedResponse.data) {
                    _loadedImage = State(initialValue: image)
                    _isLoading = State(initialValue: false)
                    return
                }
            }
        }
        // If not in cache, start with nil and isLoading = true
        _loadedImage = State(initialValue: nil)
        _isLoading = State(initialValue: true)
    }
    
    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
            } else {
                placeholder()
            }
        }
        .task {
            // Only load if not already loaded from cache in init
            if loadedImage == nil {
                await loadImage()
            }
        }
        .onChange(of: url) { oldValue, newValue in
            // Clear old image when URL changes
            if oldValue != newValue {
                loadedImage = nil
                Task {
                    await loadImage()
                }
            }
        }
    }
    
    private func loadImage() async {
        guard let url = url else {
            await MainActor.run {
                self.loadedImage = nil
                self.isLoading = false
            }
            return
        }
        
        // Check cache first (in case it wasn't found during init)
        let request = URLRequest(url: url)
        if let cachedResponse = URLCache.shared.cachedResponse(for: request),
           let image = UIImage(data: cachedResponse.data) {
            await MainActor.run {
                self.loadedImage = image
                self.isLoading = false
            }
            return
        }
        
        // Load from network
        await MainActor.run {
            self.isLoading = true
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            // Cache the response
            if let httpResponse = response as? HTTPURLResponse {
                let cachedResponse = CachedURLResponse(response: httpResponse, data: data)
                URLCache.shared.storeCachedResponse(cachedResponse, for: request)
            }
            
            if let image = UIImage(data: data) {
                await MainActor.run {
                    self.loadedImage = image
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.loadedImage = nil
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.loadedImage = nil
                self.isLoading = false
            }
        }
    }
}

// Convenience initializer for simple placeholder
extension CachedAsyncImage where Placeholder == AnyView {
    init(url: URL?, placeholder: Image) {
        self.url = url
        self.placeholder = { AnyView(placeholder) }
    }
}


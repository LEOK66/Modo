import Foundation
import FirebaseStorage
import UIKit

final class AvatarUploadService {
    static let shared = AvatarUploadService()
    private let storage = Storage.storage()

    func uploadProfileImage(userId: String, image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            completion(.failure(NSError(domain: "AvatarUploadService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode image"])));
            return
        }
        let ref = storage.reference().child("users/\(userId)/profile.jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        ref.putData(data, metadata: metadata) { _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            ref.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                // Add timestamp to URL to force cache refresh
                var urlString = url!.absoluteString
                let timestamp = Int(Date().timeIntervalSince1970)
                let separator = urlString.contains("?") ? "&" : "?"
                urlString += "\(separator)t=\(timestamp)"
                completion(.success(urlString))
            }
        }
    }
}



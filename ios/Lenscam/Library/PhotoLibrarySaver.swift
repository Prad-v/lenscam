import Foundation
import Photos

enum PhotoLibrarySaver {
    enum Failure: LocalizedError {
        case denied

        var errorDescription: String? {
            "Photos access is off, so Lenscam kept the master in its own library."
        }
    }

    static func save(at url: URL, isVideo: Bool) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw Failure.denied }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: isVideo ? .video : .photo, fileURL: url, options: nil)
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: Failure.denied)
                }
            }
        }
    }
}

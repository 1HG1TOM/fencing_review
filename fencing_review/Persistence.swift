import Foundation
import Photos

enum SaveError: Error, LocalizedError {
    case photoLibraryAccessDenied
    case failedToCreateAsset
    case fileSystemError(Error)
    
    var errorDescription: String? {
        switch self {
        case .photoLibraryAccessDenied:
            return "写真ライブラリへのアクセスが拒否されました。設定アプリから許可してください。"
        case .failedToCreateAsset:
            return "写真ライブラリにアセットを作成できませんでした。"
        case .fileSystemError(let error):
            return "ファイルの保存に失敗しました: \(error.localizedDescription)"
        }
    }
}

class MediaSaver {
    static func saveVideoToPhotoLibrary(from tempURL: URL) async throws -> String {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized else { throw SaveError.photoLibraryAccessDenied }
        
        var placeholder: PHObjectPlaceholder?
        
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tempURL)
            placeholder = request?.placeholderForCreatedAsset
        }
        
        try? FileManager.default.removeItem(at: tempURL)
        
        if let assetID = placeholder?.localIdentifier {
            return assetID
        } else {
            throw SaveError.failedToCreateAsset
        }
    }
}

class DataSaver {
    static func saveAnalysisData(frames: [AnalysisFrame], sessionID: UUID) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(frames)
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = "analysis-\(sessionID.uuidString).json"
            let fileURL = documentsDirectory.appendingPathComponent(fileName)
            try data.write(to: fileURL)
            return fileName
        } catch {
            throw SaveError.fileSystemError(error)
        }
    }
}

class SessionStore {
    private static let fileName = "recording_sessions.json"

    static func save(session: RecordingSession) {
        var sessions = loadAll()
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }

        let fileURL = getFileURL()
        if let data = try? JSONEncoder().encode(sessions) {
            try? data.write(to: fileURL)
        }
    }

    static func loadAll() -> [RecordingSession] {
        let fileURL = getFileURL()
        if let data = try? Data(contentsOf: fileURL),
           let sessions = try? JSONDecoder().decode([RecordingSession].self, from: data) {
            return sessions
        }
        return []
    }

    private static func getFileURL() -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent(fileName)
    }
}


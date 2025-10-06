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
    // MARK: - Public (新) 動画ごとフォルダ保存版

    static func saveAnalysisData(frames: [AnalysisFrame],
                                 sessionID: UUID,
                                 videoName: String) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let data = try encoder.encode(frames)
            let folderURL = try getOrCreateFolder(videoName: videoName)
            let fileName = "analysis-\(sessionID.uuidString).json"
            let fileURL = folderURL.appendingPathComponent(fileName)
            try data.write(to: fileURL)
            return fileName
        } catch {
            throw SaveError.fileSystemError(error)
        }
    }

    static func saveFlagTimestamps(times: [TimeInterval],
                                   sessionID: UUID,
                                   videoName: String) throws -> String {
        do {
            let wrapped = times.map { ["flagTime": $0] }
            let data = try JSONSerialization.data(withJSONObject: wrapped, options: .prettyPrinted)
            let folderURL = try getOrCreateFolder(videoName: videoName)
            let fileName = "flags-\(sessionID.uuidString).json"
            let fileURL = folderURL.appendingPathComponent(fileName)
            try data.write(to: fileURL)
            return fileName
        } catch {
            throw SaveError.fileSystemError(error)
        }
    }

    /// 外部JSONを動画フォルダにインポート（renameTo が拡張子なしなら .json を付与）
    @discardableResult
    static func importExternalJSON(from sourceURL: URL,
                                   renameTo: String? = nil,
                                   videoName: String) throws -> String {
        let needsStop = sourceURL.startAccessingSecurityScopedResource()
        defer { if needsStop { sourceURL.stopAccessingSecurityScopedResource() } }

        let fm = FileManager.default
        let folderURL = try getOrCreateFolder(videoName: videoName)

        let baseName: String = {
            if let renameTo, !renameTo.isEmpty { return renameTo }
            return sourceURL.lastPathComponent
        }()

        var destURL = folderURL.appendingPathComponent(baseName)

        if destURL.pathExtension.isEmpty {
            destURL.deletePathExtension()
            destURL.appendPathExtension("json")
        }

        if fm.fileExists(atPath: destURL.path) {
            let stem = destURL.deletingPathExtension().lastPathComponent
            let ext  = destURL.pathExtension
            var counter = 1
            while fm.fileExists(atPath: destURL.path) {
                destURL = folderURL.appendingPathComponent("\(stem)-\(counter).\(ext)")
                counter += 1
            }
        }

        do {
            try fm.copyItem(at: sourceURL, to: destURL)
            return destURL.lastPathComponent
        } catch {
            throw SaveError.fileSystemError(error)
        }
    }

    /// 採点ファイルを動画フォルダへ（既存の命名を踏襲）
    @discardableResult
    static func importScoringFile(from sourceURL: URL,
                                  sessionID: UUID,
                                  videoName: String) throws -> String {
        let fname = "scores-\(sessionID.uuidString).json"
        return try importExternalJSON(from: sourceURL, renameTo: fname, videoName: videoName)
    }

    // MARK: - 後方互換（旧API）: ドキュメント直下を維持

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

    static func saveFlagTimestamps(times: [TimeInterval], sessionID: UUID) throws -> String {
        let wrapped = times.map { ["flagTime": $0] }
        do {
            let data = try JSONSerialization.data(withJSONObject: wrapped, options: .prettyPrinted)
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = "flags-\(sessionID.uuidString).json"
            let fileURL = documentsDirectory.appendingPathComponent(fileName)
            try data.write(to: fileURL)
            return fileName
        } catch {
            throw SaveError.fileSystemError(error)
        }
    }

    @discardableResult
    static func importExternalJSON(from sourceURL: URL,
                                   renameTo: String? = nil) throws -> String {
        let needsStop = sourceURL.startAccessingSecurityScopedResource()
        defer { if needsStop { sourceURL.stopAccessingSecurityScopedResource() } }

        let fm = FileManager.default
        let documents = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]

        let baseName: String = {
            if let renameTo, !renameTo.isEmpty { return renameTo }
            return sourceURL.lastPathComponent
        }()

        var destURL = documents.appendingPathComponent(baseName)

        if destURL.pathExtension.isEmpty {
            destURL.deletePathExtension()
            destURL.appendPathExtension("json")
        }

        if fm.fileExists(atPath: destURL.path) {
            let stem = destURL.deletingPathExtension().lastPathComponent
            let ext  = destURL.pathExtension
            var counter = 1
            while fm.fileExists(atPath: destURL.path) {
                destURL = documents.appendingPathComponent("\(stem)-\(counter).\(ext)")
                counter += 1
            }
        }

        do {
            try fm.copyItem(at: sourceURL, to: destURL)
            return destURL.lastPathComponent
        } catch {
            throw SaveError.fileSystemError(error)
        }
    }

    @discardableResult
    static func importScoringFile(from sourceURL: URL, sessionID: UUID) throws -> String {
        let fname = "scores-\(sessionID.uuidString).json"
        return try importExternalJSON(from: sourceURL, renameTo: fname)
    }

    @discardableResult
    static func renameJSON(oldName: String, to newBaseName: String) throws -> String {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let src = docs.appendingPathComponent(oldName)
        guard fm.fileExists(atPath: src.path) else {
            throw SaveError.fileSystemError(NSError(domain: "not.found", code: 0))
        }

        var base = newBaseName.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.isEmpty { base = "untitled" }
        if !base.hasSuffix(".json") { base += ".json" }

        var dest = docs.appendingPathComponent(base)
        if fm.fileExists(atPath: dest.path) {
            let stem = dest.deletingPathExtension().lastPathComponent
            let ext  = dest.pathExtension
            var i = 1
            while fm.fileExists(atPath: dest.path) {
                dest = docs.appendingPathComponent("\(stem)-\(i).\(ext)")
                i += 1
            }
        }

        do {
            try fm.moveItem(at: src, to: dest)
            return dest.lastPathComponent
        } catch {
            throw SaveError.fileSystemError(error)
        }
    }

    // MARK: - Helpers

    /// Documents/〈動画名〉 を作成して返す
    private static func getOrCreateFolder(videoName: String) throws -> URL {
        let fm = FileManager.default
        let documents = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let safeName = sanitizeFileName(videoName)
        let folderURL = documents.appendingPathComponent(safeName, isDirectory: true)
        if !fm.fileExists(atPath: folderURL.path) {
            try fm.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
        return folderURL
    }

    /// 簡易サニタイズ：不可文字を「-」に
    private static func sanitizeFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:\n\r\t")
        let cleaned = name.components(separatedBy: invalid).joined(separator: "-")
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "untitled" : trimmed
    }
    
    static func deleteMatchFolder(videoName: String) throws {
        let fm = FileManager.default
        let documents = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let safeName = sanitizeFileName(videoName)
        let folderURL = documents.appendingPathComponent(safeName, isDirectory: true)
        if fm.fileExists(atPath: folderURL.path) {
            try fm.removeItem(at: folderURL)
            print("🗑️ フォルダ削除: \(folderURL.path)")
        } else {
            print("⚠️ 削除対象のフォルダが存在しません: \(folderURL.path)")
        }
    }
    
    static func countFlags(inMatch matchName: String) -> Int {
        let fm = FileManager.default
        let documents = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folderURL = documents.appendingPathComponent(sanitizeFileName(matchName))
        
        guard let files = try? fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) else {
            return 0
        }
        
        let flagFiles = files.filter { $0.lastPathComponent.hasPrefix("flags-") }
        var totalCount = 0
        
        for file in flagFiles {
            if let data = try? Data(contentsOf: file),
               let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                totalCount += arr.count
            }
        }
        return totalCount
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

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

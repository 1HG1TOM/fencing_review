// Logger.swift
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// ユーザ単位で 1 ファイルにログを貯めるロガー
/// 保存先: Documents/logs/<userID>.json
/// 形式: NDJSON (1行1JSON) ※拡張子は .json
/// タイムスタンプ: "ts" (UTC, ISO8601 ミリ秒付き)
final class Logger {
    static let shared = Logger()
    private init() {}

    private var userID: String = "default"
    private var logFileURL: URL?
    private let queue = DispatchQueue(label: "fencing_review.logger.queue")

    // MARK: - Public

    /// ログイン直後に必ず呼ぶ
    func setUser(id: String) {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        self.userID = trimmed.isEmpty ? "default" : trimmed

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let logsDir = docs.appendingPathComponent("logs", isDirectory: true)

        do { try FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true) }
        catch {
            #if DEBUG
            print("[Logger] createDirectory failed: \(error.localizedDescription)")
            #endif
        }

        let fileName = "\(sanitizeFileName(self.userID)).json"
        let fileURL = logsDir.appendingPathComponent(fileName)

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }

        self.logFileURL = fileURL

        #if DEBUG
        print("[Logger] user='\(self.userID)' logFile=\(fileURL.path)")
        #endif

        log(event: "user_set", ["user_id": self.userID])
    }

    /// 任意イベントを即時追記
    func log(event: String, _ attrs: [String: Any] = [:]) {
        guard let fileURL = logFileURL else {
            #if DEBUG
            print("[Logger] logFileURL is nil. Call setUser(id:) first.")
            #endif
            return
        }

        var record: [String: Any] = [
            "ts": Logger.iso8601ms.string(from: Date()), // UTC
            "event": event,
            "user_id": userID
        ]
        attrs.forEach { record[$0.key] = $0.value }

        queue.async {
            do {
                let data = try JSONSerialization.data(withJSONObject: record, options: [])
                var line = data
                line.append(0x0A) // \n

                if let handle = try? FileHandle(forWritingTo: fileURL) {
                    defer { try? handle.close() }
                    // iOS 13.4+ は throw 版、それ以前は非throw版を使用
                    if #available(iOS 13.4, *) {
                        try? handle.seekToEnd()
                    } else {
                        handle.seekToEndOfFile()
                    }
                    handle.write(line) // 互換性の高い write(_:) を使用
                } else {
                    // ハンドル取得に失敗した場合は上書き→追記にフォールバック
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        // 既存ファイル末尾に自前で結合（安全側: いったん読み出して付け直し）
                        let existing = (try? Data(contentsOf: fileURL)) ?? Data()
                        var merged = existing
                        merged.append(line)
                        try merged.write(to: fileURL, options: .atomic)
                    } else {
                        try line.write(to: fileURL, options: .atomic)
                    }
                }
            } catch {
                #if DEBUG
                print("[Logger] write failed: \(error.localizedDescription)")
                #endif
            }
        }
    }

    // MARK: - Utils

    private static let iso8601ms: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private func sanitizeFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:\n\r\t")
        let cleaned = name.components(separatedBy: invalid).joined(separator: "-")
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "user" : trimmed
    }
}

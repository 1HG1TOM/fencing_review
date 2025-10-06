import Foundation

struct ScoringPoint: Decodable {
    let pointType: String   // "GF" / "GA" / "GD" / "SET"
    let pointTime: String   // "yyyy-MM-dd HH:mm:ss"
}

enum ScoringMapError: LocalizedError {
    case fileNotFound(String)
    case decodeFailed(Error)
    case dateParseFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let name): return "得失点ファイルが見つかりません: \(name)"
        case .decodeFailed(let e):    return "得失点JSONの読み込みに失敗: \(e.localizedDescription)"
        case .dateParseFailed(let s): return "日時の解析に失敗: \(s)"
        }
    }
}

final class ScoringMapper {
    private static let fm = FileManager.default
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }()

    static func loadSeconds(
        sessionID: UUID,
        videoName: String,
        videoStartAt: Date,
        duration: Double? = nil,
        offset: Double = 0
    ) throws -> (gf: [Double], ga: [Double], gd: [Double], sets: [Double]) {

        let fileName = "scores-\(sessionID.uuidString).json"
        let url = folderURL(for: videoName).appendingPathComponent(fileName)

        guard fm.fileExists(atPath: url.path) else {
            throw ScoringMapError.fileNotFound(fileName)
        }

        let data = try Data(contentsOf: url)
        let items = try JSONDecoder().decode([ScoringPoint].self, from: data)

        var gf: [Double] = []
        var ga: [Double] = []
        var gd: [Double] = []
        var sets: [Double] = []

        for item in items {
            if let t = formatter.date(from: item.pointTime) {
                var sec = t.timeIntervalSince(videoStartAt) + offset
                if sec < 0 { continue }
                if let dur = duration, sec > dur { sec = dur }

                switch item.pointType {
                case "GF": gf.append(sec)
                case "GA": ga.append(sec)
                case "GD": gd.append(sec)
                case "SET": sets.append(sec)
                default: break
                }
            } else {
                print("[Debug] Date parse failed for: \(item.pointTime)")
            }
        }

        
        if sets.first != 0 {
            sets.insert(0.0, at: 0)
        }

        gf.sort(); ga.sort(); gd.sort(); sets.sort()
        return (gf, ga, gd, sets)
    }
}


//import Foundation
//
//// 得点データの構造体
//struct ScoringPoint: Decodable {
//    let pointType: String // "GF" / "GA" / "GD"
//    let pointTime: String // "yyyy-MM-dd HH:mm:ss"
//}
//
//// エラーハンドリング
//enum ScoringMapError: LocalizedError {
//    case fileNotFound(String)
//    case decodeFailed(Error)
//    case dateParseFailed(String)
//
//    var errorDescription: String? {
//        switch self {
//        case .fileNotFound(let name):
//            return "得失点ファイルが見つかりません: \(name)"
//        case .decodeFailed(let e):
//            return "得失点JSONの読み込みに失敗: \(e.localizedDescription)"
//        case .dateParseFailed(let s):
//            return "日時の解析に失敗: \(s)"
//        }
//    }
//}
//
//// ファイル名を安全な形式に整える
//private func sanitizeFileName(_ name: String) -> String {
//    let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:\n\r\t")
//    let cleaned = name.components(separatedBy: invalid).joined(separator: "-")
//    let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
//    return trimmed.isEmpty ? "untitled" : trimmed
//}
//
//// 保存フォルダのURLを返す
//private func folderURL(for videoName: String) -> URL {
//    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    return docs.appendingPathComponent(sanitizeFileName(videoName), isDirectory: true)
//}
//
//// 得点データを読み込んで秒に変換
//final class ScoringMapper {
//    private static let fm = FileManager.default
//
//    private static let formatter: DateFormatter = {
//        let f = DateFormatter()
//        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
//        f.locale = Locale(identifier: "en_US_POSIX")
//        f.timeZone = TimeZone.current
//        return f
//    }()
//
//    static func loadSeconds(
//        sessionID: UUID,
//        videoName: String,
//        videoStartAt: Date,
//        duration: Double? = nil,
//        offset: Double = 0
//    ) throws -> (gf: [Double], ga: [Double], gd: [Double]) {
//
//        let fileName = "scores-\(sessionID.uuidString).json"
//        let url = folderURL(for: videoName).appendingPathComponent(fileName)
//
//        guard fm.fileExists(atPath: url.path) else {
//            throw ScoringMapError.fileNotFound(fileName)
//        }
//
//        let data = try Data(contentsOf: url)
//        let items = try JSONDecoder().decode([ScoringPoint].self, from: data)
//
//        var gf: [Double] = []
//        var ga: [Double] = []
//        var gd: [Double] = []
//
//        for item in items {
//            guard let t = formatter.date(from: item.pointTime) else {
//                throw ScoringMapError.dateParseFailed(item.pointTime)
//            }
//
//            var sec = t.timeIntervalSince(videoStartAt) + offset
//            if sec < 0 { continue }
//            if let dur = duration, sec > dur { sec = dur }
//
//            switch item.pointType {
//            case "GF":
//                gf.append(sec)
//            case "GA":
//                ga.append(sec)
//            case "GD": // ★ 追加
//                gd.append(sec)
//            default:
//                break
//            }
//        }
//
//        gf.sort()
//        ga.sort()
//        gd.sort()
//
//        return (gf, ga, gd)
//    }
//}

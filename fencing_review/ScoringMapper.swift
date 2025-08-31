import Foundation

struct ScoringPoint: Decodable {
    let pointType: String   // "GF" / "GA"
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
        videoStartAt: Date,
        duration: Double? = nil,
        offset: Double = 0
    ) throws -> (gf: [Double], ga: [Double]) {

        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "scores-\(sessionID.uuidString).json"
        let url = docs.appendingPathComponent(fileName)

        guard fm.fileExists(atPath: url.path) else {
            throw ScoringMapError.fileNotFound(fileName)
        }

        let data = try Data(contentsOf: url)
        let items = try JSONDecoder().decode([ScoringPoint].self, from: data)

        var gf: [Double] = []
        var ga: [Double] = []

        for item in items {
            guard let t = formatter.date(from: item.pointTime) else {
                throw ScoringMapError.dateParseFailed(item.pointTime)
            }
            var sec = t.timeIntervalSince(videoStartAt) + offset
            if sec < 0 { continue }
            if let dur = duration, sec > dur { sec = dur }
            if item.pointType == "GF" { gf.append(sec) }
            else if item.pointType == "GA" { ga.append(sec) }
        }

        gf.sort(); ga.sort()
        return (gf, ga)
    }
}

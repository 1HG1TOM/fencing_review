import Foundation

// 1回の撮影セッション全体の情報
struct RecordingSession: Codable, Identifiable {
    let id: UUID
    let creationDate: Date
    
    // ユーザーが入力するメタデータ
    var matchName: String
    
    // 保存したファイルの「住所」
    var videoAssetID: String?       // 写真ライブラリ内の動画を指すID
    var analysisDataFilename: String? // アプリ内フォルダの分析データファイル名
    var flagDataFilename: String? // フラグのファイル名
}

// 1フレームごとの分析結果
struct AnalysisFrame: Codable {
    let videoTimestamp: TimeInterval // 録画開始からの経過時間
    let result: DetectionResult
}

// サーバーからのレスポンス形式
struct DetectionResult: Codable {
    let request_id: String
    let people: Int
    let left: PlayerPosition?
    let right: PlayerPosition?
}

// プレイヤーの座標
struct PlayerPosition: Codable, Hashable {
    let x: Int
    let y: Int
}

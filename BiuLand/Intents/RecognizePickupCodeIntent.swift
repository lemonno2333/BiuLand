import Foundation
import AppIntents

struct RecognizePickupCodeIntent: AppIntent {
    static var title: LocalizedStringResource = "识别取码并显示"
    static var description = IntentDescription("识别截图中的取餐码/取件码，并更新灵动岛与实时活动。")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "截图")
    var screenshot: IntentFile

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let fileURL = screenshot.fileURL else {
            return .result(dialog: IntentDialog("未收到截图文件。"))
        }

        let data = try Data(contentsOf: fileURL)
        let lines = try await OCRService.shared.recognizeTextLines(from: data)
        guard let candidate = CodeExtractor.bestCode(from: lines) else {
            let preview = lines.map(\.text).prefix(6).joined(separator: " / ")
            let message = preview.isEmpty ? "未识别到文字。" : "未识别到有效取码。OCR：\(preview)"
            return .result(dialog: IntentDialog(stringLiteral: message))
        }

        try await LiveActivityManager.shared.upsert(
            code: candidate.code,
            context: candidate.reason,
            confidence: candidate.score
        )

        return .result(dialog: IntentDialog("已识别取码 \(candidate.code)，并更新实时活动。"))
    }
}

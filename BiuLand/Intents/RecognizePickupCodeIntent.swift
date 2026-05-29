import Foundation
import AppIntents
import UniformTypeIdentifiers

enum RecognizePickupCodeIntentError: LocalizedError {
    case emptyImageData
    case noPickupCode(String)
    case liveActivityFailed(String)
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyImageData:
            return "未收到截图数据。"
        case .noPickupCode(let message), .liveActivityFailed(let message):
            return message
        case .recognitionFailed(let message):
            return "识别失败：\(message)"
        }
    }
}

@available(iOS 17.0, *)
struct RecognizePickupCodeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "识别截图取码"
    static var description = IntentDescription("识别截图中的取餐码/取件码，并更新灵动岛与实时活动。")
    static var isDiscoverable: Bool = true
    static var openAppWhenRun: Bool = false

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes {
        .background
    }

    @Parameter(title: "截图", inputConnectionBehavior: .connectToPreviousIntentResult)
    var screenshot: IntentFile

    func perform() async throws -> some IntentResult {
        do {
            let data = try await imageData(from: screenshot)
            guard data.isEmpty == false else {
                throw RecognizePickupCodeIntentError.emptyImageData
            }

            let lines = try await OCRService.shared.recognizeTextLines(from: data)
            guard let candidate = CodeExtractor.bestCode(from: lines) else {
                let preview = lines.map(\.text).prefix(6).joined(separator: " / ")
                let message = preview.isEmpty ? "未识别到文字。" : "未识别到有效取码。OCR：\(preview)"
                throw RecognizePickupCodeIntentError.noPickupCode(message)
            }

            PickupCodeHistoryStore.add(
                code: candidate.code,
                context: candidate.reason,
                icon: candidate.icon,
                brandIconName: candidate.brandIconName,
                brandName: candidate.brandName,
                category: candidate.category,
                confidence: candidate.score
            )

            do {
                try await LiveActivityManager.shared.upsert(
                    code: candidate.code,
                    context: candidate.reason,
                    icon: candidate.icon,
                    brandIconName: candidate.brandIconName,
                    brandName: candidate.brandName,
                    category: candidate.category,
                    confidence: candidate.score
                )
            } catch {
                throw RecognizePickupCodeIntentError.liveActivityFailed("已识别取码 \(candidate.code)，但实时活动更新失败：\(failureMessage(for: error))")
            }

            return .result()
        } catch {
            throw RecognizePickupCodeIntentError.recognitionFailed(failureMessage(for: error))
        }
    }

    private func imageData(from file: IntentFile) async throws -> Data {
        if #available(iOS 18.0, *) {
            if let contentType = file.availableContentTypes.first(where: { $0.conforms(to: .image) }) {
                return try await file.data(contentType: contentType)
            }

            return try await file.data(contentType: .image)
        }

        let embeddedData = file.data
        if embeddedData.isEmpty == false {
            return embeddedData
        }

        if let fileURL = file.fileURL {
            return try Data(contentsOf: fileURL)
        }

        return Data()
    }

    private func failureMessage(for error: Error) -> String {
        if case OCRServiceError.invalidImage = error {
            return "传入内容不是可识别的图片，请确认上一步传入的是截图。"
        }

        if error.localizedDescription.localizedCaseInsensitiveContains("Target is not foreground") {
            return "启动实时活动时 app 不在前台，请确认快捷指令动作已更新为最新版本。"
        }

        return error.localizedDescription
    }
}

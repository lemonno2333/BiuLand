import AppIntents
import Foundation

struct ViewScreenshotIntent: AppIntent {
    static var title: LocalizedStringResource = "查看截图"
    static var description = IntentDescription("打开应用查看当前取码的截图")
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // 发送通知给主应用，打开截图查看器
        NotificationCenter.default.post(
            name: NSNotification.Name("OpenScreenshotViewer"),
            object: nil
        )
        
        return .result()
    }
}

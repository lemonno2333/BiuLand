import Foundation
import UIKit

enum ScreenshotManagerError: Error {
    case saveFailure
    case loadFailure
}

nonisolated struct ScreenshotMetadata: Hashable {
    let pixelSize: CGSize
    let fileSize: Int64
}

nonisolated final class ScreenshotManager {
    static let shared = ScreenshotManager()
    private init() {}
    
    private var screenshotsDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let directory = paths[0].appendingPathComponent("Screenshots", isDirectory: true)
        
        // 确保目录存在
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
    
    /// 保存当前取码的截图
    func saveCurrentScreenshot(_ imageData: Data) throws -> String {
        let filename = "current_screenshot.jpg"
        let fileURL = screenshotsDirectory.appendingPathComponent(filename)
        
        // 如果存在旧截图，先删除
        try? FileManager.default.removeItem(at: fileURL)
        
        // 压缩并保存新截图
        guard let image = UIImage(data: imageData),
              let compressedData = image.jpegData(compressionQuality: 0.75) else {
            throw ScreenshotManagerError.saveFailure
        }
        
        try compressedData.write(to: fileURL)
        return filename
    }
    
    /// 加载当前取码的截图
    func loadCurrentScreenshot() throws -> Data {
        let filename = "current_screenshot.jpg"
        let fileURL = screenshotsDirectory.appendingPathComponent(filename)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ScreenshotManagerError.loadFailure
        }
        
        return try Data(contentsOf: fileURL)
    }
    
    /// 检查当前截图是否存在
    func currentScreenshotExists() -> Bool {
        let filename = "current_screenshot.jpg"
        let fileURL = screenshotsDirectory.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    /// 删除当前取码的截图
    func deleteCurrentScreenshot() {
        let filename = "current_screenshot.jpg"
        let fileURL = screenshotsDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    /// 清理所有截图（可用于重置或清理）
    func clearAllScreenshots() {
        try? FileManager.default.removeItem(at: screenshotsDirectory)
    }
    
    /// 获取截图文件大小（字节）
    func getCurrentScreenshotSize() -> Int64? {
        let filename = "current_screenshot.jpg"
        let fileURL = screenshotsDirectory.appendingPathComponent(filename)
        
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path) else {
            return nil
        }
        
        return attributes[.size] as? Int64
    }

    func currentScreenshotMetadata() -> ScreenshotMetadata? {
        guard let data = try? loadCurrentScreenshot(),
              let image = UIImage(data: data),
              let fileSize = getCurrentScreenshotSize() else {
            return nil
        }

        return ScreenshotMetadata(
            pixelSize: CGSize(
                width: image.size.width * image.scale,
                height: image.size.height * image.scale
            ),
            fileSize: fileSize
        )
    }
}

import Foundation
import UIKit
import os

enum ScreenshotManagerError: LocalizedError {
    case saveFailure
    case loadFailure

    var errorDescription: String? {
        switch self {
        case .saveFailure:
            return "截图保存失败，请确认传入的是有效图片。"
        case .loadFailure:
            return "找不到当前取码的截图，可能已经过期或被清理。"
        }
    }
}

nonisolated struct ScreenshotMetadata: Hashable {
    let pixelSize: CGSize
    let fileSize: Int64
}

nonisolated final class ScreenshotManager {
    static let shared = ScreenshotManager()
    private let logger = Logger(subsystem: "com.leo.BiuLand", category: "screenshot")
    private init() {}
    
    private var screenshotsDirectory: URL {
        preferredScreenshotsDirectory
    }

    private var preferredScreenshotsDirectory: URL {
        let baseDirectory = AppGroup.containerURL ?? legacyBaseDirectory
        let directory = baseDirectory.appendingPathComponent("Screenshots", isDirectory: true)
        
        // 确保目录存在
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private var legacyScreenshotsDirectory: URL {
        let directory = legacyBaseDirectory.appendingPathComponent("Screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private var legacyBaseDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var currentScreenshotFileURL: URL {
        let filename = "current_screenshot.jpg"
        let preferredURL = preferredScreenshotsDirectory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: preferredURL.path) {
            return preferredURL
        }

        let legacyURL = legacyScreenshotsDirectory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: legacyURL.path) {
            return legacyURL
        }

        return preferredURL
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
        let fileURL = currentScreenshotFileURL
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ScreenshotManagerError.loadFailure
        }
        
        return try Data(contentsOf: fileURL)
    }
    
    /// 检查当前截图是否存在
    func currentScreenshotExists() -> Bool {
        FileManager.default.fileExists(atPath: currentScreenshotFileURL.path)
    }
    
    /// 删除当前取码的截图
    func deleteCurrentScreenshot() {
        let filename = "current_screenshot.jpg"
        for directory in [preferredScreenshotsDirectory, legacyScreenshotsDirectory] {
            let fileURL = directory.appendingPathComponent(filename)
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch CocoaError.fileNoSuchFile {
                continue
            } catch {
                logger.error("Failed to delete current screenshot: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    /// 清理所有截图（可用于重置或清理）
    func clearAllScreenshots() {
        for directory in [preferredScreenshotsDirectory, legacyScreenshotsDirectory] {
            do {
                try FileManager.default.removeItem(at: directory)
            } catch CocoaError.fileNoSuchFile {
                continue
            } catch {
                logger.error("Failed to clear screenshots directory: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    /// 获取截图文件大小（字节）
    func getCurrentScreenshotSize() -> Int64? {
        let fileURL = currentScreenshotFileURL
        
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

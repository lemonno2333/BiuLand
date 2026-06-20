import MobileCoreServices
import os
import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let statusLabel = UILabel()
    private let logger = Logger(subsystem: "com.leo.BiuLand", category: "shareExtension")
    private var didStartRecognition = false

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard didStartRecognition == false else { return }
        didStartRecognition = true

        Task {
            await recognizeSharedImage()
        }
    }

    private func configureView() {
        view.backgroundColor = UIColor.systemBackground

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "正在识别图片..."
        statusLabel.textColor = UIColor.label
        statusLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center

        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @MainActor
    private func recognizeSharedImage() async {
        do {
            let imageData = try await loadSharedImageData()
            let lines = try await OCRService.shared.recognizeTextLines(from: imageData)

            guard let candidate = CodeExtractor.bestCode(from: lines) else {
                let preview = lines.map(\.text).prefix(6).joined(separator: " / ")
                let message = preview.isEmpty ? "未识别到文字。" : "未识别到有效取码。"
                finish(message)
                return
            }

            let hasScreenshot = (try? ScreenshotManager.shared.saveCurrentScreenshot(imageData)) != nil
            PickupCodeHistoryStore.saveCurrent(
                code: candidate.code,
                context: candidate.reason,
                icon: candidate.icon,
                brandIconName: candidate.brandIconName,
                brandName: candidate.brandName,
                category: candidate.category,
                confidence: candidate.score,
                hasScreenshot: hasScreenshot,
                needsLiveActivityRestore: true
            )

            finish("已识别取码 \(candidate.code)，打开 BiuLand 后会更新实时活动。")
        } catch {
            logger.error("Failed to recognize shared image: \(error.localizedDescription, privacy: .public)")
            finish("识别失败：\(error.localizedDescription)")
        }
    }

    private func loadSharedImageData() async throws -> Data {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let providers = extensionItem.attachments else {
            throw ShareExtensionError.noImage
        }

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                return try await loadImageData(from: provider, typeIdentifier: UTType.image.identifier)
            }

            if provider.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                return try await loadImageData(from: provider, typeIdentifier: kUTTypeImage as String)
            }
        }

        throw ShareExtensionError.noImage
    }

    private func loadImageData(from provider: NSItemProvider, typeIdentifier: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                do {
                    if let data = item as? Data {
                        continuation.resume(returning: data)
                    } else if let url = item as? URL {
                        continuation.resume(returning: try Data(contentsOf: url))
                    } else if let image = item as? UIImage,
                              let data = image.jpegData(compressionQuality: 0.92) {
                        continuation.resume(returning: data)
                    } else {
                        continuation.resume(throwing: ShareExtensionError.unsupportedImage)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @MainActor
    private func finish(_ message: String) {
        statusLabel.text = message

        Task {
            try? await Task.sleep(nanoseconds: 850_000_000)
            extensionContext?.completeRequest(returningItems: nil)
        }
    }
}

private enum ShareExtensionError: LocalizedError {
    case noImage
    case unsupportedImage

    var errorDescription: String? {
        switch self {
        case .noImage:
            return "未收到可识别的图片。"
        case .unsupportedImage:
            return "图片格式暂不支持。"
        }
    }
}

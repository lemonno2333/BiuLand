import Foundation
@preconcurrency import Vision
import UIKit

struct RecognizedTextLine: Hashable {
    let text: String
    let confidence: Float
    let boundingBox: CGRect
    let imageSize: CGSize
}

enum OCRServiceError: Error {
    case invalidImage
}

final class OCRService {
    static let shared = OCRService()
    private init() {}

    func recognizeLines(from imageData: Data) async throws -> [String] {
        try await recognizeTextLines(from: imageData).map(\.text)
    }

    func recognizeTextLines(from imageData: Data) async throws -> [RecognizedTextLine] {
        guard let image = UIImage(data: imageData),
              let cgImage = image.cgImage else {
            throw OCRServiceError.invalidImage
        }
        return try await recognizeTextLines(from: cgImage)
    }

    func recognizeLines(from cgImage: CGImage) async throws -> [String] {
        try await recognizeTextLines(from: cgImage).map(\.text)
    }

    func recognizeTextLines(from cgImage: CGImage) async throws -> [RecognizedTextLine] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { observation -> RecognizedTextLine? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return RecognizedTextLine(
                        text: candidate.string,
                        confidence: candidate.confidence,
                        boundingBox: observation.boundingBox,
                        imageSize: CGSize(width: cgImage.width, height: cgImage.height)
                    )
                }
                continuation.resume(returning: lines)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.minimumTextHeight = 0.015
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
            request.automaticallyDetectsLanguage = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

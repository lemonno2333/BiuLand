import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var resultText = "请选择一张截图，或通过快捷指令触发识别。"
    @State private var parsedCode = "-"
    @State private var recognizedLines: [RecognizedTextLine] = []
    @State private var debugReport: CodeExtractionDebugReport?
    @State private var showDebug = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("取码识别")
                        .font(.largeTitle.bold())

                    Text(resultText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text(parsedCode)
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .padding(.vertical, 8)

                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("从相册选择截图", systemImage: "photo")
                    }
                    .buttonStyle(.borderedProminent)

                    Button("清除当前 Live Activity") {
                        Task {
                            await LiveActivityManager.shared.endAll()
                            await MainActor.run {
                                resultText = "已清除。"
                                parsedCode = "-"
                            }
                        }
                    }
                    .buttonStyle(.bordered)

                    debugView
                }
                .padding(20)
            }
            .navigationTitle("BiuLand")
            .onChange(of: selectedItem) { newItem in
                guard let newItem else { return }
                Task {
                    await handlePhotoItem(newItem)
                }
            }
        }
    }

    private func handlePhotoItem(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                await MainActor.run { resultText = "无法读取图片数据。" }
                return
            }
            let lines = try await OCRService.shared.recognizeTextLines(from: data)
            let report = CodeExtractor.debugReport(from: lines)
            guard let candidate = report.selected else {
                await MainActor.run {
                    let preview = lines.map(\.text).prefix(8).joined(separator: " / ")
                    resultText = preview.isEmpty ? "未识别到文字。" : "未识别到有效取码。OCR：\(preview)"
                    parsedCode = "-"
                    recognizedLines = lines
                    debugReport = report
                }
                return
            }

            try await LiveActivityManager.shared.upsert(
                code: candidate.code,
                context: candidate.reason,
                confidence: candidate.score
            )

            await MainActor.run {
                resultText = "识别成功，已更新实时活动。"
                parsedCode = candidate.code
                recognizedLines = lines
                debugReport = report
            }
        } catch {
            await MainActor.run {
                resultText = "识别失败：\(error.localizedDescription)"
                parsedCode = "-"
            }
        }
    }

    private var debugView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("调试信息", isOn: $showDebug)
                .font(.headline)

            if showDebug {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Selected: \(debugReport?.selected?.code ?? "-")")
                        .font(.subheadline.bold())

                    Text("Candidates")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    if let debugReport, debugReport.candidates.isEmpty == false {
                        ForEach(debugReport.candidates.prefix(20)) { candidate in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(candidate.normalizedToken)  score \(format(candidate.score))")
                                    .font(.system(.caption, design: .monospaced).bold())
                                Text("raw: \(candidate.rawToken) | \(candidate.reason) | spatial \(format(candidate.spatialKeywordBoost)) | conf \(format(Double(candidate.confidence)))")
                                    .font(.system(.caption2, design: .monospaced))
                                Text("line: \(candidate.sourceText)")
                                    .font(.caption2)
                                Text("visual: \(candidate.visualLine)")
                                    .font(.caption2)
                                Text("box: \(formatBox(candidate.boundingBox))")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Text("px: \(formatPixelBox(candidate.boundingBox, imageSize: candidate.imageSize))")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        }
                    } else {
                        Text("No candidates")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("OCR Lines")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    ForEach(Array(recognizedLines.enumerated()), id: \.offset) { index, line in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("#\(index) \(line.text)")
                                .font(.system(.caption, design: .monospaced))
                            Text("conf \(format(Double(line.confidence))) | box \(formatBox(line.boundingBox))")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text("px \(formatPixelBox(line.boundingBox, imageSize: line.imageSize))")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }

    private func formatBox(_ box: CGRect) -> String {
        "x:\(format(box.minX)) y:\(format(box.minY)) w:\(format(box.width)) h:\(format(box.height))"
    }

    private func formatPixelBox(_ box: CGRect, imageSize: CGSize) -> String {
        guard imageSize.width > 0, imageSize.height > 0 else { return "-" }
        let x = box.minX * imageSize.width
        let y = (1 - box.maxY) * imageSize.height
        let width = box.width * imageSize.width
        let height = box.height * imageSize.height
        return "x:\(Int(x.rounded())) y:\(Int(y.rounded())) w:\(Int(width.rounded())) h:\(Int(height.rounded()))"
    }
}

import SwiftUI
import PhotosUI

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedItem: PhotosPickerItem?
    @State private var resultText = "请选择一张截图，或通过快捷指令触发识别。"
    @State private var parsedCode = "-"
    @State private var currentIcon = "fork.knife"
    @State private var currentReason = "等待识别"
    @State private var historyItems = PickupCodeHistoryStore.load()
    @State private var recognizedLines: [RecognizedTextLine] = []
    @State private var debugReport: CodeExtractionDebugReport?
    @State private var showDebug = false
    @State private var showManualAdd = false
    @State private var manualCode = ""
    @State private var manualIcon = "fork.knife"

    var body: some View {
        NavigationStack {
            ZStack {
                DiffuseBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        currentSnapshot

                        historyView

                        debugView
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("BiuLand")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                historyItems = PickupCodeHistoryStore.load()
            }
            .onChange(of: selectedItem) { newItem in
                guard let newItem else { return }
                Task {
                    await handlePhotoItem(newItem)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Image(systemName: "photo")
                    }
                    .accessibilityLabel("从相册选择截图")

                    Button {
                        showManualAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("手动添加取码")
                }
            }
            .sheet(isPresented: $showManualAdd) {
                manualAddSheet
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
                    currentIcon = "fork.knife"
                    currentReason = "未识别"
                    recognizedLines = lines
                    debugReport = report
                }
                return
            }

            try await LiveActivityManager.shared.upsert(
                code: candidate.code,
                context: candidate.reason,
                icon: candidate.icon,
                confidence: candidate.score
            )
            let updatedHistory = PickupCodeHistoryStore.add(
                code: candidate.code,
                context: candidate.reason,
                icon: candidate.icon,
                confidence: candidate.score
            )

            await MainActor.run {
                resultText = "识别成功，已更新实时活动。"
                parsedCode = candidate.code
                currentIcon = candidate.icon
                currentReason = candidate.reason
                historyItems = updatedHistory
                recognizedLines = lines
                debugReport = report
            }
        } catch {
            await MainActor.run {
                resultText = "识别失败：\(error.localizedDescription)"
                parsedCode = "-"
                currentIcon = "fork.knife"
                currentReason = "识别失败"
            }
        }
    }

    private var currentSnapshot: some View {
        liveActivitySnapshot(
            icon: currentIcon,
            title: parsedCode == "-" ? "当前取码" : "当前取码",
            code: parsedCode,
            context: currentReason,
            date: nil,
            isPlaceholder: parsedCode == "-"
        )
    }

    private var historyView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("历史取码")
                    .font(.headline)
                Spacer()
                Text("\(historyItems.count)/10")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if historyItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("暂无历史")
                        .font(.subheadline.bold())
                    Text("还没有历史记录，请点击右上角选取截图或手动录入")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 10) {
                    ForEach(historyItems) { item in
                        liveActivitySnapshot(
                            icon: item.icon,
                            title: "历史取码",
                            code: item.code,
                            context: item.context,
                            date: item.createdAt,
                            isPlaceholder: false
                        )
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private var manualAddSheet: some View {
        NavigationStack {
            Form {
                Section("取码") {
                    TextField("输入取餐码/取件码", text: $manualCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }

                Section("类型") {
                    Picker("类型", selection: $manualIcon) {
                        Label("食物", systemImage: "fork.knife")
                            .tag("fork.knife")
                        Label("饮品", systemImage: "cup.and.saucer.fill")
                            .tag("cup.and.saucer.fill")
                        Label("快递", systemImage: "shippingbox.fill")
                            .tag("shippingbox.fill")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("手动添加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showManualAdd = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            await handleManualAdd()
                        }
                    }
                    .disabled(trimmedManualCode.isEmpty)
                }
            }
        }
    }

    private func liveActivitySnapshot(
        icon: String,
        title: String,
        code: String,
        context: String,
        date: Date?,
        isPlaceholder: Bool
    ) -> some View {
        ZStack(alignment: .bottomTrailing) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 42, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(snapshotPrimaryColor)
                    .frame(width: 58)
                    .frame(maxHeight: .infinity, alignment: .center)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(snapshotSecondaryColor)
                        Spacer(minLength: 8)
                        if let date {
                            Text(formatDate(date))
                                .font(.caption2)
                                .foregroundStyle(snapshotTertiaryColor)
                        }
                    }

                    Text(isPlaceholder ? "----" : code)
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)
                        .foregroundStyle(snapshotPrimaryColor)

                    if !isPlaceholder && code.count > 4 && date == nil {
                        HStack {
                            Spacer()
                            localCompletionButton(icon: icon)
                        }
                        .padding(.top, 6)
                    }
                }
            }

            if !isPlaceholder && code.count <= 4 && date == nil {
                localCompletionButton(icon: icon)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(PickupCodeGlassCardStyle())
    }

    @ViewBuilder
    private func localCompletionButton(icon: String) -> some View {
        let button = Button {
            Task {
                await LiveActivityManager.shared.endAll()
                await MainActor.run {
                    parsedCode = "-"
                    currentIcon = "fork.knife"
                    currentReason = "等待识别"
                    resultText = "已清除。"
                }
            }
        } label: {
            Label(completionTitle(for: icon), systemImage: "checkmark.circle.fill")
                .font(.caption.bold())
                .labelStyle(.titleAndIcon)
        }

        if #available(iOS 26.0, *) {
            button
                .buttonStyle(.glassProminent)
                .tint(snapshotButtonTint)
                .foregroundStyle(snapshotPrimaryColor)
        } else {
            button
                .buttonStyle(.bordered)
                .tint(snapshotButtonTint)
                .foregroundStyle(snapshotPrimaryColor)
        }
    }

    private func completionTitle(for icon: String) -> String {
        icon == "shippingbox.fill" ? "已经取件" : "已经取餐"
    }

    private var snapshotPrimaryColor: Color {
        colorScheme == .dark ? .white : Color(red: 0.08, green: 0.09, blue: 0.12)
    }

    private var snapshotSecondaryColor: Color {
        snapshotPrimaryColor.opacity(colorScheme == .dark ? 0.68 : 0.62)
    }

    private var snapshotTertiaryColor: Color {
        snapshotPrimaryColor.opacity(colorScheme == .dark ? 0.52 : 0.46)
    }

    private var snapshotButtonTint: Color {
        colorScheme == .dark ? .white.opacity(0.18) : .black.opacity(0.08)
    }

    private var trimmedManualCode: String {
        manualCode.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func handleManualAdd() async {
        let code = trimmedManualCode
        guard code.isEmpty == false else { return }
        let reason = "手动添加"

        do {
            try await LiveActivityManager.shared.upsert(
                code: code,
                context: reason,
                icon: manualIcon,
                confidence: 1
            )
            let updatedHistory = PickupCodeHistoryStore.add(
                code: code,
                context: reason,
                icon: manualIcon,
                confidence: 1
            )

            await MainActor.run {
                parsedCode = code
                currentIcon = manualIcon
                currentReason = reason
                resultText = "已手动添加，已更新实时活动。"
                historyItems = updatedHistory
                manualCode = ""
                showManualAdd = false
            }
        } catch {
            await MainActor.run {
                resultText = "手动添加失败：\(error.localizedDescription)"
            }
        }
    }

    private var debugView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("调试信息", isOn: $showDebug)
                .font(.headline)

            if showDebug {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Selected: \(debugReport?.selected.map { "\(iconLabel($0.icon)) \($0.code)" } ?? "-")")
                        .font(.subheadline.bold())

                    Text("Candidates")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    if let debugReport, debugReport.candidates.isEmpty == false {
                        ForEach(debugReport.candidates.prefix(20)) { candidate in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(iconLabel(candidate.icon)) \(candidate.normalizedToken)  score \(format(candidate.score))")
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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
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

    private func iconLabel(_ icon: String) -> String {
        switch icon {
        case "cup.and.saucer.fill":
            return "饮品"
        case "shippingbox.fill":
            return "快递"
        default:
            return "食物"
        }
    }
}

private struct PickupCodeGlassCardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
    }

    private var baseTint: Color {
        colorScheme == .dark ? .black.opacity(0.46) : .white.opacity(0.58)
    }

    private var strokeTint: Color {
        colorScheme == .dark ? .white.opacity(0.16) : .white.opacity(0.78)
    }

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background(baseTint, in: shape)
                .glassEffect(.regular.tint(baseTint), in: shape)
                .overlay(shape.stroke(strokeTint, lineWidth: 1))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.20 : 0.08), radius: 18, y: 10)
        } else {
            content
                .background(.thinMaterial, in: shape)
                .background(baseTint, in: shape)
                .overlay(shape.stroke(strokeTint, lineWidth: 1))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.20 : 0.08), radius: 18, y: 10)
        }
    }
}

import SwiftUI
import PhotosUI
import os

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedItem: PhotosPickerItem?
    @State private var resultText = "请选择一张截图，或通过快捷指令触发识别。"
    @State private var parsedCode = "-"
    @State private var currentIcon = "fork.knife"
    @State private var currentBrandIconName: String?
    @State private var currentReason = "等待识别"
    @State private var currentBrandName: String?
    @State private var currentExpiresAt: Date?
    @State private var historyItems = PickupCodeHistoryStore.load()
    @State private var recognizedLines: [RecognizedTextLine] = []
    @State private var debugReport: CodeExtractionDebugReport?
    @State private var showDebug = false
    @State private var showDebugToggle = false
    @State private var currentSnapshotTapCount = 0
    @State private var showDebugBanner = false
    @State private var debugBannerMessage = ""
    @State private var currentExpirationTask: Task<Void, Never>?
    @State private var liveActivityMonitorTask: Task<Void, Never>?
    @State private var showCodeEditor = false
    @State private var codeEditorMode: CodeEditorMode = .add
    @State private var editorCode = ""
    @State private var editorContext = ""
    @State private var editorIcon = "fork.knife"
    @State private var showScreenshotViewer = false
    @State private var screenshotImage: UIImage?
    @State private var screenshotMetadata: ScreenshotMetadata?
    @State private var lastProcessedImageData: Data?
    @State private var revealedHistoryItemID: UUID?
    @State private var historyRowDragOffsets: [UUID: CGFloat] = [:]
    private let logger = Logger(subsystem: "com.leo.BiuLand", category: "ui")

    var body: some View {
        NavigationStack {
            ZStack {
                DiffuseBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        currentSnapshot

                        historyView

                        debugView

                        creditsView
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)

                debugModeBanner
                    .padding(.top, 4)
                    .offset(y: showDebugBanner ? -44 : -112)
                    .opacity(showDebugBanner ? 1 : 0)
                    .allowsHitTesting(showDebugBanner)
                    .animation(.spring(response: 0.32, dampingFraction: 0.82), value: showDebugBanner)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenScreenshotViewer"))) { _ in
                // 从 Live Activity 打开截图查看器
                if ScreenshotManager.shared.currentScreenshotExists() {
                    showScreenshotViewer = true
                }
            }
            .navigationTitle(showDebugBanner ? "" : "BiuLand")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                refreshFromHistory()
                restoreLiveActivityIfNeeded()
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    refreshFromHistory()
                    restoreLiveActivityIfNeeded()
                }
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
                        presentAddEditor()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("手动添加取码")
                }
            }
            .sheet(isPresented: $showCodeEditor) {
                codeEditorSheet
            }
            .sheet(isPresented: $showScreenshotViewer) {
                screenshotViewerSheet
            }
        }
    }

    private func handlePhotoItem(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                await MainActor.run { resultText = "无法读取图片数据。" }
                return
            }

            // 保存图片数据供后续使用
            await MainActor.run {
                lastProcessedImageData = data
            }
            let lines = try await OCRService.shared.recognizeTextLines(from: data)
            let report = CodeExtractor.debugReport(from: lines)
            guard let candidate = report.selected else {
                await MainActor.run {
                    let preview = lines.map(\.text).prefix(8).joined(separator: " / ")
                    resultText = preview.isEmpty ? "未识别到文字。" : "未识别到有效取码。OCR：\(preview)"
                    parsedCode = "-"
                    currentIcon = "fork.knife"
                    currentBrandIconName = nil
                    currentReason = "未识别"
                    currentBrandName = nil
                    recognizedLines = lines
                    debugReport = report
                    lastProcessedImageData = nil
                }
                return
            }

            let current = try await LiveActivityManager.shared.upsert(
                code: candidate.code,
                context: candidate.reason,
                icon: candidate.icon,
                brandIconName: candidate.brandIconName,
                brandName: candidate.brandName,
                category: candidate.category,
                confidence: candidate.score,
                imageData: data
            )

            await MainActor.run {
                resultText = current.hasScreenshot ? "识别成功，已更新实时活动。" : "识别成功，已更新实时活动，但截图保存失败。"
                applyCurrent(current)
                historyItems = PickupCodeHistoryStore.load()
                recognizedLines = lines
                debugReport = report
            }
        } catch {
            await MainActor.run {
                resultText = "识别失败：\(error.localizedDescription)"
                parsedCode = "-"
                currentIcon = "fork.knife"
                currentBrandIconName = nil
                currentReason = "识别失败"
                currentBrandName = nil
            }
        }
    }

    private var currentSnapshot: some View {
        liveActivitySnapshot(
            icon: currentIcon,
            brandIconName: currentBrandIconName,
            title: currentBrandName ?? "当前取码",
            code: parsedCode,
            context: currentReason,
            expiresAt: currentExpiresAt,
            date: nil,
            isPlaceholder: parsedCode == "-"
        )
        .contentShape(Rectangle())
        .onTapGesture {
            handleCurrentSnapshotTap()
        }
    }

    private func refreshFromHistory() {
        historyItems = PickupCodeHistoryStore.archiveCurrentIfExpired()

        if let current = PickupCodeHistoryStore.loadCurrent() {
            applyCurrent(current)
            resultText = "已同步最新取码。"
        } else {
            resetCurrentSnapshot()
        }
    }

    private func restoreLiveActivityIfNeeded() {
        guard LiveActivityManager.shared.hasActiveActivities == false,
              PickupCodeHistoryStore.needsLiveActivityRestore(),
              let current = PickupCodeHistoryStore.loadCurrent() else {
            return
        }

        Task {
            do {
                let restored = try await LiveActivityManager.shared.upsert(
                    code: current.code,
                    context: current.context,
                    icon: current.icon,
                    brandIconName: current.brandIconName,
                    brandName: current.brandName,
                    category: current.category,
                    confidence: current.confidence,
                    preserveExistingScreenshot: current.hasScreenshot
                )

                await MainActor.run {
                    PickupCodeHistoryStore.setNeedsLiveActivityRestore(false)
                    applyCurrent(restored)
                    resultText = "已同步分享识别结果，并更新实时活动。"
                }
            } catch {
                await MainActor.run {
                    applyCurrent(current)
                    resultText = "已同步分享识别结果，但实时活动更新失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func applyCurrent(_ current: CurrentPickupCodeItem) {
        parsedCode = current.code
        currentIcon = current.icon
        currentBrandIconName = current.brandIconName
        currentReason = current.context
        currentBrandName = current.brandName
        currentExpiresAt = current.expiresAt
        scheduleCurrentExpiration(for: current)
        scheduleLiveActivityCompletionMonitor()
    }

    private func resetCurrentSnapshot() {
        currentExpirationTask?.cancel()
        currentExpirationTask = nil
        liveActivityMonitorTask?.cancel()
        liveActivityMonitorTask = nil
        parsedCode = "-"
        currentIcon = "fork.knife"
        currentBrandIconName = nil
        currentReason = "等待识别"
        currentBrandName = nil
        currentExpiresAt = nil
    }

    private func scheduleCurrentExpiration(for current: CurrentPickupCodeItem) {
        currentExpirationTask?.cancel()

        let delay = max(0, current.expiresAt.timeIntervalSinceNow)
        currentExpirationTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard Task.isCancelled == false else { return }

            await LiveActivityManager.shared.endAll()
            await MainActor.run {
                historyItems = PickupCodeHistoryStore.archiveCurrentIfExpired()
                if PickupCodeHistoryStore.loadCurrent() == nil {
                    resetCurrentSnapshot()
                    resultText = "当前取码已过期，已归档到历史。"
                }
            }
        }
    }

    private func scheduleLiveActivityCompletionMonitor() {
        liveActivityMonitorTask?.cancel()
        liveActivityMonitorTask = Task {
            while Task.isCancelled == false {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard Task.isCancelled == false else { return }
                guard PickupCodeHistoryStore.loadCurrent() != nil else { return }

                if LiveActivityManager.shared.hasActiveActivities == false {
                    await MainActor.run {
                        historyItems = PickupCodeHistoryStore.completeCurrent()
                        resetCurrentSnapshot()
                        resultText = "已同步已完成取码。"
                    }
                    return
                }
            }
        }
    }

    private func handleCurrentSnapshotTap() {
        currentSnapshotTapCount += 1
        guard currentSnapshotTapCount >= 5 else { return }

        currentSnapshotTapCount = 0
        showDebugToggle.toggle()
        if showDebugToggle == false {
            showDebug = false
        }
        showDebugModeBanner(showDebugToggle ? "调试模式已显示" : "调试模式已隐藏")
    }

    private func showDebugModeBanner(_ message: String) {
        debugBannerMessage = message
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            showDebugBanner = true
        }

        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                guard debugBannerMessage == message else { return }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    showDebugBanner = false
                }
            }
        }
    }

    private var historyView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("历史取码")
                    .font(.headline)
                Spacer()
                Text("\(historyItems.count)/5")
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
                        historyRow(for: item)
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private var codeEditorSheet: some View {
        NavigationStack {
            Form {
                Section("取码") {
                    TextField("输入取餐码/取件码", text: $editorCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }

                Section("备注") {
                    TextField("例如门店、柜机或取餐位置", text: $editorContext)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("类型") {
                    Picker("类型", selection: $editorIcon) {
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
            .navigationTitle(codeEditorMode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showCodeEditor = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(codeEditorMode.confirmationTitle) {
                        Task {
                            await handleCodeEditorSave()
                        }
                    }
                    .disabled(trimmedEditorCode.isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private func liveActivitySnapshot(
        icon: String,
        brandIconName: String? = nil,
        title: String,
        code: String,
        context: String,
        expiresAt: Date?,
        date: Date?,
        isPlaceholder: Bool
    ) -> some View {
        let display = PickupCodeDisplayModel(
            icon: icon,
            brandIconName: brandIconName,
            title: title,
            code: code,
            context: context,
            isPlaceholder: isPlaceholder
        )

        ZStack(alignment: .bottomTrailing) {
            HStack(spacing: 16) {
                PickupCodeIconView(
                    icon: display.icon,
                    brandIconName: display.brandIconName,
                    size: 58,
                    systemColor: snapshotPrimaryColor,
                    brandShadowColor: .black.opacity(colorScheme == .dark ? 0.26 : 0.10)
                )
                    .frame(width: 58, height: 58)
                    .frame(maxHeight: .infinity, alignment: .center)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(display.title)
                            .font(.caption)
                            .foregroundStyle(snapshotSecondaryColor)
                        Spacer(minLength: 8)
                        if let date {
                            Text(formatDate(date))
                                .font(.caption2)
                                .foregroundStyle(snapshotTertiaryColor)
                        } else if let expiresAt, !isPlaceholder {
                            expirationBadge(expiresAt: expiresAt)
                        }
                    }

                    PickupCodeTextBlock(
                        model: display,
                        codeSize: 34,
                        titleColor: snapshotSecondaryColor,
                        codeColor: snapshotPrimaryColor,
                        contextColor: snapshotSecondaryColor,
                        contextFont: .caption,
                        contextScale: 0.75,
                        spacing: 5,
                        showsTitle: false
                    )

                    // 按钮区域 - 始终在最下方，单独一行
                    if display.isPlaceholder == false && date == nil {
                        HStack(spacing: 10) {
                            Spacer()
                            editCurrentButton
                            if ScreenshotManager.shared.currentScreenshotExists() {
                                screenshotButton
                            }
                            localCompletionButton(icon: icon)
                        }
                        .padding(.top, 6)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(PickupCodeGlassCardStyle())
    }

    @ViewBuilder
    private func localCompletionButton(icon: String) -> some View {
        compactSnapshotAction(
            systemImage: "checkmark.circle.fill",
            accessibilityLabel: PickupCodeDisplayModel.completionTitle(for: icon),
            isPrimary: true
        ) {
            Task {
                let updatedHistory = PickupCodeHistoryStore.completeCurrent()
                await LiveActivityManager.shared.endAll()
                await MainActor.run {
                    historyItems = updatedHistory
                    resetCurrentSnapshot()
                    resultText = "已完成，已归档到历史。"
                }
            }
        }
    }

    @ViewBuilder
    private var editCurrentButton: some View {
        compactSnapshotAction(systemImage: "pencil", accessibilityLabel: "编辑") {
            presentCurrentEditor()
        }
    }

    private func compactSnapshotAction(
        systemImage: String,
        accessibilityLabel: String,
        isPrimary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let fill = isPrimary ? Color.accentColor.opacity(colorScheme == .dark ? 0.38 : 0.24) : snapshotButtonTint
        let foreground = isPrimary ? Color.accentColor : snapshotPrimaryColor

        return Button(action: action) {
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 42, height: 42)
                .foregroundStyle(foreground)
                .background(fill, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private func historyRow(for item: PickupCodeHistoryItem) -> some View {
        let actionWidth: CGFloat = 84
        let baseOffset = revealedHistoryItemID == item.id ? -actionWidth : 0
        let dragOffset = historyRowDragOffsets[item.id, default: 0]
        let horizontalOffset = min(0, max(-actionWidth, baseOffset + dragOffset))
        let revealWidth = -horizontalOffset
        let revealProgress = min(1, revealWidth / actionWidth)

        ZStack(alignment: .trailing) {
            liveActivitySnapshot(
                icon: item.icon,
                brandIconName: item.brandIconName,
                title: item.brandName ?? "历史取码",
                code: item.code,
                context: item.context,
                expiresAt: nil,
                date: item.createdAt,
                isPlaceholder: false
            )
            .offset(x: horizontalOffset)
            .contentShape(Rectangle())
            .onTapGesture {
                if revealedHistoryItemID == item.id {
                    closeHistorySwipeActions()
                }
            }
            .gesture(historyRowDragGesture(for: item, actionWidth: actionWidth))
            .animation(.spring(response: 0.28, dampingFraction: 0.86), value: revealedHistoryItemID)
            .animation(.spring(response: 0.28, dampingFraction: 0.86), value: historyRowDragOffsets[item.id, default: 0])

            if revealWidth > 0 {
                restoreHistorySwipeAction(for: item, actionWidth: actionWidth)
                    .frame(width: actionWidth)
                    .opacity(revealProgress)
                    .scaleEffect(0.86 + 0.14 * revealProgress)
                    .mask(alignment: .trailing) {
                        Rectangle()
                            .frame(width: revealWidth)
                    }
                    .transition(.opacity)
            }
        }
    }

    private func restoreHistorySwipeAction(for item: PickupCodeHistoryItem, actionWidth: CGFloat) -> some View {
        Button {
            closeHistorySwipeActions()
            Task {
                await restoreHistoryItem(item)
            }
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 23, weight: .semibold))
                .frame(width: 58, height: 58)
                .foregroundStyle(.white)
                .background(Color.accentColor, in: Circle())
        }
        .buttonStyle(.plain)
        .frame(width: actionWidth, alignment: .trailing)
        .frame(maxHeight: .infinity)
        .padding(.trailing, 2)
        .accessibilityLabel("重新显示")
    }

    private func historyRowDragGesture(for item: PickupCodeHistoryItem, actionWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if revealedHistoryItemID != item.id && value.translation.width < 0 {
                    revealedHistoryItemID = nil
                }
                historyRowDragOffsets[item.id] = value.translation.width
            }
            .onEnded { value in
                defer {
                    historyRowDragOffsets[item.id] = nil
                }

                let shouldReveal = value.translation.width < -44 || value.predictedEndTranslation.width < -actionWidth * 0.8
                let shouldHide = value.translation.width > 32 || value.predictedEndTranslation.width > actionWidth * 0.45

                if shouldReveal {
                    revealedHistoryItemID = item.id
                } else if shouldHide {
                    closeHistorySwipeActions()
                } else if revealedHistoryItemID != item.id {
                    closeHistorySwipeActions()
                }
            }
    }

    private func closeHistorySwipeActions() {
        revealedHistoryItemID = nil
        historyRowDragOffsets.removeAll()
    }

    private func restoreHistoryItem(_ item: PickupCodeHistoryItem) async {
        do {
            let current = try await LiveActivityManager.shared.upsert(
                code: item.code,
                context: item.context,
                icon: item.icon,
                brandIconName: item.brandIconName,
                brandName: item.brandName,
                category: item.category,
                confidence: item.confidence
            )

            await MainActor.run {
                applyCurrent(current)
                historyItems = PickupCodeHistoryStore.load()
                resultText = "已重新显示历史取码。"
            }
        } catch {
            await MainActor.run {
                resultText = "重新显示失败：\(error.localizedDescription)"
            }
        }
    }

    private func category(for icon: String) -> PickupCategory {
        switch icon {
        case "cup.and.saucer.fill":
            return .drink
        case "shippingbox.fill":
            return .express
        default:
            return .food
        }
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

    private var trimmedEditorCode: String {
        editorCode.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedEditorContext: String {
        editorContext.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func presentAddEditor() {
        codeEditorMode = .add
        editorCode = ""
        editorContext = ""
        editorIcon = "fork.knife"
        showCodeEditor = true
    }

    private func presentCurrentEditor() {
        guard parsedCode != "-" else { return }
        codeEditorMode = .editCurrent
        editorCode = parsedCode
        editorContext = PickupCodeDisplayModel.visibleContext(for: currentReason).isEmpty ? "" : currentReason
        editorIcon = currentIcon
        showCodeEditor = true
    }

    private func handleCodeEditorSave() async {
        let code = trimmedEditorCode
        guard code.isEmpty == false else { return }
        let reason = trimmedEditorContext.isEmpty ? codeEditorMode.defaultContext : trimmedEditorContext
        let category = category(for: editorIcon)
        let shouldPreserveBrand = codeEditorMode == .editCurrent && editorIcon == currentIcon
        let shouldPreserveScreenshot = codeEditorMode == .editCurrent && ScreenshotManager.shared.currentScreenshotExists()

        do {
            let current = try await LiveActivityManager.shared.upsert(
                code: code,
                context: reason,
                icon: editorIcon,
                brandIconName: shouldPreserveBrand ? currentBrandIconName : nil,
                brandName: shouldPreserveBrand ? currentBrandName : nil,
                category: category,
                confidence: 1,
                preserveExistingScreenshot: shouldPreserveScreenshot
            )

            await MainActor.run {
                applyCurrent(current)
                resultText = codeEditorMode.successMessage
                historyItems = PickupCodeHistoryStore.load()
                editorCode = ""
                editorContext = ""
                showCodeEditor = false
            }
        } catch {
            await MainActor.run {
                resultText = "\(codeEditorMode.failurePrefix)：\(error.localizedDescription)"
            }
        }
    }

    @ViewBuilder
    private var debugView: some View {
        if showDebugToggle {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("调试信息", isOn: $showDebug)
                    .font(.headline)

                if showDebug {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Selected: \(debugReport?.selected.map { "\(iconLabel($0.icon)) \($0.code)" } ?? "-")")
                            .font(.subheadline.bold())

                        Text("Brand: \(brandDebugText(debugReport))")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)

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
    }

    private var debugModeBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: showDebugToggle ? "slider.horizontal.3" : "slider.horizontal.2.square")
                .font(.caption.bold())
            Text(debugBannerMessage)
                .font(.subheadline.bold())
        }
        .foregroundStyle(colorScheme == .dark ? .white : .black)
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .modifier(DebugModeBannerGlassStyle())
        .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
        .accessibilityLabel(debugBannerMessage)
    }

    private var creditsView: some View {
        VStack(spacing: 6) {
            Text("@Lemonno")
                .font(.caption.bold())

            HStack(spacing: 0) {
                Text("感谢 ")
                Link("Hyper Pick-up Code", destination: URL(string: "https://github.com/badnng/Hyper-pick-up-code")!)
                Text(" 的部分代码和灵感")
            }
            .font(.caption)
        }
        .foregroundStyle(.secondary)
        .tint(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
        .padding(.bottom, 24)
    }

    private func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    @ViewBuilder
    private func expirationBadge(expiresAt: Date) -> some View {
        TimelineView(.periodic(from: Date(), by: 30)) { timeline in
            Text(expirationText(expiresAt: expiresAt, now: timeline.date))
                .font(.caption2.bold())
                .foregroundStyle(expirationColor(expiresAt: expiresAt, now: timeline.date))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    expirationColor(expiresAt: expiresAt, now: timeline.date).opacity(colorScheme == .dark ? 0.18 : 0.12),
                    in: Capsule(style: .continuous)
                )
                .accessibilityLabel(expirationText(expiresAt: expiresAt, now: timeline.date))
        }
    }

    private func expirationText(expiresAt: Date, now: Date) -> String {
        let remaining = expiresAt.timeIntervalSince(now)
        if remaining <= 0 {
            return "已过期"
        }
        if remaining <= 3 * 60 {
            return "即将过期"
        }
        let minutes = max(1, Int(ceil(remaining / 60)))
        return "剩余 \(minutes) 分钟"
    }

    private func expirationColor(expiresAt: Date, now: Date) -> Color {
        let remaining = expiresAt.timeIntervalSince(now)
        if remaining <= 3 * 60 {
            return .orange
        }
        return snapshotSecondaryColor
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

    private func brandDebugText(_ report: CodeExtractionDebugReport?) -> String {
        guard let report else { return "-" }
        let location = report.pickupLocation ?? "-"
        guard let detection = report.brandDetection else {
            return "- · category \(report.category.rawValue) · location \(location)"
        }
        let terms = detection.matchedTerms.joined(separator: ",")
        return "\(detection.brand.name) · category \(detection.brand.category.rawValue) · score \(format(detection.score)) · location \(location) · \(terms)"
    }

    @ViewBuilder
    private var screenshotButton: some View {
        compactSnapshotAction(systemImage: "photo", accessibilityLabel: "查看截图") {
            showScreenshotViewer = true
        }
    }

    @ViewBuilder
    private var screenshotViewerSheet: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let image = screenshotImage {
                    ZoomableImage(image: image)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    ProgressView("加载中...")
                        .tint(.white)
                }

                if let screenshotMetadata {
                    Text(screenshotMetadataText(screenshotMetadata))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.82))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.black.opacity(0.46), in: Capsule(style: .continuous))
                        .padding(.bottom, 18)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
            .navigationTitle("查看截图")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        showScreenshotViewer = false
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.8), for: .navigationBar)
        }
        .onAppear {
            loadScreenshotImage()
        }
        .onDisappear {
            screenshotImage = nil
            screenshotMetadata = nil
        }
    }

    private func loadScreenshotImage() {
        Task {
            do {
                let data = try ScreenshotManager.shared.loadCurrentScreenshot()
                let metadata = ScreenshotManager.shared.currentScreenshotMetadata()
                guard let image = UIImage(data: data) else {
                    throw ScreenshotManagerError.loadFailure
                }

                await MainActor.run {
                    screenshotImage = image
                    screenshotMetadata = metadata
                }
            } catch {
                logger.error("Failed to load screenshot viewer image: \(error.localizedDescription, privacy: .public)")
                await MainActor.run {
                    showScreenshotViewer = false
                    resultText = "截图加载失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func screenshotMetadataText(_ metadata: ScreenshotMetadata) -> String {
        let width = Int(metadata.pixelSize.width.rounded())
        let height = Int(metadata.pixelSize.height.rounded())
        return "\(width)x\(height) · \(formatByteCount(metadata.fileSize))"
    }

    private func formatByteCount(_ byteCount: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }

}

private enum CodeEditorMode: Equatable {
    case add
    case editCurrent

    var title: String {
        switch self {
        case .add:
            return "手动添加"
        case .editCurrent:
            return "编辑取码"
        }
    }

    var confirmationTitle: String {
        switch self {
        case .add:
            return "保存"
        case .editCurrent:
            return "更新"
        }
    }

    var defaultContext: String {
        switch self {
        case .add:
            return "手动添加"
        case .editCurrent:
            return "手动编辑"
        }
    }

    var successMessage: String {
        switch self {
        case .add:
            return "已手动添加，已更新实时活动。"
        case .editCurrent:
            return "已更新当前取码。"
        }
    }

    var failurePrefix: String {
        switch self {
        case .add:
            return "手动添加失败"
        case .editCurrent:
            return "编辑失败"
        }
    }
}

private struct ZoomableImage: View {
    let image: UIImage

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .contentShape(Rectangle())
                .gesture(dragGesture.simultaneously(with: magnificationGesture))
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                        reset()
                    }
                }
        }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 1), 5)
                if scale == 1 {
                    offset = .zero
                }
            }
            .onEnded { _ in
                if scale < 1.04 {
                    reset()
                } else {
                    lastScale = scale
                    lastOffset = offset
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private func reset() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
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

private struct DebugModeBannerGlassStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    private var shape: Capsule {
        Capsule(style: .continuous)
    }

    private var fallbackFill: Color {
        colorScheme == .dark ? .black.opacity(0.86) : .white.opacity(0.92)
    }

    private var glassTint: Color {
        colorScheme == .dark ? .black.opacity(0.34) : .white.opacity(0.42)
    }

    private var strokeTint: Color {
        colorScheme == .dark ? .white.opacity(0.18) : .white.opacity(0.72)
    }

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background(glassTint, in: shape)
                .glassEffect(.regular.tint(glassTint), in: shape)
                .overlay(shape.stroke(strokeTint, lineWidth: 1))
        } else {
            content
                .background(fallbackFill, in: shape)
                .overlay(shape.stroke(strokeTint, lineWidth: 1))
        }
    }
}

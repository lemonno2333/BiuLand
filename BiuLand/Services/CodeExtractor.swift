import Foundation
import CoreGraphics

struct CodeCandidate: Hashable {
    let code: String
    let score: Double
    let reason: String
    let icon: String
    let brandIconName: String?
    let brandName: String?
    let category: PickupCategory?
}

struct CodeExtractionDebugCandidate: Hashable, Identifiable {
    let id = UUID()
    let rawToken: String
    let normalizedToken: String
    let score: Double
    let reason: String
    let sourceText: String
    let normalizedLine: String
    let visualLine: String
    let context: String
    let confidence: Float
    let boundingBox: CGRect
    let imageSize: CGSize
    let spatialKeywordBoost: Double
    let icon: String
}

struct CodeExtractionDebugReport {
    let selected: CodeCandidate?
    let candidates: [CodeExtractionDebugCandidate]
    let brandDetection: PickupBrandDetection?
    let category: PickupCategory
    let pickupLocation: String?
}

enum CodeExtractor {
    nonisolated static func bestCode(from lines: [String]) -> CodeCandidate? {
        let recognizedLines = lines.map {
            RecognizedTextLine(text: $0, confidence: 1, boundingBox: .zero, imageSize: .zero)
        }
        return bestCode(from: recognizedLines)
    }

    nonisolated static func bestCode(from lines: [RecognizedTextLine]) -> CodeCandidate? {
        debugReport(from: lines).selected
    }

    nonisolated static func debugReport(from lines: [RecognizedTextLine]) -> CodeExtractionDebugReport {
        var debugCandidates: [CodeExtractionDebugCandidate] = []
        let normalizedLines = lines.map { normalize($0.text) }
        let visualLines = visualLines(for: lines).map(normalize)
        let documentText = normalizedLines.joined(separator: "|")
        let brandDetection = PickupBrandCatalog.detect(in: documentText)
        let category = brandDetection?.brand.category ?? PickupBrandCatalog.fallbackCategory(for: documentText)
        let pickupLocation = pickupLocation(from: lines, normalizedLines: normalizedLines, visualLines: visualLines, category: category)

        for (index, normalizedLine) in normalizedLines.enumerated() {
            let context = context(around: index, in: normalizedLines)
            let visualLine = visualLines[index]
            for regex in CodeExtractionRules.codeRegexes {
                for token in matches(regex: regex, in: normalizedLine) {
                    let fixedToken = normalizeExtractedCode(
                        normalizeLikelyOCRConfusions(in: token, context: context)
                    )
                    let spatialBoost = spatialKeywordBoost(
                        for: lines[index].boundingBox,
                        line: normalizedLine,
                        visualLine: visualLine,
                        allLines: lines,
                        normalizedLines: normalizedLines,
                        visualLines: visualLines
                    )
                    let score = score(
                        code: fixedToken,
                        line: normalizedLine,
                        visualLine: visualLine,
                        context: context,
                        confidence: lines[index].confidence,
                        boundingBox: lines[index].boundingBox,
                        spatialKeywordBoost: spatialBoost
                    )
                    let reason = reasonFor(token: fixedToken, line: normalizedLine, visualLine: visualLine, context: context)
                    let icon = brandDetection?.brand.iconName ?? iconForPickupContext(visualLine + "|" + context + "|" + documentText)
                    debugCandidates.append(
                        CodeExtractionDebugCandidate(
                            rawToken: token,
                            normalizedToken: fixedToken,
                            score: score,
                            reason: reason,
                            sourceText: lines[index].text,
                            normalizedLine: normalizedLine,
                            visualLine: visualLine,
                            context: context,
                            confidence: lines[index].confidence,
                            boundingBox: lines[index].boundingBox,
                            imageSize: lines[index].imageSize,
                            spatialKeywordBoost: spatialBoost,
                            icon: icon
                        )
                    )
                }
            }
        }

        let sortedCandidates = debugCandidates.sorted { lhs, rhs in
            isBetterCandidate(lhs, than: rhs)
        }
        let selected = sortedCandidates.first.flatMap {
            $0.score >= 0.5 ? CodeCandidate(
                code: $0.normalizedToken,
                score: $0.score,
                reason: pickupLocation ?? "",
                icon: $0.icon,
                brandIconName: brandDetection?.brand.logoAssetName,
                brandName: brandDetection?.brand.name,
                category: category
            ) : nil
        }
        return CodeExtractionDebugReport(
            selected: selected,
            candidates: sortedCandidates,
            brandDetection: brandDetection,
            category: category,
            pickupLocation: pickupLocation
        )
    }

    nonisolated private static func normalize(_ text: String) -> String {
        applyTextCorrections(to: text)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
            .replacingOccurrences(of: "-", with: "/")
            .replacingOccurrences(of: "—", with: "/")
            .replacingOccurrences(of: "_", with: "/")
            .replacingOccurrences(of: "：", with: ":")
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "碼", with: "码")
            .replacingOccurrences(of: "號", with: "号")
            .replacingOccurrences(of: "單", with: "单")
            .replacingOccurrences(of: "貨", with: "货")
            .replacingOccurrences(of: "憑", with: "凭")
            .replacingOccurrences(of: "碍", with: "码")
            .uppercased()
    }

    nonisolated private static func applyTextCorrections(to text: String) -> String {
        CodeExtractionRules.textCorrections.reduce(text) { result, correction in
            result.replacingOccurrences(of: correction.0, with: correction.1)
        }
    }

    nonisolated private static func matches(regex: String, in text: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: regex) else { return [] }
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.matches(in: text, options: [], range: fullRange).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
    }

    nonisolated private static func context(around index: Int, in lines: [String]) -> String {
        let lowerBound = max(0, index - 1)
        let upperBound = min(lines.count - 1, index + 1)
        return lines[lowerBound...upperBound].joined(separator: "|")
    }

    nonisolated private static func visualLines(for lines: [RecognizedTextLine]) -> [String] {
        guard lines.isEmpty == false else { return [] }
        var rows: [[Int]] = []

        for index in lines.indices.sorted(by: { lines[$0].boundingBox.midY > lines[$1].boundingBox.midY }) {
            let box = lines[index].boundingBox
            guard box != .zero else {
                rows.append([index])
                continue
            }

            if let rowIndex = rows.firstIndex(where: { row in
                let rowMidY = row.map { lines[$0].boundingBox.midY }.reduce(0, +) / CGFloat(row.count)
                let rowHeight = row.map { lines[$0].boundingBox.height }.reduce(0, +) / CGFloat(row.count)
                let threshold = max(0.018, min(0.04, max(box.height, rowHeight) * 0.9))
                return abs(box.midY - rowMidY) <= threshold
            }) {
                rows[rowIndex].append(index)
            } else {
                rows.append([index])
            }
        }

        var result = Array(repeating: "", count: lines.count)
        for row in rows {
            let joined = row
                .sorted { lines[$0].boundingBox.minX < lines[$1].boundingBox.minX }
                .map { lines[$0].text }
                .joined(separator: " ")
            for index in row {
                result[index] = joined
            }
        }
        return result
    }

    nonisolated private static func pickupLocation(
        from lines: [RecognizedTextLine],
        normalizedLines: [String],
        visualLines: [String],
        category: PickupCategory
    ) -> String? {
        guard lines.isEmpty == false else { return nil }
        var candidates: [(text: String, score: Double)] = []
        let documentText = normalizedLines.joined(separator: "|")
        candidates.append(contentsOf: documentPickupLocationCandidates(in: documentText, category: category))

        for index in lines.indices {
            let normalizedLine = normalizedLines[index]
            let visualLine = visualLines[index]
            let rawLine = lines[index].text

            if let inlineLocation = inlinePickupLocation(fromRaw: rawLine, normalized: normalizedLine) {
                candidates.append((inlineLocation, 1.0 + locationKeywordScore(normalizedLine, category: category)))
            }

            if let visualLocation = inlinePickupLocation(fromRaw: visualLine, normalized: visualLine) {
                candidates.append((visualLocation, 0.95 + locationKeywordScore(visualLine, category: category)))
            }

            if lineLooksLikeLocationLabel(normalizedLine) || lineLooksLikeLocationLabel(visualLine) {
                for neighborIndex in (index + 1)..<min(lines.count, index + 4) {
                    let neighbor = lines[neighborIndex].text
                    let normalizedNeighbor = normalizedLines[neighborIndex]
                    guard isPlausiblePickupLocation(normalizedNeighbor) else { continue }
                    candidates.append((cleanPickupLocation(neighbor), 0.72 + locationKeywordScore(normalizedNeighbor, category: category)))
                    break
                }
            }

            if isPlausiblePickupLocation(normalizedLine) {
                let score = 0.42 + locationKeywordScore(normalizedLine, category: category) + locationPositionScore(lines[index].boundingBox)
                candidates.append((cleanPickupLocation(rawLine), score))
            }
        }

        return candidates
            .map { (cleanPickupLocation($0.text), $0.score) }
            .filter { $0.0.isEmpty == false }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0.count > rhs.0.count
            }
            .first?
            .0
    }

    nonisolated private static func inlinePickupLocation(fromRaw rawText: String, normalized: String) -> String? {
        let raw = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        for label in CodeExtractionRules.locationLabels where normalized.contains(normalize(label)) {
            let variants = [label, "\(label):", "\(label)："]
            for variant in variants {
                if let range = raw.range(of: variant) {
                    let suffix = String(raw[range.upperBound...])
                    let cleaned = cleanPickupLocation(suffix)
                    if isPlausiblePickupLocation(normalize(cleaned)) {
                        return cleaned
                    }
                }
            }
        }

        return nil
    }

    nonisolated private static func documentPickupLocationCandidates(
        in documentText: String,
        category: PickupCategory
    ) -> [(text: String, score: Double)] {
        let starts = regexAlternation(CodeExtractionRules.locationStartKeywords.map(normalize))
        let targets = regexAlternation(CodeExtractionRules.locationTargetKeywords.map(normalize))
        let stops = regexAlternation(CodeExtractionRules.locationStopKeywords.map(normalize))

        var candidates: [(text: String, score: Double)] = []
        let addressRegexes = [
            #"地址[:：]?([^|,，。！!?？；;]{4,60})"#,
            #"(\p{Han}{1,8}(?:超市|便利店|商店|小卖部|驿站|服务站))"#
        ]

        for regex in addressRegexes {
            candidates.append(contentsOf: capturedMatches(regex: regex, in: documentText).map {
                ($0, 0.74 + locationKeywordScore($0, category: category))
            })
        }

        if starts.isEmpty == false && targets.isEmpty == false {
            let startToTargetRegex = #"(?:\#(starts))([^|,，。！!?？；;]{2,60}?(?:\#(targets)))"#
            candidates.append(contentsOf: capturedMatches(regex: startToTargetRegex, in: documentText).map {
                ($0, 0.82 + locationKeywordScore($0, category: category))
            })
        }

        if starts.isEmpty == false && stops.isEmpty == false {
            let startToStopRegex = #"(?:\#(starts))([^|,，。！!?？；;]{2,60}?)(?=(?:\#(stops))|[|,，。！!?？；;])"#
            candidates.append(contentsOf: capturedMatches(regex: startToStopRegex, in: documentText).map {
                ($0, 0.68 + locationKeywordScore($0, category: category))
            })
        }

        return candidates.filter { isPlausiblePickupLocation(normalize($0.text)) }
    }

    nonisolated private static func lineLooksLikeLocationLabel(_ line: String) -> Bool {
        CodeExtractionRules.locationNeighborLabels.contains { line.contains(normalize($0)) }
    }

    nonisolated private static func isPlausiblePickupLocation(_ line: String) -> Bool {
        guard line.count >= 3 && line.count <= 36 else { return false }
        if line.allSatisfy(\.isNumber) { return false }
        if matches(regex: #"\d{4}[年./]\d{1,2}[月./]\d{1,2}"#, in: line).isEmpty == false { return false }
        if matches(regex: #"\d{1,2}[:：]\d{2}"#, in: line).isEmpty == false { return false }

        if CodeExtractionRules.locationRejectKeywords.contains(where: { line.contains($0) }) { return false }
        return CodeExtractionRules.locationKeywords.contains { line.contains($0) }
    }

    nonisolated private static func cleanPickupLocation(_ text: String) -> String {
        var cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "取餐地点", with: "")
            .replacingOccurrences(of: "取件地点", with: "")
            .replacingOccurrences(of: "取货地点", with: "")
            .replacingOccurrences(of: "提货地点", with: "")
            .replacingOccurrences(of: "自提地点", with: "")
            .replacingOccurrences(of: "取餐地址", with: "")
            .replacingOccurrences(of: "取件地址", with: "")
            .replacingOccurrences(of: "取货地址", with: "")
            .replacingOccurrences(of: "提货地址", with: "")
            .replacingOccurrences(of: "自提地址", with: "")
            .replacingOccurrences(of: "门店地址", with: "")
            .replacingOccurrences(of: "店铺地址", with: "")
            .replacingOccurrences(of: "取件点", with: "")
            .replacingOccurrences(of: "自提点", with: "")
            .replacingOccurrences(of: "：", with: "")
            .replacingOccurrences(of: ":", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        for separator in CodeExtractionRules.locationSeparators {
            if let range = cleaned.range(of: separator) {
                cleaned = String(cleaned[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        for starter in CodeExtractionRules.locationStartKeywords {
            guard let range = cleaned.range(of: starter), range.upperBound < cleaned.endIndex else { continue }
            cleaned = String(cleaned[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            break
        }

        if cleaned.count > 12 {
            for marker in CodeExtractionRules.locationPrefixMarkers {
                guard let range = cleaned.range(of: marker), range.lowerBound > cleaned.startIndex else { continue }
                cleaned = String(cleaned[range.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        return cleaned.replacingOccurrences(of: "|", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func locationKeywordScore(_ line: String, category: PickupCategory) -> Double {
        var score = 0.0
        if line.contains("地址") || line.contains("地点") { score += 0.22 }
        if line.contains("门店") || line.contains("店") { score += 0.16 }
        if line.contains("取件点") || line.contains("自提点") { score += 0.22 }
        if line.contains("超市") || line.contains("便利店") || line.contains("商店") || line.contains("小卖部") {
            score += category == .express ? 0.28 : 0.12
        }
        if line.contains("驿站") || line.contains("服务站") || line.contains("丰巢") || line.contains("菜鸟") || line.contains("柜机") || line.contains("快递柜") {
            score += category == .express ? 0.3 : 0.16
        }
        return score
    }

    nonisolated private static func locationPositionScore(_ boundingBox: CGRect) -> Double {
        guard boundingBox != .zero else { return 0 }
        if boundingBox.midY >= 0.18 && boundingBox.midY <= 0.72 { return 0.08 }
        return 0
    }

    nonisolated private static func normalizeLikelyOCRConfusions(in token: String, context: String) -> String {
        guard contextHasStrongKeyword(context), token.contains(where: \.isLetter) else { return token }
        if matches(regex: #"^[A-Z]{1,3}\d{3,6}$"#, in: token).contains(token) {
            return token
        }
        let replacements: [Character: Character] = [
            "O": "0", "Q": "0", "D": "0",
            "I": "1", "L": "1",
            "S": "5",
            "Z": "2",
            "B": "8"
        ]
        let replaced = String(token.map { replacements[$0] ?? $0 })
        let digitCount = replaced.filter(\.isNumber).count
        if digitCount == replaced.count, replaced.count >= 3 {
            return replaced
        }
        return digitCount >= max(3, token.count - 1) ? replaced : token
    }

    nonisolated private static func normalizeExtractedCode(_ token: String) -> String {
        var cleaned = token
        if cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        }
        if looksLikeExpressPickupCode(cleaned) {
            return cleaned.replacingOccurrences(of: "/", with: "-")
        }
        return cleaned
    }

    nonisolated private static func score(
        code: String,
        line: String,
        visualLine: String,
        context: String,
        confidence: Float,
        boundingBox: CGRect,
        spatialKeywordBoost: Double
    ) -> Double {
        var score = 0.18
        let strongLine = lineHasStrongKeyword(line) || lineHasStrongKeyword(visualLine)
        let negativeVisualLine = hasNegativeStrongKeywordContext(in: visualLine)

        score += min(max(Double(confidence), 0), 1) * 0.18

        if code.count >= 4 && code.count <= 6 { score += 0.18 }
        if code.count == 3 && (strongLine || spatialKeywordBoost > 0) { score += 0.12 }
        if code.allSatisfy(\.isNumber) { score += 0.14 }
        if code.contains(where: \.isLetter) && code.contains(where: \.isNumber) { score += 0.12 }
        if looksLikeExpressPickupCode(code) {
            score += 0.36
        }
        if looksLikePhraseCode(code) { score += 0.28 }
        if looksLikeQueueCode(code, context: context) { score += 0.34 }
        if line.contains("#\(code)") { score += 0.28 }
        if strongLine { score += 0.42 }
        if !strongLine { score += spatialKeywordBoost }
        if contextHasWeakKeyword(context) { score += 0.12 }
        if keywordAppearsNear(code: code, in: line) { score += 0.28 }
        if contextHasStrongKeyword(context) && code.contains(where: \.isLetter) && code.contains(where: \.isNumber) {
            score += 0.12
        }
        if strongLine && code.count == 3 && code.allSatisfy(\.isNumber) { score += 0.2 }
        if boundingBox.height >= 0.045 { score += 0.06 }
        if looksLikeProminentShortLine(code: code, line: line, boundingBox: boundingBox) && !negativeVisualLine {
            score += 0.1
        }

        if CodeExtractionRules.negativeKeywords.contains(where: { line.contains($0) }) { score -= 0.18 }
        if CodeExtractionRules.negativeKeywords.contains(where: { visualLine.contains($0) }) { score -= 0.08 }
        if CodeExtractionRules.negativeKeywords.contains(where: { context.contains($0) }) { score -= 0.08 }
        if hasNegativeStrongKeywordContext(in: line) { score -= 0.45 }
        if negativeVisualLine { score -= 0.45 }
        if hasNegativeStrongKeywordContext(in: context) { score -= 0.16 }
        if code.allSatisfy(\.isNumber) && code.count >= 8 && !contextHasStrongKeyword(context) { score -= 0.28 }
        if code.allSatisfy(\.isNumber) && code.count == 3 && !strongLine && spatialKeywordBoost == 0 {
            score -= 0.2
        }
        if looksLikeCouponPhrase(code, line: line) { score -= 0.6 }
        if looksLikeProductSpec(code, line: line) { score -= 0.35 }
        if looksLikeFoodDistraction(code, line: line) { score -= 0.32 }
        if looksLikeStatusBarCode(code, line: line) { score -= 0.45 }
        if looksLikeDateOrTime(code, line: line) { score -= 0.3 }
        if looksLikeDateOrTimeFragment(code: code, line: line, visualLine: visualLine) { score -= 0.42 }
        if looksLikePhoneOrOrderNumber(code, line: line) { score -= 0.25 }
        if looksLikePhoneTail(code: code, line: line, context: context) { score -= 0.65 }
        if code.hasPrefix("20") && code.count >= 6 { score -= 0.2 }
        if line.contains("¥") || line.contains("￥") { score -= 0.2 }

        return min(max(score, 0), 1)
    }

    nonisolated private static func spatialKeywordBoost(
        for candidateBox: CGRect,
        line: String,
        visualLine: String,
        allLines: [RecognizedTextLine],
        normalizedLines: [String],
        visualLines: [String]
    ) -> Double {
        if lineHasStrongKeyword(line) { return 0.42 }
        if hasNegativeStrongKeywordContext(in: visualLine) { return 0 }
        if candidateBox.maxY >= 0.93 { return 0 }

        var bestBoost = 0.0
        let candidateMidX = candidateBox.midX
        let candidateMidY = candidateBox.midY

        for (index, keywordLine) in normalizedLines.enumerated() where lineHasStrongKeyword(keywordLine) && !hasNegativeStrongKeywordContext(in: keywordLine) && !hasNegativeStrongKeywordContext(in: visualLines[index]) {
            let keywordBox = allLines[index].boundingBox
            let sameRow = abs(candidateMidY - keywordBox.midY) <= 0.035
            let rightOfKeyword = candidateBox.minX >= keywordBox.minX - 0.02
            if sameRow && rightOfKeyword {
                bestBoost = max(bestBoost, 0.38)
            }

            let belowKeyword = candidateMidY < keywordBox.midY
            let closeBelow = keywordBox.midY - candidateMidY <= 0.16
            let horizontallyNear = abs(candidateMidX - keywordBox.midX) <= 0.35
            if belowKeyword && closeBelow && horizontallyNear {
                bestBoost = max(bestBoost, 0.28)
            }

            let aboveKeyword = candidateMidY > keywordBox.midY
            let closeAbove = candidateMidY - keywordBox.midY <= 0.14
            if aboveKeyword && closeAbove && horizontallyNear {
                bestBoost = max(bestBoost, 0.38)
            }
        }

        return bestBoost
    }

    nonisolated private static func isBetterCandidate(
        _ lhs: CodeExtractionDebugCandidate,
        than rhs: CodeExtractionDebugCandidate
    ) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score > rhs.score
        }

        let lhsStrongLine = lineHasStrongKeyword(lhs.normalizedLine)
        let rhsStrongLine = lineHasStrongKeyword(rhs.normalizedLine)
        if lhsStrongLine != rhsStrongLine {
            return lhsStrongLine
        }

        if lhs.spatialKeywordBoost != rhs.spatialKeywordBoost {
            return lhs.spatialKeywordBoost > rhs.spatialKeywordBoost
        }

        let lhsPhraseCode = looksLikePhraseCode(lhs.normalizedToken)
        let rhsPhraseCode = looksLikePhraseCode(rhs.normalizedToken)
        if lhsPhraseCode != rhsPhraseCode {
            return lhsPhraseCode
        }

        let lhsExpressCode = looksLikeExpressPickupCode(lhs.normalizedToken)
        let rhsExpressCode = looksLikeExpressPickupCode(rhs.normalizedToken)
        if lhsExpressCode != rhsExpressCode {
            return lhsExpressCode
        }

        if lhs.confidence != rhs.confidence {
            return lhs.confidence > rhs.confidence
        }

        let lhsHasLetter = lhs.normalizedToken.contains(where: \.isLetter)
        let rhsHasLetter = rhs.normalizedToken.contains(where: \.isLetter)
        if lhsHasLetter != rhsHasLetter {
            return !lhsHasLetter
        }

        return lhs.normalizedToken < rhs.normalizedToken
    }

    nonisolated private static func reasonFor(token: String, line: String, visualLine: String, context: String) -> String {
        if hasNegativeStrongKeywordContext(in: line) || hasNegativeStrongKeywordContext(in: visualLine) {
            return "负向上下文"
        }
        if keywordAppearsNear(code: token, in: line) {
            return "关键词旁码"
        }
        if looksLikeQueueCode(token, context: context) {
            return "排队取号"
        }
        if looksLikeExpressPickupCode(token) {
            return "快递取件码"
        }
        if contextHasStrongKeyword(context) {
            return "邻近行命中关键词"
        }
        if token.allSatisfy(\.isNumber) {
            return "数字码型"
        }
        return "字母数字混合"
    }

    nonisolated private static func contextHasStrongKeyword(_ context: String) -> Bool {
        hasStrongKeyword(in: context)
    }

    nonisolated private static func lineHasStrongKeyword(_ line: String) -> Bool {
        hasStrongKeyword(in: line)
    }

    nonisolated private static func contextHasWeakKeyword(_ context: String) -> Bool {
        CodeExtractionRules.weakKeywords.contains { context.contains($0) }
    }

    nonisolated private static func iconForPickupContext(_ text: String) -> String {
        if CodeExtractionRules.packageKeywords.contains(where: { text.contains($0) }) {
            return "shippingbox.fill"
        }
        if CodeExtractionRules.drinkKeywords.contains(where: { text.contains($0) }) {
            return "cup.and.saucer.fill"
        }
        if CodeExtractionRules.foodKeywords.contains(where: { text.contains($0) }) {
            return "fork.knife"
        }
        return "fork.knife"
    }

    nonisolated private static func keywordAppearsNear(code: String, in line: String) -> Bool {
        guard let codeRange = line.range(of: code) else { return false }
        let prefix = String(line[..<codeRange.lowerBound].suffix(12))
        return hasStrongKeyword(in: prefix)
    }

    nonisolated private static func hasStrongKeyword(in text: String) -> Bool {
        if hasNegativeStrongKeywordContext(in: text) {
            return false
        }
        if CodeExtractionRules.strongKeywords.contains(where: { text.contains($0) }) {
            return true
        }
        return CodeExtractionRules.strongKeywordRegexes.contains { regex in
            matches(regex: regex, in: text).isEmpty == false
        }
    }

    nonisolated private static func hasNegativeStrongKeywordContext(in text: String) -> Bool {
        if CodeExtractionRules.negativeStrongKeywordContexts.contains(where: { text.contains($0) }) {
            return true
        }
        return CodeExtractionRules.negativeStrongKeywordRegexes.contains { regex in
            matches(regex: regex, in: text).isEmpty == false
        }
    }

    nonisolated private static func looksLikeDateOrTime(_ code: String, line: String) -> Bool {
        if matches(regex: #"\d{1,2}[:：]\d{2}"#, in: line).contains(code) { return true }
        if matches(regex: #"\d{4}[年./-]\d{1,2}[月./-]\d{1,2}"#, in: line).contains(code) { return true }
        return false
    }

    nonisolated private static func looksLikeDateOrTimeFragment(code: String, line: String, visualLine: String) -> Bool {
        guard code.allSatisfy(\.isNumber) else { return false }
        let text = visualLine.isEmpty ? line : visualLine
        let hasDate = matches(regex: #"\d{4}[年./-]\d{1,2}[月./-]\d{1,2}"#, in: text).isEmpty == false
        let hasTime = matches(regex: #"\d{1,2}[:：]\d{2}"#, in: text).isEmpty == false
        return hasDate || hasTime
    }

    nonisolated private static func looksLikeProminentShortLine(code: String, line: String, boundingBox: CGRect) -> Bool {
        guard boundingBox != .zero else { return false }
        guard line.count <= 18 && code.count <= 20 else { return false }
        guard looksLikeDateOrTimeFragment(code: code, line: line, visualLine: line) == false else { return false }
        let inUpperMiddleScreen = boundingBox.midY >= 0.45 && boundingBox.midY <= 0.86
        return inUpperMiddleScreen && boundingBox.height >= 0.028
    }

    nonisolated private static func looksLikePhraseCode(_ code: String) -> Bool {
        matches(regex: #"^\d{1,2}[.。．、]\p{Han}[\p{Han}A-Z0-9]{1,19}$"#, in: code).contains(code)
            || matches(regex: #"^[A-Z][A-Z0-9]{2,9}[.。．]\p{Han}[\p{Han}A-Z0-9]{1,23}$"#, in: code).contains(code)
    }

    nonisolated private static func looksLikeExpressPickupCode(_ code: String) -> Bool {
        matches(regex: #"^\d{1,3}[/-]\d{1,3}[/-]\d{3,6}$"#, in: code).isEmpty == false
            || matches(regex: #"^[A-Z0-9]{1,4}[/-][A-Z0-9]{1,4}[/-][A-Z0-9]{2,8}$"#, in: code).isEmpty == false
            || matches(regex: #"^[A-Z]{1,4}\d{0,3}[/-]\d{3,8}$"#, in: code).isEmpty == false
    }

    nonisolated private static func looksLikeQueueCode(_ code: String, context: String) -> Bool {
        let queueKeywordCount = CodeExtractionRules.queueKeywords.reduce(0) { count, keyword in
            context.contains(keyword) ? count + 1 : count
        }
        guard queueKeywordCount >= 2 else { return false }
        return matches(regex: #"^[A-Z]{1,2}\d{1,3}$"#, in: code).contains(code)
            || matches(regex: #"^\d{3,4}$"#, in: code).contains(code)
    }

    nonisolated private static func looksLikeCouponPhrase(_ code: String, line: String) -> Bool {
        code.contains("元券") || line.contains("元券") || line.contains("评价抽")
    }

    nonisolated private static func looksLikeProductSpec(_ code: String, line: String) -> Bool {
        let upperLine = line.uppercased()
        let upperCode = code.uppercased()
        if upperLine.contains("OZ") || upperLine.contains("ML") || upperLine.contains("毫升") {
            return upperCode.contains("OZ") || upperCode.contains("ML") || upperCode.rangeOfCharacter(from: .letters) != nil
        }
        return false
    }

    nonisolated private static func looksLikeFoodDistraction(_ code: String, line: String) -> Bool {
        guard CodeExtractionRules.foodDistractionKeywords.contains(where: { line.contains($0) }) else { return false }
        if code.allSatisfy(\.isNumber) && code.count <= 3 { return true }
        return looksLikeProductSpec(code, line: line)
    }

    nonisolated private static func looksLikeStatusBarCode(_ code: String, line: String) -> Bool {
        guard line.contains("5G") || line.contains("4G") || line.contains("WIFI") else { return false }
        if code.contains("G") { return true }
        if matches(regex: #"\d{1,2}:\d{2}"#, in: line).isEmpty == false && code.count <= 6 {
            return true
        }
        return false
    }

    nonisolated private static func looksLikePhoneOrOrderNumber(_ code: String, line: String) -> Bool {
        if code.count >= 8 && (line.contains("尾号") || line.contains("手机号") || line.contains("电话")) {
            return true
        }
        if code.count >= 7 && (line.contains("订单") || line.contains("单号") || line.contains("编号")) {
            return true
        }
        return false
    }

    nonisolated private static func looksLikePhoneTail(code: String, line: String, context: String) -> Bool {
        guard code.allSatisfy(\.isNumber), code.count == 4 else { return false }
        let text = line + "|" + context
        if CodeExtractionRules.phoneTailKeywords.contains(where: { text.contains($0) }) {
            return true
        }
        return line.contains("**\(code)") || line.contains("****\(code)")
    }

    nonisolated private static func capturedMatches(regex: String, in text: String, group: Int = 1) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: regex) else { return [] }
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.matches(in: text, options: [], range: fullRange).compactMap { match in
            guard match.numberOfRanges > group, let range = Range(match.range(at: group), in: text) else { return nil }
            return String(text[range])
        }
    }

    nonisolated private static func regexAlternation(_ terms: [String]) -> String {
        terms
            .filter { $0.isEmpty == false }
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")
    }
}

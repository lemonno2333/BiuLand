import Foundation
import CoreGraphics

struct CodeCandidate: Hashable {
    let code: String
    let score: Double
    let reason: String
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
}

struct CodeExtractionDebugReport {
    let selected: CodeCandidate?
    let candidates: [CodeExtractionDebugCandidate]
}

enum CodeExtractor {
    nonisolated private static let strongKeywords = [
        "取餐码", "取件码", "自提码", "提货码", "取货码", "提取码", "取码",
        "取单号", "取餐号", "餐号", "取餐凭证", "凭取单号",
        "取茶号", "茶号", "取饮品号", "饮品号",
        "取单口令", "暗口令", "口令", "取餐口令",
        "开柜码", "柜机码", "凭取件码", "取货凭证", "取件凭证", "PICKUPCODE"
    ]

    nonisolated private static let weakKeywords = [
        "验证码", "校验码", "码", "PICKUP", "CODE"
    ]

    nonisolated private static let strongKeywordRegexes = [
        #"取[餐茶件货貨单單饮飲品]?[餐茶件货貨单單饮飲品]?[号码碼碍]"#,
        #"[餐茶件货貨单單饮飲品]?[餐茶件货貨单單饮飲品][号码碼碍]"#,
        #"凭取[餐茶件货貨单單饮飲品]?[号码碼碍]"#,
        #"取[餐茶件货貨单單饮飲品]?凭证"#,
        #"PICKUPCODE"#
    ]

    nonisolated private static let negativeKeywords = [
        "订单", "订单号", "单号", "尾号", "手机号", "电话", "金额", "合计", "支付",
        "实付", "预计", "送达", "时间", "日期", "地址", "距离", "编号", "流水号",
        "评价", "优惠", "元券", "满意", "不满意", "商品"
    ]

    nonisolated private static let negativeStrongKeywordContexts = [
        "取单时间", "预计取单时间", "取餐时间", "预计取餐时间", "下单时间", "付款时间",
        "取单地点", "取餐地点", "取件地点", "取餐方式", "取件方式", "取单方式",
        "到店取餐", "到店取件", "门店地址", "联系地址"
    ]

    nonisolated private static let negativeStrongKeywordRegexes = [
        #"取[餐茶件货单饮品]?[餐茶件货单饮品]?.{0,3}(时间|日期|地点|地址|方式)"#,
        #"(下单|付款|支付|预计|送达).{0,4}(时间|日期)"#,
        #"(门店|联系|收货|配送).{0,4}(地址|地点|方式)"#,
        #"到店取[餐件货]"#
    ]

    nonisolated private static let codeRegexes = [
        #"(?<![A-Z0-9])\d{1,2}[.。．、]\p{Han}[\p{Han}A-Z0-9]{1,19}(?![A-Z0-9])"#,
        #"(?<![A-Z0-9])[A-Z]{1,3}\d{3,6}(?![A-Z0-9])"#,
        #"(?<![A-Z0-9])\d{3,8}(?![A-Z0-9])"#,
        #"(?<![A-Z0-9])\d{1,2}[A-Z]\d{0,2}(?![A-Z0-9])"#,
        #"(?<![A-Z0-9])[A-Z]\d{2}(?![A-Z0-9])"#,
        #"(?<![A-Z0-9])[A-Z0-9]{4,10}(?![A-Z0-9])"#
    ]

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

        for (index, normalizedLine) in normalizedLines.enumerated() {
            let context = context(around: index, in: normalizedLines)
            let visualLine = visualLines[index]
            for regex in codeRegexes {
                for token in matches(regex: regex, in: normalizedLine) {
                    let fixedToken = normalizeLikelyOCRConfusions(in: token, context: context)
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
                            spatialKeywordBoost: spatialBoost
                        )
                    )
                }
            }
        }

        let sortedCandidates = debugCandidates.sorted { lhs, rhs in
            isBetterCandidate(lhs, than: rhs)
        }
        let selected = sortedCandidates.first.flatMap {
            $0.score >= 0.5 ? CodeCandidate(code: $0.normalizedToken, score: $0.score, reason: $0.reason) : nil
        }
        return CodeExtractionDebugReport(selected: selected, candidates: sortedCandidates)
    }

    nonisolated private static func normalize(_ text: String) -> String {
        text
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
        if looksLikePhraseCode(code) { score += 0.28 }
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

        if negativeKeywords.contains(where: { line.contains($0) }) { score -= 0.18 }
        if negativeKeywords.contains(where: { visualLine.contains($0) }) { score -= 0.08 }
        if negativeKeywords.contains(where: { context.contains($0) }) { score -= 0.08 }
        if hasNegativeStrongKeywordContext(in: line) { score -= 0.45 }
        if negativeVisualLine { score -= 0.45 }
        if hasNegativeStrongKeywordContext(in: context) { score -= 0.16 }
        if code.allSatisfy(\.isNumber) && code.count >= 8 && !contextHasStrongKeyword(context) { score -= 0.28 }
        if code.allSatisfy(\.isNumber) && code.count == 3 && !strongLine && spatialKeywordBoost == 0 {
            score -= 0.2
        }
        if looksLikeCouponPhrase(code, line: line) { score -= 0.6 }
        if looksLikeProductSpec(code, line: line) { score -= 0.35 }
        if looksLikeStatusBarCode(code, line: line) { score -= 0.45 }
        if looksLikeDateOrTime(code, line: line) { score -= 0.3 }
        if looksLikeDateOrTimeFragment(code: code, line: line, visualLine: visualLine) { score -= 0.42 }
        if looksLikePhoneOrOrderNumber(code, line: line) { score -= 0.25 }
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
        weakKeywords.contains { context.contains($0) }
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
        if strongKeywords.contains(where: { text.contains($0) }) {
            return true
        }
        return strongKeywordRegexes.contains { regex in
            matches(regex: regex, in: text).isEmpty == false
        }
    }

    nonisolated private static func hasNegativeStrongKeywordContext(in text: String) -> Bool {
        if negativeStrongKeywordContexts.contains(where: { text.contains($0) }) {
            return true
        }
        return negativeStrongKeywordRegexes.contains { regex in
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
}

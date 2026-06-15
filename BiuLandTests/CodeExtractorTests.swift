import XCTest
@testable import BiuLand

final class CodeExtractorTests: XCTestCase {
    func testExtractsDrinkPickupCodeAndBrand() {
        let candidate = CodeExtractor.bestCode(from: [
            "瑞幸咖啡",
            "取餐码 238",
            "下单时间 2026-06-14 12:30"
        ])

        XCTAssertEqual(candidate?.code, "238")
        XCTAssertEqual(candidate?.brandName, "瑞幸")
        XCTAssertEqual(candidate?.category, .drink)
    }

    func testExtractsExpressPickupCode() {
        let candidate = CodeExtractor.bestCode(from: [
            "菜鸟驿站",
            "取件码 3-12-4567",
            "包裹已到站"
        ])

        XCTAssertEqual(candidate?.code, "3-12-4567")
        XCTAssertEqual(candidate?.category, .express)
    }

    func testIgnoresOrderNumbersWithoutPickupContext() {
        let candidate = CodeExtractor.bestCode(from: [
            "订单号 20260614123456",
            "付款时间 12:30",
            "实付 19.90"
        ])

        XCTAssertNil(candidate)
    }

    func testNormalizesTraditionalPickupText() {
        let candidate = CodeExtractor.bestCode(from: [
            "取餐碼",
            "A123"
        ])

        XCTAssertEqual(candidate?.code, "A123")
    }

    func testExtractsPhrasePickupCode() {
        let candidate = CodeExtractor.bestCode(from: [
            "星巴克",
            "啡快口令 6.拿铁"
        ])

        XCTAssertEqual(candidate?.code, "6.拿铁")
        XCTAssertEqual(candidate?.brandName, "星巴克")
        XCTAssertEqual(candidate?.category, .drink)
    }

    func testCorrectsCommonExpressOCRText() {
        let candidate = CodeExtractor.bestCode(from: [
            "菜鸟驿站",
            "取性码 A-2-7261",
            "包 裹已到站"
        ])

        XCTAssertEqual(candidate?.code, "A-2-7261")
        XCTAssertEqual(candidate?.category, .express)
    }

    func testRejectsPhoneTailAsPickupCode() {
        let candidate = CodeExtractor.bestCode(from: [
            "包裹已到站",
            "收件人手机号尾号 7261",
            "请及时领取"
        ])

        XCTAssertNil(candidate)
    }

    func testExtractsPickupLocationFromArrivalSentence() {
        let candidate = CodeExtractor.bestCode(from: [
            "菜鸟驿站",
            "请凭取件码 A-2-7261",
            "包裹已到东方悦天地便利店领取"
        ])

        XCTAssertEqual(candidate?.code, "A-2-7261")
        XCTAssertEqual(candidate?.reason, "东方悦天地便利店")
    }

    func testExtractsAlphaPhrasePickupCode() {
        let candidate = CodeExtractor.bestCode(from: [
            "星巴克",
            "啡快口令 M707.你的脚步有力量"
        ])

        XCTAssertEqual(candidate?.code, "M707.你的脚步有力量")
        XCTAssertEqual(candidate?.brandName, "星巴克")
    }

    func testExtractsQueueCodeWhenQueueSceneIsClear() {
        let candidate = CodeExtractor.bestCode(from: [
            "迎宾台取号",
            "还需等待桌安排",
            "小桌 A3"
        ])

        XCTAssertEqual(candidate?.code, "A3")
    }
}

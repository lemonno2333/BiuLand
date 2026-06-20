import XCTest
@testable import BiuLand

final class CodeExtractorTests: XCTestCase {
    func testDetectsMainstreamDrinkBrands() {
        assertBrand("柠季 手打柠檬茶 取茶号 A23", name: "柠季", category: .drink)
        assertBrand("益禾堂 烤奶 取茶码 58", name: "益禾堂", category: .drink)
        assertBrand("茉莉奶白 茶饮 制作中 取茶 102", name: "茉莉奶白", category: .drink)
        assertBrand("M Stand 咖啡 取餐码 19", name: "M Stand", category: .drink)
        assertBrand("Peet's Coffee 拿铁 取餐码 7", name: "Peet's", category: .drink)
        assertBrand("挪瓦咖啡 NOWWA 取餐 28", name: "挪瓦咖啡", category: .drink)
    }

    func testDetectsMainstreamFoodBrands() {
        assertBrand("德克士 炸鸡 取餐号 58", name: "德克士", category: .food)
        assertBrand("必胜客 披萨 取餐号 120", name: "必胜客", category: .food)
        assertBrand("达美乐比萨 取餐号 A15", name: "达美乐", category: .food)
        assertBrand("真功夫 快餐 取餐号 86", name: "真功夫", category: .food)
        assertBrand("吉野家 牛肉饭 取餐号 31", name: "吉野家", category: .food)
        assertBrand("食其家 SUKIYA 取餐号 44", name: "食其家", category: .food)
    }

    func testDetectsMainstreamExpressBrands() {
        assertBrand("京东快递 包裹已到 取件码 6-1234", name: "京东物流", category: .express)
        assertBrand("跨越速运 快递 取件码 A-18-9921", name: "跨越速运", category: .express)
        assertBrand("丹鸟快递 包裹已到站 取件码 3021", name: "丹鸟", category: .express)
        assertBrand("兔喜快递超市 包裹 取件码 8-210", name: "兔喜", category: .express)
        assertBrand("速递易柜 开柜码 7110", name: "速递易", category: .express)
        assertBrand("FedEx 联邦快递 包裹 取件码 FX1024", name: "FedEx", category: .express)
    }

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

    private func assertBrand(
        _ text: String,
        name: String,
        category: PickupCategory,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let detection = PickupBrandCatalog.detect(in: text)
        XCTAssertEqual(detection?.brand.name, name, file: file, line: line)
        XCTAssertEqual(detection?.brand.category, category, file: file, line: line)
    }
}

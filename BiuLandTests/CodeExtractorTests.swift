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

    func testDetectsLuckinFromPickupCodeAndScanPrompt() {
        let candidate = CodeExtractor.bestCode(from: [
            "520",
            "取餐码",
            "张女士，请扫码取餐",
            "订单号 20260614123456"
        ])

        XCTAssertEqual(candidate?.code, "520")
        XCTAssertEqual(candidate?.brandName, "瑞幸")
        XCTAssertEqual(candidate?.category, .drink)
    }

    func testDetectsLuckinWhenPickupCodeAndScanPromptAreSeparateLines() {
        let candidate = CodeExtractor.bestCode(from: [
            "取餐码",
            "521",
            "张女士，请扫码取餐",
            "预计 13:48 可制作完成"
        ])

        XCTAssertEqual(candidate?.code, "521")
        XCTAssertEqual(candidate?.brandName, "瑞幸")
        XCTAssertEqual(candidate?.category, .drink)
    }

    func testDoesNotDetectLuckinWithoutScanPrompt() {
        let detection = PickupBrandCatalog.detect(in: "520 取餐码")

        XCTAssertNil(detection)
    }

    func testDoesNotDetectLuckinWithoutSupportFeature() {
        let detection = PickupBrandCatalog.detect(in: "520 取餐码 张女士，请扫码取餐")

        XCTAssertNil(detection)
    }

    func testLuckinTextFallbackDoesNotOverrideExplicitBrand() {
        assertBrand("M Stand 咖啡 520 取餐码 请扫码取餐", name: "M Stand", category: .drink)
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

        XCTAssertEqual(candidate?.code, "小桌A3")
    }

    func testExtractsMeituanQueueTableCodeWithTableType() {
        let candidate = CodeExtractor.bestCode(from: [
            "排队详情",
            "当前时间 18:42:04",
            "中桌 B141",
            "还需等待 5 桌，预计 10 分钟",
            "取号成功",
            "待叫号",
            "已就餐",
            "盛香亭转转热卤(西丽宝能店)",
            "取号时间：17:20（已等待 81 分钟）",
            "手机号码：181****6782（线上取号）",
            "商家说明",
            "1、认准官方渠道取号",
            "通过非官方渠道获取的取号，存在无效、被转卖等风险，导致无法正常就餐，请认准官方渠道！！",
            "2、按需取号，关注进度"
        ])

        XCTAssertEqual(candidate?.code, "中桌B141")
        XCTAssertEqual(candidate?.icon, "person.2.fill")
    }

    func testRejectsMaskedPhonePrefixOnQueuePage() {
        let candidate = CodeExtractor.bestCode(from: [
            RecognizedTextLine(
                text: "排队详情",
                confidence: 1,
                boundingBox: CGRect(x: 0.38, y: 0.86, width: 0.24, height: 0.03),
                imageSize: CGSize(width: 1080, height: 2400)
            ),
            RecognizedTextLine(
                text: "中桌 B141",
                confidence: 1,
                boundingBox: CGRect(x: 0.363, y: 0.687, width: 0.273, height: 0.045),
                imageSize: CGSize(width: 1080, height: 2400)
            ),
            RecognizedTextLine(
                text: "还需等待 5 桌，预计 10 分钟",
                confidence: 1,
                boundingBox: CGRect(x: 0.31, y: 0.63, width: 0.38, height: 0.03),
                imageSize: CGSize(width: 1080, height: 2400)
            ),
            RecognizedTextLine(
                text: "盛香亭转转热卤(西丽宝能店) >",
                confidence: 1,
                boundingBox: CGRect(x: 0.05, y: 0.42, width: 0.5, height: 0.03),
                imageSize: CGSize(width: 1080, height: 2400)
            ),
            RecognizedTextLine(
                text: "手机号码：181****6782（线上取号）",
                confidence: 1,
                boundingBox: CGRect(x: 0.051, y: 0.368, width: 0.478, height: 0.022),
                imageSize: CGSize(width: 1080, height: 2400)
            )
        ])

        XCTAssertEqual(candidate?.code, "中桌B141")
    }

    func testRejectsMerchantInstructionListAsPhraseCode() {
        let candidate = CodeExtractor.bestCode(from: [
            "商家说明",
            "1、认准官方渠道取号",
            "通过非官方渠道获取的取号，存在无效、被转卖等风险，导致无法正常就餐，请认准官方渠道！！",
            "2、按需取号，关注进度"
        ])

        XCTAssertNil(candidate)
    }

    func testExtractsMeituanQueueSeatCodeWithSeatType() {
        let candidate = CodeExtractor.bestCode(from: [
            "排队详情",
            "双人位 B247",
            "还需等待 51 桌",
            "取号时间：18:00（已等待 2 分钟）",
            "手机号码：****（线上取号）",
            "如无法到店就餐，请及时取消"
        ])

        XCTAssertEqual(candidate?.code, "双人位B247")
        XCTAssertEqual(candidate?.reason, "排队取号")
        XCTAssertEqual(candidate?.icon, "person.2.fill")
    }

    func testPrefersFullQueueSeatCodeOverSubTokenWithLowOCRConfidence() {
        let candidate = CodeExtractor.bestCode(from: [
            RecognizedTextLine(
                text: "排队详情",
                confidence: 1,
                boundingBox: CGRect(x: 0.38, y: 0.86, width: 0.24, height: 0.03),
                imageSize: CGSize(width: 1080, height: 2400)
            ),
            RecognizedTextLine(
                text: "双人位 B247",
                confidence: 0.5,
                boundingBox: CGRect(x: 0.335, y: 0.846, width: 0.332, height: 0.026),
                imageSize: CGSize(width: 1080, height: 2400)
            ),
            RecognizedTextLine(
                text: "还需等待 51 桌",
                confidence: 0.9,
                boundingBox: CGRect(x: 0.35, y: 0.80, width: 0.3, height: 0.03),
                imageSize: CGSize(width: 1080, height: 2400)
            )
        ])

        XCTAssertEqual(candidate?.code, "双人位B247")
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

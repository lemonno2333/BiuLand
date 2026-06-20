import Foundation

enum PickupCategory: String, Codable, Hashable {
    case drink = "饮品"
    case food = "餐食"
    case express = "快递"

    var fallbackIconName: String {
        switch self {
        case .drink:
            return "cup.and.saucer.fill"
        case .food:
            return "fork.knife"
        case .express:
            return "shippingbox.fill"
        }
    }
}

struct PickupBrand: Hashable {
    let name: String
    let aliases: [String]
    let category: PickupCategory
    let keywords: [String]
    let iconName: String
    let logoAssetName: String?

    init(
        name: String,
        aliases: [String],
        category: PickupCategory,
        keywords: [String],
        iconName: String,
        logoAssetName: String? = nil
    ) {
        self.name = name
        self.aliases = aliases
        self.category = category
        self.keywords = keywords
        self.iconName = iconName
        self.logoAssetName = logoAssetName
    }
}

struct PickupBrandDetection: Hashable {
    let brand: PickupBrand
    let score: Double
    let matchedTerms: [String]
}

enum PickupBrandCatalog {
    nonisolated private static let heyteaFallbackRequiredTerms = ["订单详情"]
    nonisolated private static let heyteaFallbackFeatureTerms = [
        "阿喜熟客",
        "金喜卡",
        "灵感好礼",
        "贵宾权益",
        "制茶中",
        "前方",
        "喜贴定制",
        "前方还有",
        "正在全力制作中",
        "商品明细",
        "问题反馈"
    ]

    nonisolated static let brands: [PickupBrand] = [
        PickupBrand(name: "星巴克", aliases: ["STARBUCKS"], category: .drink, keywords: ["啡快", "啡快口令", "星礼卡"], iconName: "cup.and.saucer.fill", logoAssetName: "brand_starbucks"),
        PickupBrand(name: "瑞幸", aliases: ["LUCKIN", "瑞幸咖啡"], category: .drink, keywords: ["取餐码", "咖啡", "拿铁", "小蓝杯"], iconName: "cup.and.saucer.fill", logoAssetName: "brand_luckin"),
        PickupBrand(name: "库迪", aliases: ["COTTI", "库迪咖啡"], category: .drink, keywords: ["咖啡", "取餐码", "拿铁"], iconName: "cup.and.saucer.fill", logoAssetName: "brand_cotti"),
        PickupBrand(name: "幸运咖", aliases: ["LUCKY CUP"], category: .drink, keywords: ["咖啡", "饮品", "取餐"], iconName: "cup.and.saucer.fill"),
        PickupBrand(name: "蜜雪冰城", aliases: ["蜜雪", "MIXUE"], category: .drink, keywords: ["冰淇淋", "柠檬水", "取茶", "雪王"], iconName: "cup.and.saucer.fill", logoAssetName: "brand_mixue"),
        PickupBrand(name: "古茗", aliases: ["GOODME"], category: .drink, keywords: ["奶茶", "取茶", "饮品", "葫芦"], iconName: "cup.and.saucer.fill", logoAssetName: "brand_goodme"),
        PickupBrand(name: "茶百道", aliases: ["CHA BAI DAO", "CHABAIDAO"], category: .drink, keywords: ["奶茶", "取茶", "饮品", "熊猫币", "熊猫值"], iconName: "cup.and.saucer.fill", logoAssetName: "brand_chabaidao"),
        PickupBrand(name: "霸王茶姬", aliases: ["CHAGEE"], category: .drink, keywords: ["伯牙绝弦", "取茶", "奶茶"], iconName: "cup.and.saucer.fill", logoAssetName: "brand_chagee"),
        PickupBrand(name: "喜茶", aliases: ["HEYTEA", "喜茶GO"], category: .drink, keywords: ["取茶", "多肉葡萄", "饮品"], iconName: "cup.and.saucer.fill", logoAssetName: "brand_heytea"),
        PickupBrand(name: "奈雪", aliases: ["奈雪的茶", "NAIXUE"], category: .drink, keywords: ["取茶", "奶茶", "饮品"], iconName: "cup.and.saucer.fill", logoAssetName: "brand_naixue"),
        PickupBrand(name: "沪上阿姨", aliases: ["沪上"], category: .drink, keywords: ["奶茶", "取茶", "饮品"], iconName: "cup.and.saucer.fill", logoAssetName: "brand_hushangayi"),
        PickupBrand(name: "柠季", aliases: ["LINLEE"], category: .drink, keywords: ["柠檬茶", "鸭屎香", "手打柠檬茶", "取茶"], iconName: "cup.and.saucer.fill", logoAssetName: "brand_linlee"),
        PickupBrand(name: "益禾堂", aliases: ["益禾"], category: .drink, keywords: ["奶茶", "烤奶", "取茶"], iconName: "cup.and.saucer.fill"),
        PickupBrand(name: "茉莉奶白", aliases: ["茉莉"], category: .drink, keywords: ["茉莉", "奶白", "茶饮", "取茶"], iconName: "cup.and.saucer.fill"),
        PickupBrand(name: "茶话弄", aliases: [], category: .drink, keywords: ["奶茶", "茶饮", "取茶"], iconName: "cup.and.saucer.fill"),
        PickupBrand(name: "爷爷不泡茶", aliases: [], category: .drink, keywords: ["茶饮", "取茶", "荔枝冰酿"], iconName: "cup.and.saucer.fill"),
        PickupBrand(name: "阿嬷手作", aliases: ["阿嬷"], category: .drink, keywords: ["手作", "奶茶", "取茶"], iconName: "cup.and.saucer.fill"),
        PickupBrand(name: "伏小桃", aliases: [], category: .drink, keywords: ["桃子", "奶茶", "取茶"], iconName: "cup.and.saucer.fill"),
        PickupBrand(name: "CoCo", aliases: ["COCO", "都可"], category: .drink, keywords: ["奶茶", "取茶", "饮品"], iconName: "cup.and.saucer.fill", logoAssetName: "brand_coco"),
        PickupBrand(name: "一点点", aliases: ["1点点"], category: .drink, keywords: ["奶茶", "取茶", "饮品"], iconName: "cup.and.saucer.fill"),
        PickupBrand(name: "书亦烧仙草", aliases: ["书亦"], category: .drink, keywords: ["烧仙草", "奶茶", "取茶"], iconName: "cup.and.saucer.fill"),
        PickupBrand(name: "甜啦啦", aliases: [], category: .drink, keywords: ["奶茶", "柠檬茶", "取茶"], iconName: "cup.and.saucer.fill"),
        PickupBrand(name: "700CC", aliases: ["700"], category: .drink, keywords: ["奶茶", "饮品", "取茶"], iconName: "cup.and.saucer.fill"),
        PickupBrand(name: "鲜果时间", aliases: [], category: .drink, keywords: ["鲜果", "饮品", "取茶"], iconName: "cup.and.saucer.fill"),
        PickupBrand(name: "快乐柠檬", aliases: [], category: .drink, keywords: ["柠檬", "奶茶", "取茶"], iconName: "cup.and.saucer.fill"),
        PickupBrand(name: "7分甜", aliases: ["七分甜"], category: .drink, keywords: ["杨枝甘露", "奶茶", "取茶"], iconName: "cup.and.saucer.fill"),
        PickupBrand(name: "一只酸奶牛", aliases: ["酸奶牛"], category: .drink, keywords: ["酸奶", "饮品", "取茶"], iconName: "cup.and.saucer.fill"),
        PickupBrand(name: "茶颜悦色", aliases: ["茶颜"], category: .drink, keywords: ["奶茶", "取茶", "幽兰拿铁"], iconName: "cup.and.saucer.fill"),
        PickupBrand(name: "Manner", aliases: ["MANNER"], category: .drink, keywords: ["咖啡", "取餐", "拿铁"], iconName: "cup.and.saucer.fill"),
        PickupBrand(name: "Tims", aliases: ["TIMS", "天好咖啡"], category: .drink, keywords: ["咖啡", "取餐", "拿铁"], iconName: "cup.and.saucer.fill"),
        PickupBrand(name: "M Stand", aliases: ["MSTAND"], category: .drink, keywords: ["咖啡", "取餐", "拿铁"], iconName: "cup.and.saucer.fill"),
        PickupBrand(name: "Peet's", aliases: ["PEETS", "皮爷咖啡", "皮爷"], category: .drink, keywords: ["咖啡", "取餐", "拿铁"], iconName: "cup.and.saucer.fill"),
        PickupBrand(name: "Costa", aliases: ["COSTA", "咖世家"], category: .drink, keywords: ["咖啡", "取餐", "拿铁"], iconName: "cup.and.saucer.fill"),
        PickupBrand(name: "挪瓦咖啡", aliases: ["NOWWA", "挪瓦"], category: .drink, keywords: ["咖啡", "取餐", "拿铁"], iconName: "cup.and.saucer.fill"),
        PickupBrand(name: "% Arabica", aliases: ["ARABICA"], category: .drink, keywords: ["咖啡", "取餐", "拿铁"], iconName: "cup.and.saucer.fill"),

        PickupBrand(name: "麦当劳", aliases: ["MCDONALD", "MCDONALDS", "金拱门"], category: .food, keywords: ["取餐号", "汉堡", "麦乐送"], iconName: "fork.knife", logoAssetName: "brand_mcdonalds"),
        PickupBrand(name: "肯德基", aliases: ["KFC"], category: .food, keywords: ["取餐号", "炸鸡", "汉堡"], iconName: "fork.knife", logoAssetName: "brand_kfc"),
        PickupBrand(name: "汉堡王", aliases: ["BURGER KING"], category: .food, keywords: ["取餐号", "汉堡", "皇堡"], iconName: "fork.knife", logoAssetName: "brand_burgerking"),
        PickupBrand(name: "塔斯汀", aliases: ["TASTIEN"], category: .food, keywords: ["取餐号", "汉堡", "中国汉堡"], iconName: "fork.knife", logoAssetName: "brand_tastien"),
        PickupBrand(name: "华莱士", aliases: ["WALLACE"], category: .food, keywords: ["取餐号", "炸鸡", "汉堡"], iconName: "fork.knife", logoAssetName: "brand_wallace"),
        PickupBrand(name: "德克士", aliases: ["DICOS"], category: .food, keywords: ["取餐号", "炸鸡", "汉堡"], iconName: "fork.knife", logoAssetName: "brand_dicos"),
        PickupBrand(name: "必胜客", aliases: ["PIZZA HUT", "PIZZAHUT"], category: .food, keywords: ["取餐号", "披萨", "比萨"], iconName: "fork.knife", logoAssetName: "brand_pizzahut"),
        PickupBrand(name: "达美乐", aliases: ["DOMINO", "DOMINOS", "达美乐比萨"], category: .food, keywords: ["取餐号", "披萨", "比萨"], iconName: "fork.knife", logoAssetName: "brand_dominos"),
        PickupBrand(name: "棒约翰", aliases: ["PAPA JOHNS", "PAPAJOHNS"], category: .food, keywords: ["取餐号", "披萨", "比萨"], iconName: "fork.knife", logoAssetName: "brand_papajohns"),
        PickupBrand(name: "老乡鸡", aliases: [], category: .food, keywords: ["取餐号", "米饭", "快餐"], iconName: "fork.knife", logoAssetName: "brand_lxj"),
        PickupBrand(name: "真功夫", aliases: [], category: .food, keywords: ["取餐号", "蒸饭", "快餐"], iconName: "fork.knife"),
        PickupBrand(name: "乡村基", aliases: [], category: .food, keywords: ["取餐号", "米饭", "快餐"], iconName: "fork.knife"),
        PickupBrand(name: "大米先生", aliases: [], category: .food, keywords: ["取餐号", "米饭", "快餐"], iconName: "fork.knife"),
        PickupBrand(name: "老娘舅", aliases: [], category: .food, keywords: ["取餐号", "米饭", "快餐"], iconName: "fork.knife"),
        PickupBrand(name: "永和大王", aliases: [], category: .food, keywords: ["取餐号", "豆浆", "快餐"], iconName: "fork.knife"),
        PickupBrand(name: "吉野家", aliases: ["YOSHINOYA"], category: .food, keywords: ["取餐号", "牛肉饭", "快餐"], iconName: "fork.knife", logoAssetName: "brand_yoshinoya"),
        PickupBrand(name: "食其家", aliases: ["SUKIYA"], category: .food, keywords: ["取餐号", "牛丼", "快餐"], iconName: "fork.knife", logoAssetName: "brand_sukiya"),
        PickupBrand(name: "南城香", aliases: [], category: .food, keywords: ["取餐号", "米饭", "快餐"], iconName: "fork.knife"),

        PickupBrand(name: "顺丰", aliases: ["顺丰速运", "SF EXPRESS"], category: .express, keywords: ["快递", "包裹", "取件码"], iconName: "shippingbox.fill", logoAssetName: "brand_sf"),
        PickupBrand(name: "中通", aliases: ["中通快递", "ZTO"], category: .express, keywords: ["快递", "包裹", "取件码"], iconName: "shippingbox.fill"),
        PickupBrand(name: "圆通", aliases: ["圆通快递", "YTO"], category: .express, keywords: ["快递", "包裹", "取件码"], iconName: "shippingbox.fill"),
        PickupBrand(name: "申通", aliases: ["申通快递", "STO"], category: .express, keywords: ["快递", "包裹", "取件码"], iconName: "shippingbox.fill"),
        PickupBrand(name: "韵达", aliases: ["韵达快递", "YUNDA"], category: .express, keywords: ["快递", "包裹", "取件码"], iconName: "shippingbox.fill"),
        PickupBrand(name: "极兔", aliases: ["极兔速递", "J&T", "JT"], category: .express, keywords: ["快递", "包裹", "取件码"], iconName: "shippingbox.fill"),
        PickupBrand(name: "德邦", aliases: ["德邦快递"], category: .express, keywords: ["快递", "包裹", "取件码"], iconName: "shippingbox.fill"),
        PickupBrand(name: "京东物流", aliases: ["京东快递", "JD EXPRESS"], category: .express, keywords: ["快递", "包裹", "取件码"], iconName: "shippingbox.fill", logoAssetName: "brand_jdlogistics"),
        PickupBrand(name: "跨越速运", aliases: ["跨越"], category: .express, keywords: ["快递", "包裹", "取件码"], iconName: "shippingbox.fill"),
        PickupBrand(name: "丹鸟", aliases: ["丹鸟快递", "丹鸟物流"], category: .express, keywords: ["快递", "包裹", "取件码"], iconName: "shippingbox.fill"),
        PickupBrand(name: "菜鸟速递", aliases: ["菜鸟裹裹"], category: .express, keywords: ["快递", "包裹", "取件码"], iconName: "shippingbox.fill"),
        PickupBrand(name: "菜鸟", aliases: ["菜鸟驿站"], category: .express, keywords: ["驿站", "取件码", "包裹"], iconName: "shippingbox.fill", logoAssetName: "brand_cainiao"),
        PickupBrand(name: "丰巢", aliases: ["丰巢柜", "快递柜"], category: .express, keywords: ["开柜", "取件码", "柜机"], iconName: "shippingbox.fill", logoAssetName: "brand_hivebox"),
        PickupBrand(name: "兔喜", aliases: ["兔喜生活", "兔喜快递超市"], category: .express, keywords: ["驿站", "取件码", "包裹"], iconName: "shippingbox.fill"),
        PickupBrand(name: "速递易", aliases: ["速递易柜", "快递柜"], category: .express, keywords: ["开柜", "取件码", "柜机"], iconName: "shippingbox.fill"),
        PickupBrand(name: "中国邮政", aliases: ["邮政", "EMS"], category: .express, keywords: ["快递", "包裹", "取件码", "邮政大厅"], iconName: "shippingbox.fill", logoAssetName: "brand_chinapost"),
        PickupBrand(name: "DHL", aliases: ["DHL EXPRESS"], category: .express, keywords: ["快递", "包裹", "取件码"], iconName: "shippingbox.fill"),
        PickupBrand(name: "FedEx", aliases: ["FEDEX", "联邦快递"], category: .express, keywords: ["快递", "包裹", "取件码"], iconName: "shippingbox.fill"),
        PickupBrand(name: "UPS", aliases: ["UPS快递"], category: .express, keywords: ["快递", "包裹", "取件码"], iconName: "shippingbox.fill"),
        PickupBrand(name: "驿站", aliases: ["服务站", "代收点"], category: .express, keywords: ["快递", "包裹", "取件码"], iconName: "shippingbox.fill")
    ]

    nonisolated static func detect(in text: String) -> PickupBrandDetection? {
        let normalizedText = normalize(text)
        guard normalizedText.isEmpty == false else { return nil }

        var best: PickupBrandDetection?
        for brand in brands {
            var score = 0.0
            var terms: [String] = []
            var hasBrandIdentityMatch = false

            if normalizedText.contains(normalize(brand.name)) {
                score += 15
                terms.append(brand.name)
                hasBrandIdentityMatch = true
            }

            for alias in brand.aliases where normalizedText.contains(normalize(alias)) {
                score += 10
                terms.append(alias)
                hasBrandIdentityMatch = true
            }

            if brand.name == "星巴克", normalizedText.contains(normalize("啡快口令")) {
                score += 30
                terms.append("啡快口令")
                hasBrandIdentityMatch = true
            }

            guard hasBrandIdentityMatch else { continue }

            for keyword in brand.keywords where normalizedText.contains(normalize(keyword)) {
                score += 4
                terms.append(keyword)
            }

            guard score > 0 else { continue }
            let detection = PickupBrandDetection(
                brand: brand,
                score: score,
                matchedTerms: Array(NSOrderedSet(array: terms).compactMap { $0 as? String })
            )
            if best.map({ detection.score > $0.score }) ?? true {
                best = detection
            }
        }

        if let best {
            return best
        }

        return detectLuckinByPickupTextFeatures(in: normalizedText)
            ?? detectHeyteaByPickupPageFeatures(in: normalizedText)
    }

    nonisolated private static func detectLuckinByPickupTextFeatures(in normalizedText: String) -> PickupBrandDetection? {
        guard normalizedText.contains(normalize("请扫码取餐")) || normalizedText.contains(normalize("扫码取餐")) else { return nil }
        guard containsStandaloneThreeDigitCode(in: normalizedText) else { return nil }
        guard normalizedText.contains(normalize("取餐码")) else { return nil }
        guard containsLuckinSupportFeature(in: normalizedText) else { return nil }
        guard let luckin = brands.first(where: { $0.name == "瑞幸" }) else { return nil }

        return PickupBrandDetection(
            brand: luckin,
            score: 18,
            matchedTerms: ["取餐码", "扫码取餐", "三位数", "订单/自提/制作/NO"]
        )
    }

    nonisolated private static func detectHeyteaByPickupPageFeatures(in normalizedText: String) -> PickupBrandDetection? {
        guard heyteaFallbackRequiredTerms.allSatisfy({ normalizedText.contains(normalize($0)) }) else {
            return nil
        }

        let matchedFeatures = heyteaFallbackFeatureTerms.filter {
            normalizedText.contains(normalize($0))
        }
        guard matchedFeatures.count >= 2 else { return nil }
        guard let heytea = brands.first(where: { $0.name == "喜茶" }) else { return nil }

        return PickupBrandDetection(
            brand: heytea,
            score: 12 + Double(matchedFeatures.count * 3),
            matchedTerms: heyteaFallbackRequiredTerms + matchedFeatures
        )
    }

    nonisolated private static func containsStandaloneThreeDigitCode(in text: String) -> Bool {
        let pattern = #"(^|[^0-9])\d{3}([^0-9]|$)"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.firstMatch(in: text, range: range) != nil
    }

    nonisolated private static func containsLuckinSupportFeature(in text: String) -> Bool {
        if ["订单", "自提", "制作"].contains(where: { text.contains(normalize($0)) }) {
            return true
        }

        let pattern = #"(^|[^A-Z0-9])NO([.:#号]|[^A-Z0-9]|$)"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.firstMatch(in: text, range: range) != nil
    }

    nonisolated static func fallbackCategory(for text: String) -> PickupCategory {
        let normalizedText = normalize(text)
        if ["取件", "快递", "速递", "物流", "包裹", "驿站", "菜鸟", "丰巢", "开柜", "柜机", "提货", "取货"].contains(where: { normalizedText.contains(normalize($0)) }) {
            return .express
        }
        if ["饮品", "取茶", "茶号", "奶茶", "茶饮", "柠檬茶", "果茶", "咖啡", "拿铁", "美式", "冰饮", "热饮"].contains(where: { normalizedText.contains(normalize($0)) }) {
            return .drink
        }
        return .food
    }

    nonisolated private static func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
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
}

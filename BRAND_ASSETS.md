# Brand Asset Inventory

This file tracks brand logo assets used by BiuLand. Brand names and logos may be protected trademarks, so prefer official public sources and keep source records before adding or replacing assets.

## Rules

- Store each logo in both asset catalogs:
  - `BiuLand/Assets.xcassets/<asset>.imageset`
  - `LiveActivity/Assets.xcassets/<asset>.imageset`
- Use the same `asset` name in `PickupBrandCatalog.logoAssetName`.
- Prefer SVG when the official source provides vector artwork. Use PNG only when SVG is unavailable.
- Prefer square artwork with transparent or self-contained background.
- Do not use third-party logo aggregators as the only source unless the same artwork can be verified against an official brand page.
- Record the source URL, source type, format, and date before marking an asset as verified.

## Existing Assets

| Brand | Asset | Format | App asset | Live Activity asset | Source status |
| --- | --- | --- | --- | --- | --- |
| 星巴克 | `brand_starbucks` | SVG | yes | yes | source pending |
| 瑞幸 | `brand_luckin` | SVG | yes | yes | source pending |
| 蜜雪冰城 | `brand_mixue` | SVG | yes | yes | source pending |
| 古茗 | `brand_goodme` | SVG | yes | yes | source pending |
| 霸王茶姬 | `brand_chagee` | SVG | yes | yes | source pending |
| 喜茶 | `brand_heytea` | SVG | yes | yes | source pending |
| 麦当劳 | `brand_mcdonalds` | SVG | yes | yes | source pending |
| 肯德基 | `brand_kfc` | SVG | yes | yes | source pending |
| 库迪 | `brand_cotti` | SVG | yes | yes | see `logo-review-temp/batch-1/sources.md` |
| 茶百道 | `brand_chabaidao` | SVG | yes | yes | see `logo-review-temp/batch-1/sources.md` |
| 奈雪 | `brand_naixue` | SVG | yes | yes | see `logo-review-temp/batch-1/sources.md` |
| 柠季 | `brand_linlee` | SVG | yes | yes | see `logo-review-temp/batch-1/sources.md` |
| 汉堡王 | `brand_burgerking` | SVG | yes | yes | see `logo-review-temp/batch-1/sources.md` |
| 塔斯汀 | `brand_tastien` | SVG | yes | yes | see `logo-review-temp/batch-1/sources.md` |
| 顺丰 | `brand_sf` | SVG | yes | yes | see `logo-review-temp/batch-1/sources.md` |
| 菜鸟 | `brand_cainiao` | SVG | yes | yes | see `logo-review-temp/batch-1/sources.md` |
| 德克士 | `brand_dicos` | SVG | yes | yes | see `logo-review-temp/batch-2/sources.md` |
| 必胜客 | `brand_pizzahut` | SVG | yes | yes | see `logo-review-temp/batch-2/sources.md` |
| 丰巢 | `brand_hivebox` | SVG | yes | yes | see `logo-review-temp/batch-2/sources.md` |
| 京东物流 | `brand_jdlogistics` | SVG | yes | yes | see `logo-review-temp/batch-2/sources.md` |
| 中国邮政 | `brand_chinapost` | SVG | yes | yes | see `logo-review-temp/batch-2/sources.md` |
| 沪上阿姨 | `brand_hushangayi` | SVG | yes | yes | see `logo-review-temp/batch-3/sources.md` |
| CoCo | `brand_coco` | SVG | yes | yes | see `logo-review-temp/batch-3/sources.md` |
| 华莱士 | `brand_wallace` | SVG | yes | yes | see `logo-review-temp/batch-3/sources.md` |
| 吉野家 | `brand_yoshinoya` | SVG | yes | yes | see `logo-review-temp/batch-3/sources.md` |
| 食其家 | `brand_sukiya` | SVG | yes | yes | see `logo-review-temp/batch-3/sources.md` |
| 老乡鸡 | `brand_lxj` | SVG | yes | yes | see `logo-review-temp/batch-3/sources.md` |
| 达美乐 | `brand_dominos` | SVG | yes | yes | see `logo-review-temp/batch-3/sources.md` |
| 棒约翰 | `brand_papajohns` | SVG | yes | yes | see `logo-review-temp/batch-3/sources.md` |

## Priority Collection Queue

### Batch 2

Collection status: completed; 5 assets imported from `logo-review-temp/batch-2/sources.md`.

### Batch 3

Collection status: 8 assets imported from `logo-review-temp/batch-3/sources.md`; Manner remains pending because no reliable source was reachable from the current network, and 真功夫 remains pending because no SVG was provided.

| Brand | Target asset | Category | Preferred source |
| --- | --- | --- | --- |
| Manner | `brand_manner` | 饮品 | official website / official app listing |
| 真功夫 | `brand_kungfu` | 餐食 | official website / official app listing |

## Source Record Template

| Brand | Asset | Source URL | Source type | Format | Retrieved date | Notes |
| --- | --- | --- | --- | --- | --- | --- |
|  | `brand_` |  | official website / app listing / official media kit | SVG / PNG | YYYY-MM-DD |  |

## Import Checklist

1. Add the asset to both `BiuLand/Assets.xcassets` and `LiveActivity/Assets.xcassets`.
2. Confirm both `Contents.json` files reference the same filename.
3. Set `logoAssetName` in `PickupBrandCatalog` only after both asset catalogs contain the logo.
4. Build `BiuLand` and `LiveActivityExtension`.
5. Add or update a brand detection test if the brand is newly introduced.

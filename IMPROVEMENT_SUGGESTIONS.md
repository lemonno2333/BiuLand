# BiuLand 修改建议

生成日期：2026-06-14

这份建议基于当前 Xcode 工程 `BiuLand/BiuLand.xcodeproj` 及其主 App、Live Activity、OCR/取码提取相关源码。重点放在能直接提升可靠性、识别体验和后续维护效率的改动上。

## 优先级较高

### 1. 统一 current 状态保存入口，避免截图状态被覆盖

现状：

- `LiveActivityManager.upsert(...)` 内部已经会调用 `PickupCodeHistoryStore.saveCurrent(...)` 保存当前取码，并带上 `hasScreenshot`。
- `ContentView.handlePhotoItem(...)` 在调用 `upsert(..., imageData: data)` 之后，又调用了一次 `PickupCodeHistoryStore.saveCurrent(...)`，但没有传 `hasScreenshot`，会使用默认值 `false`。
- 手动添加路径也存在类似的重复保存。

影响：

- 从截图识别成功后，截图文件可能已经保存，但 current 记录里的 `hasScreenshot` 被第二次保存覆盖为 `false`。
- 依赖 `hasScreenshot` 的清理逻辑和 UI 展示会变得不稳定，例如完成/过期后不删除截图，或者按钮状态与实际文件不一致。

建议：

- 让 `LiveActivityManager.upsert(...)` 返回保存后的 `CurrentPickupCodeItem`，调用方直接使用返回值更新 UI。
- 或者把 `PickupCodeHistoryStore.saveCurrent(...)` 完全移出 `LiveActivityManager`，由调用方负责保存。两种方案二选一，不要双写。
- `ContentState.hasScreenshot` 建议使用实际保存结果 `hasScreenshot`，不要用 `imageData != nil`。这样保存失败时 Live Activity 不会误以为截图可用。

涉及位置：

- `BiuLand/Services/LiveActivityManager.swift`
- `BiuLand/ContentView.swift`
- `BiuLand/Services/PickupCodeHistoryStore.swift`

### 2. 补一组 CodeExtractor 单元测试，锁住识别规则

现状：

- `CodeExtractor` 里已经有不少关键词、负向关键词、OCR 纠错、空间位置加权、品牌识别、门店/柜机位置提取逻辑。
- 当前工程没有看到测试 target 或测试目录。

影响：

- 识别规则越复杂，越容易出现“修好 A 品牌截图，弄坏 B 品牌截图”的回归。
- 现在调规则主要靠手动验证，后续添加品牌和码型会越来越吃力。

建议：

- 新建 `BiuLandTests` target。
- 优先测试纯函数，不依赖 Vision OCR：`CodeExtractor.bestCode(from:)`、`CodeExtractor.debugReport(from:)`、`PickupBrandCatalog.detect(in:)`。
- 建议至少覆盖这些样例：
  - 瑞幸/星巴克/喜茶/霸王茶姬等饮品取码。
  - 麦当劳/KFC 等餐食取餐号。
  - 菜鸟/丰巢/顺丰等快递取件码。
  - 带“下单时间、付款时间、订单号、手机号尾号”等负向上下文的误识别样例。
  - OCR 常见误识别，例如 `碼/號/單/貨/碍`、中英文混排、空格和标点变体。

### 3. 清理重复源码、备份文件和未使用目录

现状：

- 工程根目录下有 `Sources/`，Xcode 工程下也有 `BiuLand/BiuLand/`、`LiveActivity/`、`BiuLandWidget/`。
- 仓库里存在多份 `ContentView.swift.bak`、`ContentView.swift.backup*`、`PickupCodeLiveActivity.swift.bak`。
- `BiuLandWidget/PickupCodeLiveActivity.swift` 中 `activityContent(for state:)` 内部引用了不存在的 `context.state`，如果该文件被重新纳入 target 会直接编译失败。

影响：

- 后续修改时很容易改错文件。
- 旧文件继续留在仓库里会干扰搜索结果，也会让新接手的人误判项目结构。
- 备份源码会绕过正常版本控制，增加维护成本。

建议：

- 明确只保留当前 Xcode target 使用的源码路径。
- 删除或移出 `.bak`、`.backup*` 文件。如果确实需要保留历史，交给 git。
- 在 `.gitignore` 里加入 `*.bak`、`*.backup*`，并确认 `.DerivedData/` 不被提交。
- 如果 `BiuLandWidget/` 已废弃，就从 README 和仓库中移除；如果仍要保留，就修复其中的编译问题并接入工程。

### 4. 修正文档和实现不一致

现状：

- README 写的是“首页保留最近 10 条历史取码”。
- `PickupCodeHistoryStore.limit` 当前是 `5`，UI 里也显示 `\(historyItems.count)/5`。

影响：

- 用户和开发者会对历史记录容量产生不同预期。

建议：

- 如果产品上希望最近 10 条，就把 `limit` 和 UI 文案改成 10。
- 如果 5 条是当前设计，就更新 README。
- 最好把 `limit` 暴露成一个单一常量，UI 不要硬编码 `/5`。

## 功能完善建议

### 5. 给取码增加剩余时间和过期提示

现状：

- current 默认 20 分钟过期，Live Activity 的 `staleDate` 也是 20 分钟。
- App 首页没有明确显示剩余时间。

建议：

- 在当前取码卡片上显示“剩余 18 分钟”或“即将过期”。
- 过期前 2-3 分钟用较弱的视觉提示，不需要打断用户。
- 将 `20 * 60` 抽成共享常量，App 与 Live Activity 使用同一来源。

收益：

- 用户能判断这个码是否还值得去取，特别适合奶茶、快餐和快递柜场景。

### 6. 支持手动编辑当前取码

现状：

- 识别错了只能重新识别或手动新增。

建议：

- 当前取码卡片增加编辑入口，可以修改 code、类型、品牌/备注。
- 修改后同步更新 Live Activity。
- 编辑动作可以复用手动添加 sheet，但带入当前值。

收益：

- OCR 误识别时，用户能快速修正，不必重新截图。

### 7. 历史记录支持再次设为当前取码

现状：

- 历史记录只展示，不能直接恢复为当前实时活动。

建议：

- 历史卡片增加轻量操作，例如“重新显示”。
- 点击后把该历史项设为 current 并启动/更新 Live Activity。

收益：

- 用户误点“已经取餐/取件”或 Live Activity 被系统清掉时，可以快速恢复。

### 8. 改进截图查看体验

现状：

- 截图保存为固定文件 `current_screenshot.jpg`，仅服务当前取码。
- 截图查看页比较基础。

建议：

- 查看页支持双指缩放、拖动查看细节。
- 保存截图时可以记录原图尺寸、压缩后大小，调试模式下展示。
- 如果未来要让历史记录也能查看截图，需要改成按 current id 或 history id 存储，而不是固定文件名。

## 代码优化建议

### 9. 将识别评分配置数据化

现状：

- 关键词、正则、负向词、品牌 catalog 都写在 Swift 代码中。

建议：

- 短期可以先按 category 拆分文件，例如 `PickupKeywordRules.swift`、`PickupCodePatterns.swift`。
- 中期可以把品牌别名和关键词迁移到 JSON 或 plist，再由 Swift 加载。

收益：

- 添加品牌和调整关键词时更清楚，也方便未来做远程规则或用户自定义规则。

### 10. 抽出共享 UI 组件，减少 App 和 Live Activity 的重复逻辑

现状：

- App 当前卡片、历史卡片、Live Activity 都有相近的图标、标题、码、上下文展示逻辑。
- `visiblePickupContext(_:)` 在多个地方重复。

建议：

- 把“内部 reason 到用户可见 context”的转换抽到共享 helper。
- 把 App 内 snapshot 的展示数据建成 `PickupCodeDisplayModel`，UI 只消费 display model。
- Live Activity 因运行环境特殊，不一定能完全复用 View，但可以复用格式化和上下文过滤逻辑。

### 11. 用更明确的错误和日志替代 `print`

现状：

- 截图保存/读取失败目前使用 `print(...)`。

建议：

- 使用 `Logger`，按模块分 subsystem/category，例如 `ocr`、`liveActivity`、`screenshot`。
- 对用户可恢复的问题给出 UI 提示，例如“取码已显示，但截图保存失败”。

收益：

- 真机调试和 TestFlight 收集问题时更容易定位。

### 12. 隔离 UserDefaults，方便测试和迁移

现状：

- `PickupCodeHistoryStore` 直接使用 `UserDefaults.standard`。

建议：

- 给 store 增加可注入的 `UserDefaults` 或 protocol。
- 为 current/history 数据加版本号，未来结构变化时可以迁移。

收益：

- 单元测试不用污染真实用户默认值。
- 后续增加更多字段时更安全。

## 建议的实施顺序

1. 先修 current 双写和 `hasScreenshot` 状态问题。
2. 清理备份文件、重复目录和 README 不一致。
3. 新建测试 target，先覆盖 `CodeExtractor` 和品牌识别。
4. 增加剩余时间、编辑当前取码、历史恢复当前取码。
5. 再做规则数据化和 UI/日志/存储抽象。

如果只想先做一个小版本，我建议把第 1、3、4 项作为第一轮：它们风险低、收益明显，而且能减少后续继续迭代时的不确定性。

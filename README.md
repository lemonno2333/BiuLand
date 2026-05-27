# BiuLand

BiuLand 是一个用于从截图中自动识别取餐码、取件码、自提码的小工具。它可以从相册截图或快捷指令传入的截图中进行 OCR 识别，并把识别结果显示在 App 首页、历史记录以及 iOS 实时活动 / 灵动岛中。

## 功能

- 从截图中识别取餐码、取件码、自提码等取码信息
- 支持相册选择截图，也支持快捷指令传入截图
- 支持手动添加取码
- 自动区分食品、饮品、快递场景，并使用对应 SF Symbol
- 通过 Live Activity / Dynamic Island 显示当前取码
- 在实时活动中提供“已经取餐 / 已经取件”按钮，用于清除当前实时活动
- 首页保留最近 10 条历史取码，样式与实时活动快照一致
- 内置 OCR 调试信息，便于排查识别错误
- 支持深浅色模式和弥散渐变动态背景

## 快捷指令用法

可以在快捷指令中这样组合：

1. 添加系统动作 `截屏`
2. 添加 BiuLand 动作 `识别取码并显示`

`识别取码并显示` 会自动接收上一步传入的截图，不需要手动选择图片。识别成功后会直接更新实时活动，不再额外弹出成功对话框。

如果快捷指令动作没有自动接收截图，或仍然显示旧的参数形式，可以删除这个动作后重新添加一次，让系统刷新 App Intent 元数据。

## 识别策略

BiuLand 使用 Vision OCR 提取截图文字，并结合以下信息为候选取码打分：

- 取餐码、取件码、自提码、提货码等关键词
- 同行、邻近行的文本位置关系
- OCR 文字框位置和大小
- 负向关键词，例如下单时间、付款时间、取餐地点等
- 食品、饮品、快递相关上下文
- 常见 OCR 误识别修正

调试面板可以查看 OCR 原始行、候选取码、得分、文本框坐标等信息。

## 开发环境

- Xcode 26 或更新版本
- iOS 16.6+ 部署目标
- iOS 17+ 支持 Live Activity Intent
- SwiftUI、Vision、ActivityKit、AppIntents

## 项目结构

```text
BiuLand/
  BiuLand/                  主 App
    Components/             通用 SwiftUI 组件
    Intents/                快捷指令 App Intents
    Services/               OCR、取码提取、历史记录、实时活动管理
    Shared/                 App 与 Live Activity 共享模型
    Assets.xcassets/        App 图标和颜色资源
  LiveActivity/             实时活动 / 灵动岛扩展
  BiuLandWidget/            Widget / Live Activity 相关代码
  Design/                   设计源文件，例如 Icon Composer 文件
```

## 构建

使用 Xcode 打开：

```bash
open BiuLand.xcodeproj
```

或使用命令行构建：

```bash
xcodebuild -project BiuLand.xcodeproj -scheme BiuLand -destination 'generic/platform=iOS' build
```

## License

This project is licensed under the terms of the MIT License.

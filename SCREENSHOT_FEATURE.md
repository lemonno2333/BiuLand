# 截图保存与查看功能实现说明

## 功能概述

实现了在识别取码时保存截图，并在取码有效期内提供查看截图的功能。当取码过期或被用户标记为已完成时，自动删除截图以避免占用空间。

## 实现的文件

### 1. ScreenshotManager.swift (新增)
**位置**: `BiuLand/BiuLand/Services/ScreenshotManager.swift`

**功能**:
- 保存当前取码的截图（JPEG 格式，75% 压缩率）
- 加载当前截图
- 检查截图是否存在
- 删除当前截图
- 获取截图文件大小

**存储位置**: `Documents/Screenshots/current_screenshot.jpg`

### 2. PickupCodeHistoryStore.swift (更新)
**更新内容**:
- `CurrentPickupCodeItem` 添加 `hasScreenshot: Bool` 字段
- `saveCurrent()` 方法添加 `hasScreenshot` 参数
- `archiveCurrentIfExpired()` 在归档时删除过期截图
- `completeCurrent()` 在完成时删除截图

### 3. LiveActivityManager.swift (更新)
**更新内容**:
- `upsert()` 方法添加可选的 `imageData: Data?` 参数
- 在创建/更新 Live Activity 时保存截图
- 自动将 `hasScreenshot` 状态保存到历史记录

### 4. ContentView.swift (更新)
**新增 UI 元素**:
- **状态变量**:
  - `showScreenshotViewer`: 控制截图查看器显示
  - `screenshotImage`: 存储加载的截图
  - `lastProcessedImageData`: 临时存储处理的图片数据

- **查看截图按钮**:
  - 在当前取码卡片中显示（仅当截图存在时）
  - 位于"已经取餐/取件"按钮旁边
  - 支持长码（>4字符）和短码（≤4字符）两种布局

- **截图查看器 Sheet**:
  - 全屏黑色背景
  - 图片自适应缩放显示
  - 顶部导航栏带"完成"按钮
  - 加载时显示进度指示器

**更新逻辑**:
- `handlePhotoItem()`: 在处理图片时保存 `imageData` 参数
- 识别成功后将图片数据传递给 `LiveActivityManager`

### 5. RecognizePickupCodeIntent.swift (更新)
**更新内容**:
- 在调用 `LiveActivityManager.shared.upsert()` 时传递 `imageData` 参数
- 支持从快捷指令识别时也保存截图

### 6. LiveActivityLiveActivity.swift (锁屏实时活动颜色修复)
**更新内容**:
- 为锁屏实时活动显式设置黑色背景
- 为锁屏实时活动文字固定使用白色层级
- 补全 `WidgetBackground` 颜色资源，避免系统背景回退

## 使用流程

### 场景 1: 从相册选择图片
1. 用户点击相册图标选择截图
2. 识别成功后，截图被保存到 `Documents/Screenshots/`
3. 在当前取码卡片中显示"查看截图"按钮
4. 点击按钮可全屏查看原始截图
5. 20分钟后自动过期或用户点击"已经取餐"，截图被自动删除

### 场景 2: 通过快捷指令识别
1. 快捷指令传入截图
2. `RecognizePickupCodeIntent` 处理并保存截图
3. 后续流程同场景 1

### 场景 3: 手动添加取码
1. 用户手动输入取码（无截图）
2. 不显示"查看截图"按钮

## 数据清理机制

### 自动清理时机:
1. **过期清理**: 取码超过 20 分钟自动归档，同时删除截图
2. **完成清理**: 用户点击"已经取餐/取件"按钮，立即删除截图
3. **替换清理**: 保存新截图时自动删除旧截图

### 存储优化:
- 使用 JPEG 格式，压缩率 75%
- 仅保留当前取码的截图（最多 1 张）
- 已归档的历史记录不保留截图

## 权限要求

无需额外权限。所有文件存储在应用沙盒的 `Documents` 目录下。

## 注意事项

1. **文件名固定**: 使用 `current_screenshot.jpg`，新截图会覆盖旧截图
2. **仅当前取码**: 只有当前活跃的取码才保存截图，历史记录不保留
3. **自动清理**: 确保不会因忘记清理而占用大量空间
4. **容错处理**: 截图保存失败不影响取码识别功能

## 测试建议

1. ✅ 从相册选择图片识别，验证截图保存
2. ✅ 点击"查看截图"按钮，验证图片正确显示
3. ✅ 等待 20 分钟或点击"已经取餐"，验证截图被删除
4. ✅ 快捷指令识别，验证截图保存
5. ✅ 手动添加取码，验证不显示"查看截图"按钮
6. ✅ 在锁屏状态下查看实时通知，验证深色模式文字可见

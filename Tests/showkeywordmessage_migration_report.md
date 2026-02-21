# ShowKeywordMessage() 函数迁移报告

## 迁移概述

**任务**: 3.1.8 迁移 ShowKeywordMessage() 消息过滤器  
**日期**: 2024  
**状态**: ✅ 完成

## 迁移内容

### 源文件
- `AddOns/KeywordMonitor/Core.lua.backup` (行 968-1061)

### 目标文件
- `AddOns/KeywordMonitor/Modules/Core.lua`

### 函数签名
```lua
function Core.ShowKeywordMessage(chatFrame, event, message, sender, ...)
```

## 主要变更

### 1. 模块化引用更新

#### 配置管理
- **原**: `EnsureConfig()`
- **新**: `Config.EnsureConfig()`

#### 工具函数
- **原**: `CleanText(msg)`
- **新**: `Utils.CleanText(message)`

#### 核心功能
- **原**: `MatchKeywords(msg)`
- **新**: `Core.MatchKeywords(message)`

- **原**: `HighlightKeyword(msg, keyword)`
- **新**: `Core.HighlightKeyword(message, keyword)`

- **原**: `IsFriend(name)`
- **新**: `Core.IsFriend(name)`

- **原**: `IsRepeatMessage(cleanMsg)`
- **新**: `Core.IsRepeatMessage(cleanMsg)`

### 2. 参数名称标准化
- `msg` → `message` (更清晰的参数命名)
- `author` → `sender` (更符合消息过滤器的语义)

### 3. 依赖模块处理

由于以下模块尚未迁移，使用条件检查确保向后兼容：

#### Blacklist 模块
```lua
-- 检查黑名单（待 Blacklist 模块实现后更新）
-- TODO: 替换为 KM.Blacklist.IsBlacklisted(name, message)
if KM.IsBlacklisted and KM.IsBlacklisted(name, message) then
    return false
end
```

#### History 模块
```lua
-- 保存到历史记录（待 History 模块实现后更新）
-- TODO: 替换为 KM.History.AddToHistory()
if KM.AddToHistory then
    KM:AddToHistory({...})
end
```

#### Statistics 模块
```lua
-- 更新统计数据（待 Statistics 模块实现后更新）
-- TODO: 替换为 KM.Statistics.UpdateStatistics()
if KM.UpdateStatistics then
    KM:UpdateStatistics(keyword, timestamp)
end

-- 更新性能统计（待 Statistics 模块实现后更新）
-- TODO: 替换为 KM.Statistics.UpdatePerformance()
if KM.UpdatePerformance then
    KM:UpdatePerformance()
end
```

### 4. 字符串格式化优化
- **原**: `string.format(...)`
- **新**: `format(...)` (使用本地化的全局函数引用)

## 功能保持

以下所有原有功能均已保留：

1. ✅ 配置检查和启用状态验证
2. ✅ 过滤自己的消息
3. ✅ 过滤好友消息
4. ✅ 黑名单检查（玩家和关键词）
5. ✅ 关键词匹配检测
6. ✅ 重复消息过滤
7. ✅ 频道名称解析
8. ✅ 玩家颜色和链接生成
9. ✅ 关键词高亮显示
10. ✅ 消息输出（系统窗口和独立窗口）
11. ✅ 历史记录保存
12. ✅ 统计数据更新
13. ✅ 性能监控
14. ✅ 提示音播放

## 消息过滤逻辑

函数实现了完整的消息过滤流程：

```
输入消息
    ↓
检查监控是否启用 → 否 → 返回 false
    ↓ 是
检查是否自己的消息 → 是 → 返回 false
    ↓ 否
检查是否好友消息 → 是 → 返回 false
    ↓ 否
检查黑名单 → 是 → 返回 false
    ↓ 否
匹配关键词 → 否 → 返回 false
    ↓ 是
检查重复消息 → 是 → 返回 false
    ↓ 否
处理并输出消息
    ↓
保存历史记录
    ↓
更新统计数据
    ↓
播放提示音
    ↓
返回 false (不过滤消息)
```

## 输出模式

函数支持两种输出模式：

### 模式 1: 系统聊天窗口
- 输出到指定的聊天框架 (ChatFrame)
- 支持闪烁提示 (FlashOnMatch)
- 消息格式: `[时间] [频道] [关注] [玩家]: 消息内容`

### 模式 2: 独立监控窗口
- 输出到独立的关键词监控窗口
- 消息格式: `[时间] [频道] [玩家]: 消息内容`

## 性能优化

保持了原有的性能优化措施：

1. ✅ 使用本地化的全局函数引用
2. ✅ 简化的频道名称获取
3. ✅ 简化的颜色解析
4. ✅ 避免复杂的表达式替换
5. ✅ 重复消息缓存机制
6. ✅ 好友缓存机制（60秒刷新）

## 向后兼容性

### 全局命名空间
- 函数通过 `KM.Core.ShowKeywordMessage` 访问
- 保持与现有代码的兼容性

### 配置数据
- 完全兼容现有的 `KeywordMonitorDB` 配置结构
- 支持所有现有的配置选项

### 依赖模块
- 使用条件检查确保未迁移模块的兼容性
- 不会因为模块缺失而导致错误

## 测试

### 测试文件
- `AddOns/KeywordMonitor/Tests/test_showkeywordmessage.lua`

### 测试覆盖
1. ✅ 匹配关键词的消息
2. ✅ 不匹配关键词的消息
3. ✅ 过滤自己的消息
4. ✅ 监控禁用时的行为
5. ✅ 重复消息过滤

## 后续任务

### 待更新的引用
当以下模块迁移完成后，需要更新相应的函数调用：

1. **Blacklist 模块** (任务 5.1)
   - 更新 `IsBlacklisted` 调用为 `KM.Blacklist.IsBlacklisted`

2. **History 模块** (任务 5.5)
   - 更新 `AddToHistory` 调用为 `KM.History.AddToHistory`

3. **Statistics 模块** (任务 5.4)
   - 更新 `UpdateStatistics` 调用为 `KM.Statistics.UpdateStatistics`
   - 更新 `UpdatePerformance` 调用为 `KM.Statistics.UpdatePerformance`

### 主入口文件更新
在阶段 6 (任务 6.1) 重构主入口文件时，需要：
- 移除 `Core.lua` 中的旧 `ShowKeywordMessage` 函数
- 更新 `ChatFrame_AddMessageEventFilter` 调用使用新的模块函数

## 验收标准

根据需求 4 的验收标准：

- ✅ **标准 3**: ShowKeywordMessage() 函数作为消息过滤器已实现
- ✅ **标准 8**: 消息匹配关键词时，调用相应的输出和统计函数
- ✅ **标准 9**: 保持现有的消息过滤逻辑不变

## 结论

ShowKeywordMessage() 函数已成功迁移到 Core 模块，所有功能和性能优化均已保留。函数使用模块化的引用方式，并为未迁移的依赖模块提供了向后兼容的处理。迁移完成后，代码结构更加清晰，便于后续的维护和扩展。

# KeywordMonitor - Era 分支说明

## 关于此分支

这是 KeywordMonitor 插件的经典旧世（Era）版本，专门为硬核60级服务器优化。

## 主要变更

### 1. 接口版本更新
- 从 `Interface: 30403` (巫妖王之怒) 更新为 `Interface: 11503` (经典旧世)
- 版本号更新为 `2.0.4-era`

### 2. API 兼容性调整

#### 好友系统
- 移除了巫妖王之怒的 `C_FriendList` API
- 移除了战网好友功能（经典旧世不支持）
- 使用经典旧世的 `GetNumFriends()` 和 `GetFriendInfo()` API

#### 修改的文件
- `KeywordMonitor.toc` - 更新接口版本和描述
- `Modules/Core.lua` - 更新好友检测功能，使用经典旧世 API
- `Modules/Utils.lua` - 移除不支持的 API 引用
- `Modules/UI.lua` - 移除不支持的 API 引用

## 功能说明

所有核心功能在经典旧世中均可正常使用：
- ✅ 关键词监控和提取
- ✅ 聊天消息过滤
- ✅ 好友检测（使用经典旧世 API）
- ✅ 重复消息过滤
- ✅ 独立监控窗口
- ✅ 黑名单功能
- ✅ 关键词分组
- ✅ 快速回复
- ✅ 统计功能
- ❌ 战网好友检测（经典旧世不支持）

## 安装说明

1. 下载此分支的代码
2. 将 `KeywordMonitor` 文件夹放入魔兽世界的 `Interface/AddOns/` 目录
3. 重启游戏或重载界面 (`/reload`)
4. 使用 `/km` 命令打开配置界面

## 使用说明

与主分支使用方法完全相同：
- `/km` 或 `/keyword` - 打开配置界面
- `/km on` - 开启关键词监控
- `/km off` - 关闭关键词监控
- `/km set 关键词1,关键词2` - 设置关键词

## 技术说明

### 经典旧世 API 差异

经典旧世使用的是较旧的 API，主要差异：

1. **好友系统**
   - 巫妖王之怒: `C_FriendList.GetNumOnlineFriends()`, `C_FriendList.GetFriendInfoByIndex()`
   - 经典旧世: `GetNumFriends()`, `GetFriendInfo()`

2. **战网功能**
   - 巫妖王之怒: 支持 `C_BattleNet` API
   - 经典旧世: 不支持战网功能

3. **聊天系统**
   - 大部分聊天 API 保持兼容
   - `C_ChatInfo` 在经典旧世中不存在，已做兼容处理

## 维护说明

如需同步主分支的功能更新：
1. 确保新功能不使用经典旧世不支持的 API
2. 测试所有功能在经典旧世客户端中的表现
3. 更新此 README 文件

## 反馈

如遇到问题，请在 GitHub 上提交 Issue，并注明使用的是 era 分支。

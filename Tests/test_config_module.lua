--[[
    KeywordMonitor - Config Module Test
    配置模块测试脚本
    
    测试内容：
    1. 模块加载验证
    2. GetDefaultConfig() 函数测试
    3. EnsureConfig() 函数测试
    4. 配置初始化和验证
    5. 向后兼容性测试
--]]

-- 模拟 WoW API 环境
local function SetupMockEnvironment()
    -- 模拟全局函数
    _G.GetServerTime = function() return os.time() end
    _G.GetTime = function() return os.clock() end
    _G.date = os.date
    
    -- 模拟 SavedVariables
    _G.KeywordMonitorDB = nil
    
    print("测试环境已设置")
end

-- 测试 1: 模块加载验证
local function Test_ModuleLoading()
    print("\n=== 测试 1: 模块加载验证 ===")
    
    -- 检查全局命名空间
    if not _G.KeywordMonitor then
        print("❌ 失败: KeywordMonitor 全局命名空间不存在")
        return false
    end
    
    -- 检查 Config 模块
    if not _G.KeywordMonitor.Config then
        print("❌ 失败: Config 模块不存在")
        return false
    end
    
    -- 检查模块加载标记
    if not _G.KeywordMonitor.Config.Loaded then
        print("❌ 失败: Config 模块未标记为已加载")
        return false
    end
    
    -- 检查公共接口
    if type(_G.KeywordMonitor.Config.EnsureConfig) ~= "function" then
        print("❌ 失败: EnsureConfig 函数不存在")
        return false
    end
    
    if type(_G.KeywordMonitor.Config.GetDefaultConfig) ~= "function" then
        print("❌ 失败: GetDefaultConfig 函数不存在")
        return false
    end
    
    print("✓ 通过: 模块加载验证")
    return true
end

-- 测试 2: GetDefaultConfig() 函数
local function Test_GetDefaultConfig()
    print("\n=== 测试 2: GetDefaultConfig() 函数 ===")
    
    local KM = _G.KeywordMonitor
    local defaultConfig = KM.Config.GetDefaultConfig()
    
    -- 检查返回值类型
    if type(defaultConfig) ~= "table" then
        print("❌ 失败: GetDefaultConfig 未返回表")
        return false
    end
    
    -- 检查必需的配置项
    local requiredFields = {
        "Enabled", "Keywords", "AudioEnabled", "OutputMode", 
        "Channels", "Blacklist", "KeywordGroups", "History",
        "QuickReplies", "Statistics", "Presets", "TimeTriggers",
        "TrendData", "KeywordCorrelation", "Performance"
    }
    
    for _, field in ipairs(requiredFields) do
        if defaultConfig[field] == nil then
            print("❌ 失败: 缺少必需字段 " .. field)
            return false
        end
    end
    
    -- 检查嵌套表结构
    if type(defaultConfig.Channels) ~= "table" then
        print("❌ 失败: Channels 不是表")
        return false
    end
    
    if type(defaultConfig.Blacklist) ~= "table" or 
       type(defaultConfig.Blacklist.Players) ~= "table" or
       type(defaultConfig.Blacklist.Keywords) ~= "table" then
        print("❌ 失败: Blacklist 结构不正确")
        return false
    end
    
    -- 检查是否是深拷贝（修改副本不应影响原始配置）
    local config1 = KM.Config.GetDefaultConfig()
    local config2 = KM.Config.GetDefaultConfig()
    config1.Enabled = true
    config2.Enabled = false
    
    if config1.Enabled == config2.Enabled then
        print("❌ 失败: GetDefaultConfig 未返回独立副本")
        return false
    end
    
    print("✓ 通过: GetDefaultConfig() 函数测试")
    return true
end

-- 测试 3: EnsureConfig() 基本功能
local function Test_EnsureConfig_Basic()
    print("\n=== 测试 3: EnsureConfig() 基本功能 ===")
    
    local KM = _G.KeywordMonitor
    
    -- 清空 SavedVariables
    _G.KeywordMonitorDB = nil
    
    -- 调用 EnsureConfig
    KM.Config.EnsureConfig()
    
    -- 检查 KeywordMonitorDB 是否被创建
    if not _G.KeywordMonitorDB then
        print("❌ 失败: KeywordMonitorDB 未被创建")
        return false
    end
    
    -- 检查所有必需字段是否存在
    local requiredFields = {
        "Enabled", "Keywords", "AudioEnabled", "OutputMode",
        "Channels", "Blacklist", "KeywordGroups", "History",
        "QuickReplies", "Statistics", "Presets"
    }
    
    for _, field in ipairs(requiredFields) do
        if _G.KeywordMonitorDB[field] == nil then
            print("❌ 失败: KeywordMonitorDB 缺少字段 " .. field)
            return false
        end
    end
    
    print("✓ 通过: EnsureConfig() 基本功能测试")
    return true
end

-- 测试 4: EnsureConfig() 配置合并
local function Test_EnsureConfig_Merge()
    print("\n=== 测试 4: EnsureConfig() 配置合并 ===")
    
    local KM = _G.KeywordMonitor
    
    -- 设置部分用户配置
    _G.KeywordMonitorDB = {
        Enabled = true,
        Keywords = "测试关键词",
        -- 其他字段缺失
    }
    
    -- 调用 EnsureConfig
    KM.Config.EnsureConfig()
    
    -- 检查用户配置是否保留
    if _G.KeywordMonitorDB.Enabled ~= true then
        print("❌ 失败: 用户配置 Enabled 未保留")
        return false
    end
    
    if _G.KeywordMonitorDB.Keywords ~= "测试关键词" then
        print("❌ 失败: 用户配置 Keywords 未保留")
        return false
    end
    
    -- 检查缺失字段是否被填充
    if not _G.KeywordMonitorDB.Channels then
        print("❌ 失败: 缺失字段 Channels 未被填充")
        return false
    end
    
    if not _G.KeywordMonitorDB.Statistics then
        print("❌ 失败: 缺失字段 Statistics 未被填充")
        return false
    end
    
    print("✓ 通过: EnsureConfig() 配置合并测试")
    return true
end

-- 测试 5: 统计数据日期重置
local function Test_Statistics_DateReset()
    print("\n=== 测试 5: 统计数据日期重置 ===")
    
    local KM = _G.KeywordMonitor
    
    -- 设置旧日期的统计数据
    _G.KeywordMonitorDB = {
        Statistics = {
            TodayMatches = 100,
            LastResetDate = "2020-01-01",
            KeywordCounts = {},
            HourCounts = {},
            TotalMatches = 100,
        }
    }
    
    -- 调用 EnsureConfig
    KM.Config.EnsureConfig()
    
    -- 检查今日统计是否被重置
    if _G.KeywordMonitorDB.Statistics.TodayMatches ~= 0 then
        print("❌ 失败: 今日统计未被重置")
        return false
    end
    
    -- 检查日期是否更新
    local currentDate = os.date("%Y-%m-%d", os.time())
    if _G.KeywordMonitorDB.Statistics.LastResetDate ~= currentDate then
        print("❌ 失败: 日期未更新到当前日期")
        return false
    end
    
    print("✓ 通过: 统计数据日期重置测试")
    return true
end

-- 测试 6: 小时统计初始化
local function Test_HourCounts_Initialization()
    print("\n=== 测试 6: 小时统计初始化 ===")
    
    local KM = _G.KeywordMonitor
    
    -- 清空配置
    _G.KeywordMonitorDB = nil
    
    -- 调用 EnsureConfig
    KM.Config.EnsureConfig()
    
    -- 检查小时统计是否初始化
    if not _G.KeywordMonitorDB.Statistics.HourCounts then
        print("❌ 失败: HourCounts 未初始化")
        return false
    end
    
    -- 检查是否包含 0-23 小时
    for i = 0, 23 do
        if _G.KeywordMonitorDB.Statistics.HourCounts[i] == nil then
            print("❌ 失败: HourCounts 缺少小时 " .. i)
            return false
        end
    end
    
    print("✓ 通过: 小时统计初始化测试")
    return true
end

-- 测试 7: 向后兼容性
local function Test_BackwardCompatibility()
    print("\n=== 测试 7: 向后兼容性 ===")
    
    local KM = _G.KeywordMonitor
    
    -- 模拟旧版本配置（缺少新字段）
    _G.KeywordMonitorDB = {
        Enabled = true,
        Keywords = "MC,ZS,FS",
        AudioEnabled = true,
        OutputMode = 1,
        -- 缺少新版本的字段
    }
    
    -- 调用 EnsureConfig
    KM.Config.EnsureConfig()
    
    -- 检查旧字段是否保留
    if _G.KeywordMonitorDB.Enabled ~= true then
        print("❌ 失败: 旧字段 Enabled 未保留")
        return false
    end
    
    -- 检查新字段是否添加
    if not _G.KeywordMonitorDB.TrendData then
        print("❌ 失败: 新字段 TrendData 未添加")
        return false
    end
    
    if not _G.KeywordMonitorDB.KeywordCorrelation then
        print("❌ 失败: 新字段 KeywordCorrelation 未添加")
        return false
    end
    
    if not _G.KeywordMonitorDB.Performance then
        print("❌ 失败: 新字段 Performance 未添加")
        return false
    end
    
    print("✓ 通过: 向后兼容性测试")
    return true
end

-- 运行所有测试
local function RunAllTests()
    print("========================================")
    print("KeywordMonitor Config 模块测试")
    print("========================================")
    
    SetupMockEnvironment()
    
    local tests = {
        Test_ModuleLoading,
        Test_GetDefaultConfig,
        Test_EnsureConfig_Basic,
        Test_EnsureConfig_Merge,
        Test_Statistics_DateReset,
        Test_HourCounts_Initialization,
        Test_BackwardCompatibility,
    }
    
    local passed = 0
    local failed = 0
    
    for i, test in ipairs(tests) do
        local success = test()
        if success then
            passed = passed + 1
        else
            failed = failed + 1
        end
    end
    
    print("\n========================================")
    print("测试结果汇总")
    print("========================================")
    print(string.format("总计: %d 个测试", passed + failed))
    print(string.format("通过: %d 个测试", passed))
    print(string.format("失败: %d 个测试", failed))
    
    if failed == 0 then
        print("\n✓ 所有测试通过！")
    else
        print("\n❌ 部分测试失败，请检查上述错误信息")
    end
end

-- 执行测试
RunAllTests()

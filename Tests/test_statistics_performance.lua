--[[
    KeywordMonitor - Statistics Performance Functions Test
    测试统计模块的性能监控函数
    
    测试内容：
    - UpdatePerformance() 函数
    - GetMemoryUsage() 函数
    - GetPerformanceStats() 函数
--]]

-- 模拟 WoW API
local mockTime = 0
local mockServerTime = 1234567890
local mockMemoryUsage = 1024.5

_G.GetTime = function()
    return mockTime
end

_G.GetServerTime = function()
    return mockServerTime
end

_G.UpdateAddOnMemoryUsage = function()
    -- 模拟函数，不做任何操作
end

_G.GetAddOnMemoryUsage = function(addonName)
    if addonName == "KeywordMonitor" then
        return mockMemoryUsage
    end
    return 0
end

_G.date = os.date
_G.time = os.time
_G.print = print
_G.CreateFrame = function() return {} end
_G.UIParent = {}

-- 初始化全局命名空间
_G.KeywordMonitor = {}
local KM = _G.KeywordMonitor

-- 模拟 Config 模块
KM.Config = {}
function KM.Config.EnsureConfig()
    if not _G.KeywordMonitorDB then
        _G.KeywordMonitorDB = {
            Performance = {
                MessageCount = 0,
                MessagesPerSecond = 0,
                LastResetTime = 0,
            },
            Statistics = {
                TotalMatches = 0,
                TodayMatches = 0,
                KeywordCounts = {},
                HourCounts = {},
            },
        }
    end
end

-- 加载 Statistics 模块
dofile("AddOns/KeywordMonitor/Modules/Statistics.lua")

-- 测试辅助函数
local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message or "Assertion failed", tostring(expected), tostring(actual)))
    end
end

local function assert_not_nil(value, message)
    if value == nil then
        error(message or "Value should not be nil")
    end
end

local function assert_true(condition, message)
    if not condition then
        error(message or "Condition should be true")
    end
end

-- 测试套件
local function runTests()
    print("\n=== 开始测试 Statistics 性能监控函数 ===\n")
    
    -- 初始化配置
    KM.Config.EnsureConfig()
    
    -- 测试 1: UpdatePerformance() - 初始调用
    print("测试 1: UpdatePerformance() - 初始调用")
    mockTime = 0
    KeywordMonitorDB.Performance.LastResetTime = 0
    KeywordMonitorDB.Performance.MessageCount = 0
    
    KM.Statistics.UpdatePerformance()
    assert_equal(KeywordMonitorDB.Performance.MessageCount, 1, "消息计数应该增加到 1")
    print("✓ 消息计数正确增加")
    
    -- 测试 2: UpdatePerformance() - 多次调用但未达到10秒
    print("\n测试 2: UpdatePerformance() - 多次调用但未达到10秒")
    mockTime = 5
    for i = 1, 5 do
        KM.Statistics.UpdatePerformance()
    end
    assert_equal(KeywordMonitorDB.Performance.MessageCount, 6, "消息计数应该是 6")
    assert_equal(KeywordMonitorDB.Performance.MessagesPerSecond, 0, "每秒消息数应该还是 0（未达到10秒）")
    print("✓ 未达到10秒时不更新每秒消息数")
    
    -- 测试 3: UpdatePerformance() - 达到10秒后更新
    print("\n测试 3: UpdatePerformance() - 达到10秒后更新")
    mockTime = 10
    KM.Statistics.UpdatePerformance()
    assert_equal(KeywordMonitorDB.Performance.MessageCount, 0, "消息计数应该重置为 0")
    assert_true(KeywordMonitorDB.Performance.MessagesPerSecond > 0, "每秒消息数应该大于 0")
    assert_equal(KeywordMonitorDB.Performance.LastResetTime, 10, "重置时间应该更新为 10")
    print(string.format("✓ 每秒消息数正确计算: %.2f", KeywordMonitorDB.Performance.MessagesPerSecond))
    
    -- 测试 4: GetMemoryUsage() - 首次调用
    print("\n测试 4: GetMemoryUsage() - 首次调用")
    mockTime = 0
    mockMemoryUsage = 1024.5
    local memory = KM.Statistics.GetMemoryUsage()
    assert_equal(memory, 1024.5, "内存使用应该是 1024.5 KB")
    print("✓ 首次调用返回正确的内存使用")
    
    -- 测试 5: GetMemoryUsage() - 缓存测试（5秒内）
    print("\n测试 5: GetMemoryUsage() - 缓存测试（5秒内）")
    mockTime = 3
    mockMemoryUsage = 2048.0  -- 改变模拟值
    memory = KM.Statistics.GetMemoryUsage()
    assert_equal(memory, 1024.5, "应该返回缓存的值 1024.5 KB")
    print("✓ 5秒内使用缓存值")
    
    -- 测试 6: GetMemoryUsage() - 缓存过期（超过5秒）
    print("\n测试 6: GetMemoryUsage() - 缓存过期（超过5秒）")
    mockTime = 6
    memory = KM.Statistics.GetMemoryUsage()
    assert_equal(memory, 2048.0, "应该返回新的内存值 2048.0 KB")
    print("✓ 超过5秒后更新内存值")
    
    -- 测试 7: GetPerformanceStats() - 完整性能统计
    print("\n测试 7: GetPerformanceStats() - 完整性能统计")
    KeywordMonitorDB.Performance.MessagesPerSecond = 5.5
    KeywordMonitorDB.Statistics.TotalMatches = 100
    mockTime = 12
    mockMemoryUsage = 1500.0
    
    local stats = KM.Statistics.GetPerformanceStats()
    assert_not_nil(stats, "性能统计不应该为 nil")
    assert_equal(stats.memory, 1500.0, "内存统计应该是 1500.0 KB")
    assert_equal(stats.messagesPerSecond, 5.5, "每秒消息数应该是 5.5")
    assert_equal(stats.totalMessages, 100, "总消息数应该是 100")
    print("✓ 性能统计返回完整数据")
    print(string.format("  - 内存: %.2f KB", stats.memory))
    print(string.format("  - 每秒消息数: %.2f", stats.messagesPerSecond))
    print(string.format("  - 总消息数: %d", stats.totalMessages))
    
    -- 测试 8: 向后兼容性接口
    print("\n测试 8: 向后兼容性接口")
    assert_not_nil(KM.UpdatePerformance, "KM:UpdatePerformance() 应该存在")
    assert_not_nil(KM.GetMemoryUsage, "KM:GetMemoryUsage() 应该存在")
    assert_not_nil(KM.GetPerformanceStats, "KM:GetPerformanceStats() 应该存在")
    
    -- 测试向后兼容接口是否工作
    mockTime = 20
    KeywordMonitorDB.Performance.MessageCount = 0
    KeywordMonitorDB.Performance.LastResetTime = 20
    KM:UpdatePerformance()
    assert_equal(KeywordMonitorDB.Performance.MessageCount, 1, "向后兼容接口应该正常工作")
    
    local compatMemory = KM:GetMemoryUsage()
    assert_not_nil(compatMemory, "向后兼容的 GetMemoryUsage 应该返回值")
    
    local compatStats = KM:GetPerformanceStats()
    assert_not_nil(compatStats, "向后兼容的 GetPerformanceStats 应该返回值")
    print("✓ 向后兼容性接口正常工作")
    
    print("\n=== 所有测试通过！ ===\n")
end

-- 运行测试
local success, error = pcall(runTests)
if not success then
    print("\n❌ 测试失败:")
    print(error)
    os.exit(1)
else
    os.exit(0)
end

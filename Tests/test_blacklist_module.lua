--[[
    Blacklist Module Test
    测试 Blacklist 模块独立加载和功能
    
    验证项：
    1. 模块文件存在且无语法错误
    2. 所有函数在 KM.Blacklist 命名空间中正确定义
    3. 模块加载标记 (KM.Blacklist.Loaded) 已设置
    4. IsBlacklisted 函数正确检查玩家和关键词黑名单
    5. GetBlacklistPlayers 和 GetBlacklistKeywords 函数正确返回列表
    6. 向后兼容性接口 (KM:GetBlacklistPlayers, KM:GetBlacklistKeywords) 正常工作
--]]

-- 模拟 WoW API 环境
local function setupMockEnvironment()
    -- 模拟全局函数
    _G.CreateFrame = function() return {} end
    _G.UIParent = {}
    _G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    
    -- 初始化全局命名空间
    _G.KeywordMonitor = {}
    
    -- 模拟配置数据
    _G.KeywordMonitorDB = {
        Blacklist = {
            Players = {
                ["TestPlayer1"] = true,
                ["TestPlayer2"] = true,
                ["恶意玩家"] = true
            },
            Keywords = {
                ["垃圾"] = true,
                ["spam"] = true,
                ["广告"] = true
            }
        }
    }
end

-- 测试结果收集
local testResults = {
    passed = 0,
    failed = 0,
    errors = {}
}

-- 测试辅助函数
local function assert_true(condition, message)
    if condition then
        testResults.passed = testResults.passed + 1
        print("✓ PASS: " .. message)
    else
        testResults.failed = testResults.failed + 1
        print("✗ FAIL: " .. message)
        table.insert(testResults.errors, message)
    end
end

local function assert_false(condition, message)
    assert_true(not condition, message)
end

local function assert_not_nil(value, message)
    assert_true(value ~= nil, message)
end

local function assert_type(value, expectedType, message)
    assert_true(type(value) == expectedType, message .. " (expected " .. expectedType .. ", got " .. type(value) .. ")")
end

local function assert_equals(actual, expected, message)
    assert_true(actual == expected, message .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
end

-- 主测试函数
local function runTests()
    print("\n========================================")
    print("Blacklist Module Test Suite")
    print("========================================\n")
    
    -- 设置模拟环境
    setupMockEnvironment()
    
    -- 测试 1: 加载 Utils 模块（依赖）
    print("Test 1: Loading Utils module (dependency)...")
    local utilsSuccess, utilsErr = pcall(function()
        dofile("AddOns/KeywordMonitor/Modules/Utils.lua")
    end)
    
    if not utilsSuccess then
        print("✗ FAIL: Utils module failed to load - " .. tostring(utilsErr))
        testResults.failed = testResults.failed + 1
        table.insert(testResults.errors, "Utils module load error: " .. tostring(utilsErr))
        return testResults
    end
    
    print("✓ PASS: Utils module loaded")
    testResults.passed = testResults.passed + 1
    
    -- 测试 2: 加载 Blacklist 模块
    print("\nTest 2: Loading Blacklist module...")
    local success, err = pcall(function()
        dofile("AddOns/KeywordMonitor/Modules/Blacklist.lua")
    end)
    
    if not success then
        print("✗ FAIL: Module failed to load - " .. tostring(err))
        testResults.failed = testResults.failed + 1
        table.insert(testResults.errors, "Module load error: " .. tostring(err))
        return testResults
    end
    
    print("✓ PASS: Module loaded without syntax errors")
    testResults.passed = testResults.passed + 1
    
    -- 获取模块引用
    local KM = _G.KeywordMonitor
    
    -- 测试 3: 验证命名空间
    print("\nTest 3: Verifying namespace...")
    assert_not_nil(KM, "KeywordMonitor global namespace exists")
    assert_not_nil(KM.Blacklist, "KM.Blacklist namespace exists")
    
    -- 测试 4: 验证模块加载标记
    print("\nTest 4: Verifying module loaded flag...")
    assert_true(KM.Blacklist.Loaded == true, "KM.Blacklist.Loaded is set to true")
    
    -- 测试 5: 验证所有必需函数存在
    print("\nTest 5: Verifying all required functions exist...")
    
    local requiredFunctions = {
        "IsBlacklisted",
        "GetBlacklistPlayers",
        "GetBlacklistKeywords"
    }
    
    for _, funcName in ipairs(requiredFunctions) do
        assert_not_nil(KM.Blacklist[funcName], "Function KM.Blacklist." .. funcName .. " exists")
        assert_type(KM.Blacklist[funcName], "function", "KM.Blacklist." .. funcName .. " is a function")
    end
    
    -- 测试 6: 测试 IsBlacklisted 函数 - 玩家黑名单
    print("\nTest 6: Testing IsBlacklisted - Player blacklist...")
    
    assert_true(KM.Blacklist.IsBlacklisted("TestPlayer1", nil), "Blacklisted player returns true")
    assert_true(KM.Blacklist.IsBlacklisted("TestPlayer2", nil), "Another blacklisted player returns true")
    assert_true(KM.Blacklist.IsBlacklisted("恶意玩家", nil), "Chinese name blacklisted player returns true")
    assert_false(KM.Blacklist.IsBlacklisted("GoodPlayer", nil), "Non-blacklisted player returns false")
    assert_false(KM.Blacklist.IsBlacklisted(nil, nil), "Nil player returns false")
    
    -- 测试 7: 测试 IsBlacklisted 函数 - 关键词黑名单
    print("\nTest 7: Testing IsBlacklisted - Keyword blacklist...")
    
    assert_true(KM.Blacklist.IsBlacklisted(nil, "这是垃圾消息"), "Message with blacklisted keyword returns true")
    assert_true(KM.Blacklist.IsBlacklisted(nil, "This is spam"), "English spam message returns true")
    assert_true(KM.Blacklist.IsBlacklisted(nil, "广告内容"), "Chinese ad message returns true")
    assert_false(KM.Blacklist.IsBlacklisted(nil, "正常消息"), "Normal message returns false")
    assert_false(KM.Blacklist.IsBlacklisted(nil, "Hello world"), "Clean English message returns false")
    
    -- 测试 8: 测试 IsBlacklisted 函数 - 组合检查
    print("\nTest 8: Testing IsBlacklisted - Combined checks...")
    
    assert_true(KM.Blacklist.IsBlacklisted("TestPlayer1", "正常消息"), "Blacklisted player with normal message returns true")
    assert_true(KM.Blacklist.IsBlacklisted("GoodPlayer", "垃圾消息"), "Normal player with blacklisted keyword returns true")
    assert_true(KM.Blacklist.IsBlacklisted("TestPlayer1", "垃圾消息"), "Blacklisted player with blacklisted keyword returns true")
    assert_false(KM.Blacklist.IsBlacklisted("GoodPlayer", "正常消息"), "Normal player with normal message returns false")
    
    -- 测试 9: 测试 GetBlacklistPlayers 函数
    print("\nTest 9: Testing GetBlacklistPlayers...")
    
    local players = KM.Blacklist.GetBlacklistPlayers()
    assert_type(players, "table", "GetBlacklistPlayers returns a table")
    assert_equals(#players, 3, "GetBlacklistPlayers returns correct count")
    
    -- 验证列表已排序
    local isSorted = true
    for i = 1, #players - 1 do
        if players[i] > players[i + 1] then
            isSorted = false
            break
        end
    end
    assert_true(isSorted, "GetBlacklistPlayers returns sorted list")
    
    -- 测试 10: 测试 GetBlacklistKeywords 函数
    print("\nTest 10: Testing GetBlacklistKeywords...")
    
    local keywords = KM.Blacklist.GetBlacklistKeywords()
    assert_type(keywords, "table", "GetBlacklistKeywords returns a table")
    assert_equals(#keywords, 3, "GetBlacklistKeywords returns correct count")
    
    -- 验证列表已排序
    isSorted = true
    for i = 1, #keywords - 1 do
        if keywords[i] > keywords[i + 1] then
            isSorted = false
            break
        end
    end
    assert_true(isSorted, "GetBlacklistKeywords returns sorted list")
    
    -- 测试 11: 测试向后兼容性接口
    print("\nTest 11: Testing backward compatibility interface...")
    
    assert_not_nil(KM.GetBlacklistPlayers, "KM:GetBlacklistPlayers exists")
    assert_not_nil(KM.GetBlacklistKeywords, "KM:GetBlacklistKeywords exists")
    
    local compatPlayers = KM:GetBlacklistPlayers()
    assert_type(compatPlayers, "table", "KM:GetBlacklistPlayers returns a table")
    assert_equals(#compatPlayers, 3, "KM:GetBlacklistPlayers returns correct count")
    
    local compatKeywords = KM:GetBlacklistKeywords()
    assert_type(compatKeywords, "table", "KM:GetBlacklistKeywords returns a table")
    assert_equals(#compatKeywords, 3, "KM:GetBlacklistKeywords returns correct count")
    
    -- 测试 12: 测试空配置处理
    print("\nTest 12: Testing empty configuration handling...")
    
    -- 保存原始配置
    local originalDB = _G.KeywordMonitorDB
    
    -- 测试 nil 配置
    _G.KeywordMonitorDB = nil
    assert_false(KM.Blacklist.IsBlacklisted("TestPlayer", "test"), "IsBlacklisted handles nil DB")
    
    local emptyPlayers = KM.Blacklist.GetBlacklistPlayers()
    assert_equals(#emptyPlayers, 0, "GetBlacklistPlayers returns empty list for nil DB")
    
    local emptyKeywords = KM.Blacklist.GetBlacklistKeywords()
    assert_equals(#emptyKeywords, 0, "GetBlacklistKeywords returns empty list for nil DB")
    
    -- 恢复配置
    _G.KeywordMonitorDB = originalDB
    
    -- 打印测试总结
    print("\n========================================")
    print("Test Summary")
    print("========================================")
    print("Total Passed: " .. testResults.passed)
    print("Total Failed: " .. testResults.failed)
    
    if testResults.failed > 0 then
        print("\nFailed Tests:")
        for _, error in ipairs(testResults.errors) do
            print("  - " .. error)
        end
    end
    
    print("========================================\n")
    
    return testResults
end

-- 运行测试
local results = runTests()

-- 返回退出码
if results.failed > 0 then
    os.exit(1)
else
    os.exit(0)
end

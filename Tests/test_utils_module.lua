--[[
    Utils Module Test
    测试 Utils 模块独立加载
    
    验证项：
    1. 模块文件存在且无语法错误
    2. 所有函数在 KM.Utils 命名空间中正确定义
    3. 模块加载标记 (KM.Utils.Loaded) 已设置
    4. 所有本地化全局函数可访问
--]]

-- 模拟 WoW API 环境
local function setupMockEnvironment()
    -- 模拟全局函数
    _G.CreateFrame = function() return {} end
    _G.UIParent = {}
    _G.GameTooltip = {}
    _G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    _G.RAID_CLASS_COLORS = {}
    _G.GetServerTime = function() return 0 end
    _G.date = os.date
    _G.GetTime = function() return 0 end
    _G.time = os.time
    _G.InCombatLockdown = function() return false end
    _G.PlaySound = function() end
    _G.PlaySoundFile = function() end
    _G.SOUNDKIT = {}
    _G.Ambiguate = function(name) return name end
    _G.IsShiftKeyDown = function() return false end
    _G.UnitName = function() return "Player" end
    _G.GetPlayerInfoByGUID = function() return nil end
    _G.GetColoredName = function(name) return name end
    _G.GetPlayerLink = function(name) return name end
    _G.C_Timer = {}
    _G.C_FriendList = {}
    _G.C_BattleNet = {}
    _G.BNGetNumFriends = function() return 0 end
    _G.BNGetFriendInfoByID = function() return nil end
    _G.BNET_CLIENT_WOW = 1
    _G.ChatEdit_ChooseBoxForSend = function() end
    _G.ChatEdit_SendText = function() end
    _G.ChatFrame_SendTell = function() end
    _G.C_ChatInfo = { ReplaceIconAndGroupExpressions = function(text) return text end }
    _G.ChatFrame_CanChatGroupPerformExpressionExpansion = function() return false end
    _G.FCF_StartAlertFlash = function() end
    _G.GeneralDockManager = {}
    _G.GetChatWindowInfo = function() return nil end
    _G.NUM_CHAT_WINDOWS = 10
    _G.UpdateAddOnMemoryUsage = function() end
    _G.GetAddOnMemoryUsage = function() return 0 end
    _G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    
    -- 初始化全局命名空间
    _G.KeywordMonitor = {}
    _G.KeywordMonitorDB = { UseNDuiStyle = false }
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

local function assert_not_nil(value, message)
    assert_true(value ~= nil, message)
end

local function assert_type(value, expectedType, message)
    assert_true(type(value) == expectedType, message .. " (expected " .. expectedType .. ", got " .. type(value) .. ")")
end

-- 主测试函数
local function runTests()
    print("\n========================================")
    print("Utils Module Test Suite")
    print("========================================\n")
    
    -- 设置模拟环境
    setupMockEnvironment()
    
    -- 测试 1: 加载模块文件
    print("Test 1: Loading Utils module...")
    local success, err = pcall(function()
        dofile("AddOns/KeywordMonitor/Modules/Utils.lua")
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
    
    -- 测试 2: 验证命名空间
    print("\nTest 2: Verifying namespace...")
    assert_not_nil(KM, "KeywordMonitor global namespace exists")
    assert_not_nil(KM.Utils, "KM.Utils namespace exists")
    
    -- 测试 3: 验证模块加载标记
    print("\nTest 3: Verifying module loaded flag...")
    assert_true(KM.Utils.Loaded == true, "KM.Utils.Loaded is set to true")
    
    -- 测试 4: 验证所有必需函数存在
    print("\nTest 4: Verifying all required functions exist...")
    
    local requiredFunctions = {
        "CleanText",
        "SplitString",
        "CreateBD",
        "CreateFS",
        "CreateButton",
        "CreateCheckBox",
        "CreateEditBox",
        "CreateCloseButton",
        "CleanupUIElements"
    }
    
    for _, funcName in ipairs(requiredFunctions) do
        assert_not_nil(KM.Utils[funcName], "Function KM.Utils." .. funcName .. " exists")
        assert_type(KM.Utils[funcName], "function", "KM.Utils." .. funcName .. " is a function")
    end
    
    -- 测试 5: 测试文本处理函数
    print("\nTest 5: Testing text processing functions...")
    
    -- 测试 CleanText
    local cleanedText = KM.Utils.CleanText("|cff00ff00Hello|r World!")
    assert_type(cleanedText, "string", "CleanText returns a string")
    assert_true(cleanedText == "HELLOWORLD", "CleanText removes colors and punctuation (expected 'HELLOWORLD', got '" .. cleanedText .. "')")
    
    -- 测试空文本
    local emptyClean = KM.Utils.CleanText(nil)
    assert_true(emptyClean == "", "CleanText handles nil input")
    
    -- 测试 SplitString
    local parts = KM.Utils.SplitString("apple,banana,cherry", ",")
    assert_type(parts, "table", "SplitString returns a table")
    assert_true(#parts == 3, "SplitString splits correctly (expected 3 parts, got " .. #parts .. ")")
    assert_true(parts[1] == "apple", "SplitString first part is 'apple'")
    assert_true(parts[2] == "banana", "SplitString second part is 'banana'")
    assert_true(parts[3] == "cherry", "SplitString third part is 'cherry'")
    
    -- 测试中文逗号
    local chineseParts = KM.Utils.SplitString("苹果，香蕉，樱桃", ",")
    assert_true(#chineseParts == 3, "SplitString handles Chinese comma (expected 3 parts, got " .. #chineseParts .. ")")
    
    -- 测试空字符串
    local emptyParts = KM.Utils.SplitString("", ",")
    assert_true(#emptyParts == 0, "SplitString handles empty string")
    
    -- 测试 6: 测试 UI 辅助函数（基本调用）
    print("\nTest 6: Testing UI helper functions (basic calls)...")
    
    -- 创建模拟框架
    local mockFrame = {
        CreateFontString = function() 
            return {
                SetFont = function() end,
                SetText = function() end,
                SetJustifyH = function() end
            }
        end,
        SetBackdrop = function() end,
        SetBackdropColor = function() end,
        SetBackdropBorderColor = function() end
    }
    
    -- 测试 CreateBD
    local bdSuccess = pcall(function()
        KM.Utils.CreateBD(mockFrame)
    end)
    assert_true(bdSuccess, "CreateBD executes without error")
    
    -- 测试 CreateFS
    local fs = KM.Utils.CreateFS(mockFrame, 12, "Test")
    assert_not_nil(fs, "CreateFS returns a value")
    
    -- 测试 CleanupUIElements
    local cleanupSuccess = pcall(function()
        KM.Utils.CleanupUIElements({})
    end)
    assert_true(cleanupSuccess, "CleanupUIElements executes without error")
    
    -- 测试 nil 输入
    local cleanupNilSuccess = pcall(function()
        KM.Utils.CleanupUIElements(nil)
    end)
    assert_true(cleanupNilSuccess, "CleanupUIElements handles nil input")
    
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

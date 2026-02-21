--[[
    KeywordMonitor - QuickReply Module Test
    快速回复模块测试文件
    
    测试内容：
    1. 模块加载验证
    2. 快速回复添加功能
    3. 快速回复删除功能
    4. 快速回复列表管理
    5. UI函数可用性
--]]

-- 模拟WoW API环境
local function SetupTestEnvironment()
    -- 全局命名空间
    _G.KeywordMonitor = _G.KeywordMonitor or {}
    _G.KeywordMonitorDB = _G.KeywordMonitorDB or {
        QuickReplies = {},
        UseNDuiStyle = false
    }
    
    -- 模拟WoW API
    _G.CreateFrame = _G.CreateFrame or function() return {} end
    _G.UIParent = _G.UIParent or {}
    _G.C_Timer = _G.C_Timer or {
        After = function(delay, callback) callback() end,
        NewTimer = function(delay, callback) return {Cancel = function() end} end
    }
    _G.ChatFrame_SendTell = _G.ChatFrame_SendTell or function() end
    _G.ChatEdit_ChooseBoxForSend = _G.ChatEdit_ChooseBoxForSend or function() return nil end
    _G.ChatEdit_SendText = _G.ChatEdit_SendText or function() end
end

-- 测试结果收集
local testResults = {
    passed = 0,
    failed = 0,
    tests = {}
}

-- 断言函数
local function assert_equal(actual, expected, testName)
    if actual == expected then
        testResults.passed = testResults.passed + 1
        table.insert(testResults.tests, {name = testName, status = "PASS"})
        print("|cff00FF00[PASS]|r " .. testName)
        return true
    else
        testResults.failed = testResults.failed + 1
        table.insert(testResults.tests, {name = testName, status = "FAIL", 
            message = string.format("Expected: %s, Got: %s", tostring(expected), tostring(actual))})
        print("|cffFF0000[FAIL]|r " .. testName .. string.format(" (Expected: %s, Got: %s)", tostring(expected), tostring(actual)))
        return false
    end
end

local function assert_true(condition, testName)
    return assert_equal(condition, true, testName)
end

local function assert_not_nil(value, testName)
    if value ~= nil then
        testResults.passed = testResults.passed + 1
        table.insert(testResults.tests, {name = testName, status = "PASS"})
        print("|cff00FF00[PASS]|r " .. testName)
        return true
    else
        testResults.failed = testResults.failed + 1
        table.insert(testResults.tests, {name = testName, status = "FAIL", message = "Value is nil"})
        print("|cffFF0000[FAIL]|r " .. testName .. " (Value is nil)")
        return false
    end
end

-- 运行测试
local function RunTests()
    print("\n|cffFFFF00========================================|r")
    print("|cffFFFF00  KeywordMonitor QuickReply Module Test|r")
    print("|cffFFFF00========================================|r\n")
    
    SetupTestEnvironment()
    
    local KM = _G.KeywordMonitor
    
    -- 测试 1: 模块加载验证
    print("|cff00FFFF--- Test 1: Module Loading ---|r")
    assert_not_nil(KM.QuickReply, "QuickReply module should be loaded")
    assert_true(KM.QuickReply.Loaded == true, "QuickReply module should be marked as loaded")
    
    -- 测试 2: 公共接口存在性
    print("\n|cff00FFFF--- Test 2: Public Interface ---|r")
    assert_not_nil(KM.QuickReply.AddQuickReply, "AddQuickReply function should exist")
    assert_not_nil(KM.QuickReply.RemoveQuickReply, "RemoveQuickReply function should exist")
    assert_not_nil(KM.QuickReply.SendQuickReply, "SendQuickReply function should exist")
    assert_not_nil(KM.QuickReply.ShowQuickReplyUI, "ShowQuickReplyUI function should exist")
    assert_not_nil(KM.QuickReply.RefreshQuickReplyList, "RefreshQuickReplyList function should exist")
    assert_not_nil(KM.QuickReply.ShowQuickReplyForPlayer, "ShowQuickReplyForPlayer function should exist")
    assert_not_nil(KM.QuickReply.ShowQuickReplyConfirmation, "ShowQuickReplyConfirmation function should exist")
    
    -- 测试 3: 向后兼容接口
    print("\n|cff00FFFF--- Test 3: Backward Compatibility ---|r")
    assert_not_nil(KM.AddQuickReply, "KM:AddQuickReply should exist for backward compatibility")
    assert_not_nil(KM.RemoveQuickReply, "KM:RemoveQuickReply should exist for backward compatibility")
    assert_not_nil(KM.SendQuickReply, "KM:SendQuickReply should exist for backward compatibility")
    assert_not_nil(KM.ShowQuickReplyUI, "KM:ShowQuickReplyUI should exist for backward compatibility")
    
    -- 测试 4: 添加快速回复
    print("\n|cff00FFFF--- Test 4: Add Quick Reply ---|r")
    KeywordMonitorDB.QuickReplies = {}
    KM.QuickReply.AddQuickReply("测试回复1")
    assert_equal(#KeywordMonitorDB.QuickReplies, 1, "Should have 1 quick reply after adding")
    assert_equal(KeywordMonitorDB.QuickReplies[1], "测试回复1", "Quick reply text should match")
    
    -- 测试 5: 添加重复回复（应该被拒绝）
    print("\n|cff00FFFF--- Test 5: Add Duplicate Reply ---|r")
    KM.QuickReply.AddQuickReply("测试回复1")
    assert_equal(#KeywordMonitorDB.QuickReplies, 1, "Should still have 1 quick reply (duplicate rejected)")
    
    -- 测试 6: 添加多个回复
    print("\n|cff00FFFF--- Test 6: Add Multiple Replies ---|r")
    KM.QuickReply.AddQuickReply("测试回复2")
    KM.QuickReply.AddQuickReply("测试回复3")
    assert_equal(#KeywordMonitorDB.QuickReplies, 3, "Should have 3 quick replies")
    
    -- 测试 7: 删除快速回复
    print("\n|cff00FFFF--- Test 7: Remove Quick Reply ---|r")
    KM.QuickReply.RemoveQuickReply(2)
    assert_equal(#KeywordMonitorDB.QuickReplies, 2, "Should have 2 quick replies after removal")
    assert_equal(KeywordMonitorDB.QuickReplies[1], "测试回复1", "First reply should remain")
    assert_equal(KeywordMonitorDB.QuickReplies[2], "测试回复3", "Third reply should move to second position")
    
    -- 测试 8: 空文本处理
    print("\n|cff00FFFF--- Test 8: Empty Text Handling ---|r")
    local countBefore = #KeywordMonitorDB.QuickReplies
    KM.QuickReply.AddQuickReply("")
    assert_equal(#KeywordMonitorDB.QuickReplies, countBefore, "Should not add empty text")
    KM.QuickReply.AddQuickReply(nil)
    assert_equal(#KeywordMonitorDB.QuickReplies, countBefore, "Should not add nil text")
    
    -- 测试 9: 无效索引删除
    print("\n|cff00FFFF--- Test 9: Invalid Index Removal ---|r")
    local countBefore = #KeywordMonitorDB.QuickReplies
    KM.QuickReply.RemoveQuickReply(999)
    assert_equal(#KeywordMonitorDB.QuickReplies, countBefore, "Should not remove with invalid index")
    KM.QuickReply.RemoveQuickReply(nil)
    assert_equal(#KeywordMonitorDB.QuickReplies, countBefore, "Should not remove with nil index")
    
    -- 打印测试总结
    print("\n|cffFFFF00========================================|r")
    print("|cffFFFF00  Test Summary|r")
    print("|cffFFFF00========================================|r")
    print(string.format("|cff00FF00Passed:|r %d", testResults.passed))
    print(string.format("|cffFF0000Failed:|r %d", testResults.failed))
    print(string.format("|cffFFFFFFTotal:|r %d", testResults.passed + testResults.failed))
    
    if testResults.failed == 0 then
        print("\n|cff00FF00All tests passed! ✓|r")
    else
        print("\n|cffFF0000Some tests failed! ✗|r")
        print("\n|cffFF0000Failed tests:|r")
        for _, test in ipairs(testResults.tests) do
            if test.status == "FAIL" then
                print(string.format("  - %s: %s", test.name, test.message or ""))
            end
        end
    end
    
    return testResults.failed == 0
end

-- 如果直接运行此文件，执行测试
if not _G.KeywordMonitor then
    RunTests()
end

-- 导出测试函数供外部调用
return {
    RunTests = RunTests,
    SetupTestEnvironment = SetupTestEnvironment
}

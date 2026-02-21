--[[
    Groups Module Test
    测试 Groups 模块独立加载和功能
    
    验证项：
    1. 模块文件存在且无语法错误
    2. 所有函数在 KM.Groups 命名空间中正确定义
    3. 模块加载标记 (KM.Groups.Loaded) 已设置
    4. AddKeywordGroup 函数正确添加分组
    5. RemoveKeywordGroup 函数正确删除分组
    6. UpdateKeywordGroup 函数正确更新分组
    7. GetEnabledKeywordGroups 函数正确返回启用的分组
    8. SetTimeTrigger 和 RemoveTimeTrigger 函数正确管理时间触发
    9. CheckTimeTriggers 函数正确检查和应用时间触发
    10. 向后兼容性接口正常工作
--]]

-- 模拟 WoW API 环境
local function setupMockEnvironment()
    -- 模拟全局函数
    _G.CreateFrame = function(frameType, name, parent, template)
        local frame = {
            frameType = frameType,
            name = name,
            parent = parent,
            template = template,
            children = {},
            scripts = {}
        }
        
        function frame:SetSize(width, height)
            self.width = width
            self.height = height
        end
        
        function frame:SetPoint(...)
            self.points = {...}
        end
        
        function frame:SetFrameStrata(strata)
            self.strata = strata
        end
        
        function frame:SetFrameLevel(level)
            self.level = level
        end
        
        function frame:SetBackdrop(backdrop)
            self.backdrop = backdrop
        end
        
        function frame:SetBackdropColor(...)
            self.backdropColor = {...}
        end
        
        function frame:SetBackdropBorderColor(...)
            self.backdropBorderColor = {...}
        end
        
        function frame:Hide()
            self.hidden = true
        end
        
        function frame:Show()
            self.hidden = false
        end
        
        function frame:IsShown()
            return not self.hidden
        end
        
        function frame:SetMovable(movable)
            self.movable = movable
        end
        
        function frame:EnableMouse(enable)
            self.mouseEnabled = enable
        end
        
        function frame:RegisterForDrag(button)
            self.dragButton = button
        end
        
        function frame:SetScript(event, handler)
            self.scripts[event] = handler
        end
        
        function frame:StartMoving() end
        function frame:StopMovingOrSizing() end
        function frame:SetScrollChild(child) self.scrollChild = child end
        function frame:SetHeight(height) self.height = height end
        function frame:SetText(text) self.text = text end
        function frame:GetText() return self.text or "" end
        function frame:SetChecked(checked) self.checked = checked end
        function frame:GetChecked() return self.checked end
        function frame:ClearFocus() end
        function frame:SetTextColor(...) self.textColor = {...} end
        
        return frame
    end
    
    _G.UIParent = {}
    _G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    _G.GetServerTime = function() return os.time() end
    
    -- 初始化全局命名空间
    _G.KeywordMonitor = {}
    
    -- 模拟配置数据
    _G.KeywordMonitorDB = {
        KeywordGroups = {},
        TimeTriggers = {},
        UseKeywordGroups = false,
        UseNDuiStyle = false,
        Keywords = "测试,关键词"
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
    print("Groups Module Test Suite")
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
    
    -- 测试 2: 加载 Config 模块（依赖）
    print("\nTest 2: Loading Config module (dependency)...")
    local configSuccess, configErr = pcall(function()
        dofile("AddOns/KeywordMonitor/Modules/Config.lua")
    end)
    
    if not configSuccess then
        print("✗ FAIL: Config module failed to load - " .. tostring(configErr))
        testResults.failed = testResults.failed + 1
        table.insert(testResults.errors, "Config module load error: " .. tostring(configErr))
        return testResults
    end
    
    print("✓ PASS: Config module loaded")
    testResults.passed = testResults.passed + 1
    
    -- 测试 3: 加载 Groups 模块
    print("\nTest 3: Loading Groups module...")
    local success, err = pcall(function()
        dofile("AddOns/KeywordMonitor/Modules/Groups.lua")
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
    
    -- 测试 4: 验证命名空间
    print("\nTest 4: Verifying namespace...")
    assert_not_nil(KM, "KeywordMonitor global namespace exists")
    assert_not_nil(KM.Groups, "KM.Groups namespace exists")
    
    -- 测试 5: 验证模块加载标记
    print("\nTest 5: Verifying module loaded flag...")
    assert_true(KM.Groups.Loaded == true, "KM.Groups.Loaded is set to true")
    
    -- 测试 6: 验证所有必需函数存在
    print("\nTest 6: Verifying all required functions exist...")
    
    local requiredFunctions = {
        "AddKeywordGroup",
        "RemoveKeywordGroup",
        "UpdateKeywordGroup",
        "GetEnabledKeywordGroups",
        "ShowKeywordGroupsUI",
        "RefreshGroupsList",
        "SetTimeTrigger",
        "RemoveTimeTrigger",
        "CheckTimeTriggers"
    }
    
    for _, funcName in ipairs(requiredFunctions) do
        assert_not_nil(KM.Groups[funcName], "Function KM.Groups." .. funcName .. " exists")
        assert_type(KM.Groups[funcName], "function", "KM.Groups." .. funcName .. " is a function")
    end
    
    -- 测试 7: 测试 AddKeywordGroup 函数
    print("\nTest 7: Testing AddKeywordGroup...")
    
    local initialCount = #KeywordMonitorDB.KeywordGroups
    local group1 = KM.Groups.AddKeywordGroup("测试分组1", "关键词1,关键词2", {1, 0, 0})
    
    assert_not_nil(group1, "AddKeywordGroup returns a group object")
    assert_equals(#KeywordMonitorDB.KeywordGroups, initialCount + 1, "Group count increased by 1")
    assert_equals(group1.name, "测试分组1", "Group name is correct")
    assert_equals(group1.keywords, "关键词1,关键词2", "Group keywords are correct")
    assert_true(group1.enabled, "Group is enabled by default")
    assert_not_nil(group1.color, "Group has color")
    
    -- 测试默认参数
    local group2 = KM.Groups.AddKeywordGroup()
    assert_equals(group2.name, "新分组", "Default name is '新分组'")
    assert_equals(group2.keywords, "", "Default keywords are empty")
    assert_true(group2.enabled, "Default enabled is true")
    
    -- 测试 8: 测试 UpdateKeywordGroup 函数
    print("\nTest 8: Testing UpdateKeywordGroup...")
    
    local groupIndex = #KeywordMonitorDB.KeywordGroups
    KM.Groups.UpdateKeywordGroup(groupIndex, "更新后的名称", "新关键词", false, {0, 1, 0})
    
    local updatedGroup = KeywordMonitorDB.KeywordGroups[groupIndex]
    assert_equals(updatedGroup.name, "更新后的名称", "Group name updated")
    assert_equals(updatedGroup.keywords, "新关键词", "Group keywords updated")
    assert_false(updatedGroup.enabled, "Group enabled status updated")
    assert_equals(updatedGroup.color[2], 1, "Group color updated")
    
    -- 测试部分更新
    KM.Groups.UpdateKeywordGroup(groupIndex, "只更新名称")
    assert_equals(updatedGroup.name, "只更新名称", "Partial update works - name")
    assert_equals(updatedGroup.keywords, "新关键词", "Partial update preserves other fields")
    
    -- 测试 9: 测试 GetEnabledKeywordGroups 函数
    print("\nTest 9: Testing GetEnabledKeywordGroups...")
    
    -- 添加一些测试分组
    KM.Groups.AddKeywordGroup("启用分组1", "kw1", nil)
    KM.Groups.AddKeywordGroup("启用分组2", "kw2", nil)
    local disabledIndex = #KeywordMonitorDB.KeywordGroups + 1
    KM.Groups.AddKeywordGroup("禁用分组", "kw3", nil)
    KM.Groups.UpdateKeywordGroup(disabledIndex, nil, nil, false)
    
    local enabledGroups = KM.Groups.GetEnabledKeywordGroups()
    assert_type(enabledGroups, "table", "GetEnabledKeywordGroups returns a table")
    
    -- 验证所有返回的分组都是启用的
    local allEnabled = true
    for _, group in ipairs(enabledGroups) do
        if not group.enabled then
            allEnabled = false
            break
        end
    end
    assert_true(allEnabled, "All returned groups are enabled")
    
    -- 测试 10: 测试 RemoveKeywordGroup 函数
    print("\nTest 10: Testing RemoveKeywordGroup...")
    
    local countBeforeRemove = #KeywordMonitorDB.KeywordGroups
    local groupToRemove = KeywordMonitorDB.KeywordGroups[1]
    local removedName = groupToRemove.name
    
    KM.Groups.RemoveKeywordGroup(1)
    
    assert_equals(#KeywordMonitorDB.KeywordGroups, countBeforeRemove - 1, "Group count decreased by 1")
    
    -- 验证被删除的分组不再存在
    local found = false
    for _, group in ipairs(KeywordMonitorDB.KeywordGroups) do
        if group.name == removedName then
            found = true
            break
        end
    end
    assert_false(found, "Removed group no longer exists")
    
    -- 测试无效索引
    local countBefore = #KeywordMonitorDB.KeywordGroups
    KM.Groups.RemoveKeywordGroup(999)
    assert_equals(#KeywordMonitorDB.KeywordGroups, countBefore, "Invalid index doesn't remove anything")
    
    -- 测试 11: 测试 SetTimeTrigger 函数
    print("\nTest 11: Testing SetTimeTrigger...")
    
    KM.Groups.SetTimeTrigger(1, 8, 22)
    
    assert_not_nil(KeywordMonitorDB.TimeTriggers[1], "Time trigger created")
    assert_equals(KeywordMonitorDB.TimeTriggers[1].startHour, 8, "Start hour is correct")
    assert_equals(KeywordMonitorDB.TimeTriggers[1].endHour, 22, "End hour is correct")
    
    -- 测试跨天时间段
    KM.Groups.SetTimeTrigger(2, 22, 2)
    assert_equals(KeywordMonitorDB.TimeTriggers[2].startHour, 22, "Cross-day start hour is correct")
    assert_equals(KeywordMonitorDB.TimeTriggers[2].endHour, 2, "Cross-day end hour is correct")
    
    -- 测试 12: 测试 RemoveTimeTrigger 函数
    print("\nTest 12: Testing RemoveTimeTrigger...")
    
    KM.Groups.RemoveTimeTrigger(1)
    assert_true(KeywordMonitorDB.TimeTriggers[1] == nil, "Time trigger removed")
    
    -- 测试移除不存在的触发器
    KM.Groups.RemoveTimeTrigger(999)
    -- 应该不会报错
    
    -- 测试 13: 测试 CheckTimeTriggers 函数
    print("\nTest 13: Testing CheckTimeTriggers...")
    
    -- 清空并重新设置测试数据
    KeywordMonitorDB.KeywordGroups = {}
    KeywordMonitorDB.TimeTriggers = {}
    
    -- 添加测试分组
    KM.Groups.AddKeywordGroup("时间触发测试", "test", nil)
    
    -- 获取当前小时
    local currentHour = tonumber(os.date("%H"))
    
    -- 设置一个应该启用的时间段（当前时间在范围内）
    local startHour = (currentHour - 1 + 24) % 24
    local endHour = (currentHour + 1) % 24
    
    -- 如果跨越午夜，调整测试逻辑
    if startHour > endHour then
        -- 跨天情况，确保当前时间在范围内
        KM.Groups.SetTimeTrigger(1, startHour, endHour)
    else
        -- 正常情况
        KM.Groups.SetTimeTrigger(1, startHour, endHour)
    end
    
    -- 先禁用分组
    KM.Groups.UpdateKeywordGroup(1, nil, nil, false)
    
    -- 检查时间触发
    KM.Groups.CheckTimeTriggers()
    
    -- 由于当前时间在范围内，分组应该被启用
    assert_true(KeywordMonitorDB.KeywordGroups[1].enabled, "Time trigger enables group when in range")
    
    -- 测试 14: 测试 ShowKeywordGroupsUI 函数
    print("\nTest 14: Testing ShowKeywordGroupsUI...")
    
    -- 调用函数创建UI
    KM.Groups.ShowKeywordGroupsUI()
    
    assert_not_nil(KM.groupsFrame, "Groups frame created")
    assert_type(KM.groupsFrame, "table", "Groups frame is a table")
    assert_not_nil(KM.groupsFrame.scrollChild, "Scroll child exists")
    
    -- 测试切换显示
    local wasShown = KM.groupsFrame:IsShown()
    KM.Groups.ShowKeywordGroupsUI()
    assert_true(KM.groupsFrame:IsShown() ~= wasShown, "ShowKeywordGroupsUI toggles visibility")
    
    -- 测试 15: 测试 RefreshGroupsList 函数
    print("\nTest 15: Testing RefreshGroupsList...")
    
    -- 确保有一些分组
    KeywordMonitorDB.KeywordGroups = {}
    KM.Groups.AddKeywordGroup("刷新测试1", "kw1", nil)
    KM.Groups.AddKeywordGroup("刷新测试2", "kw2", nil)
    
    -- 调用刷新
    KM.Groups.RefreshGroupsList()
    
    -- 验证 scrollChild.groups 被更新
    assert_not_nil(KM.groupsFrame.scrollChild.groups, "Groups list exists")
    assert_type(KM.groupsFrame.scrollChild.groups, "table", "Groups list is a table")
    
    -- 测试 16: 测试向后兼容性接口
    print("\nTest 16: Testing backward compatibility interface...")
    
    local compatFunctions = {
        "AddKeywordGroup",
        "RemoveKeywordGroup",
        "UpdateKeywordGroup",
        "GetEnabledKeywordGroups",
        "ShowKeywordGroupsUI",
        "RefreshGroupsList",
        "SetTimeTrigger",
        "RemoveTimeTrigger",
        "CheckTimeTriggers"
    }
    
    for _, funcName in ipairs(compatFunctions) do
        assert_not_nil(KM[funcName], "KM:" .. funcName .. " exists")
        assert_type(KM[funcName], "function", "KM:" .. funcName .. " is a function")
    end
    
    -- 测试兼容性接口功能
    local compatGroup = KM:AddKeywordGroup("兼容性测试", "test", nil)
    assert_not_nil(compatGroup, "KM:AddKeywordGroup works")
    
    local compatEnabled = KM:GetEnabledKeywordGroups()
    assert_type(compatEnabled, "table", "KM:GetEnabledKeywordGroups works")
    
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

--[[
    Statistics Module Test
    测试 Statistics 模块独立加载和功能
    
    验证项：
    1. 模块文件存在且无语法错误
    2. 所有函数在 KM.Statistics 命名空间中正确定义
    3. 模块加载标记 (KM.Statistics.Loaded) 已设置
    4. 统计数据更新和查询功能正常
    5. 趋势分析功能正常
    6. 关联分析功能正常
    7. 性能监控功能正常
    8. 内存优化功能正常
    9. UI 函数正确定义
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
        
        function frame:SetBackdropColor(r, g, b, a)
            self.backdropColor = {r, g, b, a}
        end
        
        function frame:SetBackdropBorderColor(r, g, b, a)
            self.backdropBorderColor = {r, g, b, a}
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
        
        function frame:SetScrollChild(child)
            self.scrollChild = child
        end
        
        function frame:SetHeight(height)
            self.height = height
        end
        
        function frame:SetText(text)
            self.text = text
        end
        
        function frame:GetText()
            return self.text or ""
        end
        
        function frame:SetChecked(checked)
            self.checked = checked
        end
        
        function frame:GetChecked()
            return self.checked
        end
        
        function frame:SetNumeric(numeric)
            self.numeric = numeric
        end
        
        return frame
    end
    
    _G.UIParent = {}
    _G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    _G.GameTooltip = {
        SetOwner = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end
    }
    
    -- 模拟时间函数
    local mockTime = 1640000000
    _G.GetServerTime = function() return mockTime end
    _G.GetTime = function() return mockTime end
    _G.time = function(t)
        if not t then return mockTime end
        -- 简化的时间计算
        return mockTime
    end
    _G.date = function(format, timestamp)
        timestamp = timestamp or mockTime
        if format == "%Y-%m-%d" then
            return "2021-12-20"
        elseif format == "%Y-%m-%d-%H" then
            return "2021-12-20-10"
        elseif format == "%H" then
            return "10"
        end
        return "2021-12-20"
    end
    
    -- 模拟内存函数
    _G.UpdateAddOnMemoryUsage = function() end
    _G.GetAddOnMemoryUsage = function(addon)
        return 512.5  -- 返回模拟的内存使用量（KB）
    end
    
    _G.collectgarbage = function(opt)
        return 0
    end
    
    -- 模拟 C_Timer
    _G.C_Timer = {
        After = function(delay, callback)
            -- 立即执行回调（测试环境）
            if callback then callback() end
        end,
        NewTicker = function(interval, callback)
            return {
                Cancel = function() end
            }
        end
    }
    
    -- 初始化全局命名空间
    _G.KeywordMonitor = {}
    
    -- 模拟配置数据
    _G.KeywordMonitorDB = {
        UseNDuiStyle = false,
        AutoCleanOldData = true,
        DataRetentionDays = 7,
        Statistics = {
            TodayMatches = 0,
            LastResetDate = "2021-12-20",
            KeywordCounts = {},
            HourCounts = {},
            TotalMatches = 0
        },
        TrendData = {
            Daily = {},
            Hourly = {}
        },
        KeywordCorrelation = {},
        Performance = {
            MessageCount = 0,
            MessagesPerSecond = 0,
            LastResetTime = mockTime
        },
        History = {}
    }
    
    -- 初始化小时统计
    for i = 0, 23 do
        _G.KeywordMonitorDB.Statistics.HourCounts[i] = 0
    end
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
    print("Statistics Module Test Suite")
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
    
    -- 测试 3: 加载 Statistics 模块
    print("\nTest 3: Loading Statistics module...")
    local statsSuccess, statsErr = pcall(function()
        dofile("AddOns/KeywordMonitor/Modules/Statistics.lua")
    end)
    
    if not statsSuccess then
        print("✗ FAIL: Statistics module failed to load - " .. tostring(statsErr))
        testResults.failed = testResults.failed + 1
        table.insert(testResults.errors, "Statistics module load error: " .. tostring(statsErr))
        return testResults
    end
    
    print("✓ PASS: Statistics module loaded")
    testResults.passed = testResults.passed + 1
    
    local KM = _G.KeywordMonitor
    
    -- 测试 4: 验证模块加载标记
    print("\nTest 4: Verifying module loaded flag...")
    assert_true(KM.Statistics.Loaded == true, "KM.Statistics.Loaded should be true")
    
    -- 测试 5: 验证核心统计函数存在
    print("\nTest 5: Verifying core statistics functions exist...")
    assert_type(KM.Statistics.UpdateStatistics, "function", "UpdateStatistics should be a function")
    assert_type(KM.Statistics.GetStatistics, "function", "GetStatistics should be a function")
    assert_type(KM.Statistics.ResetStatistics, "function", "ResetStatistics should be a function")
    assert_type(KM.Statistics.GetTopKeywords, "function", "GetTopKeywords should be a function")
    assert_type(KM.Statistics.GetTopHours, "function", "GetTopHours should be a function")
    
    -- 测试 6: 验证趋势分析函数存在
    print("\nTest 6: Verifying trend analysis functions exist...")
    assert_type(KM.Statistics.UpdateTrendData, "function", "UpdateTrendData should be a function")
    assert_type(KM.Statistics.GetKeywordTrend, "function", "GetKeywordTrend should be a function")
    assert_type(KM.Statistics.GetOverallTrend, "function", "GetOverallTrend should be a function")
    
    -- 测试 7: 验证关联分析函数存在
    print("\nTest 7: Verifying correlation analysis functions exist...")
    assert_type(KM.Statistics.UpdateKeywordCorrelation, "function", "UpdateKeywordCorrelation should be a function")
    assert_type(KM.Statistics.GetKeywordCorrelations, "function", "GetKeywordCorrelations should be a function")
    
    -- 测试 8: 验证性能监控函数存在
    print("\nTest 8: Verifying performance monitoring functions exist...")
    assert_type(KM.Statistics.UpdatePerformance, "function", "UpdatePerformance should be a function")
    assert_type(KM.Statistics.GetMemoryUsage, "function", "GetMemoryUsage should be a function")
    assert_type(KM.Statistics.GetPerformanceStats, "function", "GetPerformanceStats should be a function")
    
    -- 测试 9: 验证内存优化函数存在
    print("\nTest 9: Verifying memory optimization functions exist...")
    assert_type(KM.Statistics.OptimizeMemory, "function", "OptimizeMemory should be a function")
    assert_type(KM.Statistics.CleanOldData, "function", "CleanOldData should be a function")
    assert_type(KM.Statistics.DiagnoseMemory, "function", "DiagnoseMemory should be a function")
    
    -- 测试 10: 验证 UI 函数存在
    print("\nTest 10: Verifying UI functions exist...")
    assert_type(KM.Statistics.ShowStatisticsUI, "function", "ShowStatisticsUI should be a function")
    assert_type(KM.Statistics.RefreshStatistics, "function", "RefreshStatistics should be a function")
    assert_type(KM.Statistics.ShowPerformanceUI, "function", "ShowPerformanceUI should be a function")
    assert_type(KM.Statistics.RefreshPerformance, "function", "RefreshPerformance should be a function")
    assert_type(KM.Statistics.ShowTrendAnalysisUI, "function", "ShowTrendAnalysisUI should be a function")
    assert_type(KM.Statistics.RefreshTrendAnalysis, "function", "RefreshTrendAnalysis should be a function")
    assert_type(KM.Statistics.ShowCorrelationAnalysisUI, "function", "ShowCorrelationAnalysisUI should be a function")
    assert_type(KM.Statistics.RefreshCorrelationAnalysis, "function", "RefreshCorrelationAnalysis should be a function")
    
    -- 测试 11: 测试统计数据更新
    print("\nTest 11: Testing statistics update...")
    KM.Statistics.UpdateStatistics("测试关键词", GetServerTime())
    local stats = KM.Statistics.GetStatistics()
    assert_equals(stats.TodayMatches, 1, "TodayMatches should be 1 after one update")
    assert_equals(stats.TotalMatches, 1, "TotalMatches should be 1 after one update")
    assert_not_nil(stats.KeywordCounts["测试关键词"], "Keyword should be tracked")
    
    -- 测试 12: 测试多个关键词更新
    print("\nTest 12: Testing multiple keywords update...")
    KM.Statistics.UpdateStatistics({"关键词1", "关键词2"}, GetServerTime())
    stats = KM.Statistics.GetStatistics()
    assert_equals(stats.TodayMatches, 2, "TodayMatches should be 2 after two updates")
    assert_not_nil(stats.KeywordCounts["关键词1"], "Keyword1 should be tracked")
    assert_not_nil(stats.KeywordCounts["关键词2"], "Keyword2 should be tracked")
    
    -- 测试 13: 测试热门关键词获取
    print("\nTest 13: Testing GetTopKeywords...")
    local topKeywords = KM.Statistics.GetTopKeywords(5)
    assert_type(topKeywords, "table", "GetTopKeywords should return a table")
    assert_true(#topKeywords > 0, "GetTopKeywords should return at least one keyword")
    
    -- 测试 14: 测试活跃时段获取
    print("\nTest 14: Testing GetTopHours...")
    local topHours = KM.Statistics.GetTopHours(5)
    assert_type(topHours, "table", "GetTopHours should return a table")
    assert_equals(#topHours, 5, "GetTopHours should return 5 hours")
    
    -- 测试 15: 测试趋势数据更新
    print("\nTest 15: Testing trend data update...")
    KM.Statistics.UpdateTrendData({"趋势关键词"}, GetServerTime())
    local trend = KM.Statistics.GetKeywordTrend("趋势关键词", 7)
    assert_type(trend, "table", "GetKeywordTrend should return a table")
    assert_equals(#trend, 7, "GetKeywordTrend should return 7 days of data")
    
    -- 测试 16: 测试总体趋势
    print("\nTest 16: Testing overall trend...")
    local overallTrend = KM.Statistics.GetOverallTrend(7)
    assert_type(overallTrend, "table", "GetOverallTrend should return a table")
    assert_equals(#overallTrend, 7, "GetOverallTrend should return 7 days of data")
    
    -- 测试 17: 测试关联分析
    print("\nTest 17: Testing keyword correlation...")
    KM.Statistics.UpdateKeywordCorrelation({"关联词1", "关联词2"})
    local correlations = KM.Statistics.GetKeywordCorrelations("关联词1", 5)
    assert_type(correlations, "table", "GetKeywordCorrelations should return a table")
    
    -- 测试 18: 测试性能统计
    print("\nTest 18: Testing performance stats...")
    KM.Statistics.UpdatePerformance()
    local perfStats = KM.Statistics.GetPerformanceStats()
    assert_type(perfStats, "table", "GetPerformanceStats should return a table")
    assert_not_nil(perfStats.memory, "Performance stats should include memory")
    assert_not_nil(perfStats.messagesPerSecond, "Performance stats should include messagesPerSecond")
    assert_not_nil(perfStats.totalMessages, "Performance stats should include totalMessages")
    
    -- 测试 19: 测试内存使用获取
    print("\nTest 19: Testing memory usage...")
    local memory = KM.Statistics.GetMemoryUsage()
    assert_type(memory, "number", "GetMemoryUsage should return a number")
    assert_true(memory > 0, "Memory usage should be greater than 0")
    
    -- 测试 20: 测试内存优化
    print("\nTest 20: Testing memory optimization...")
    local cleaned = KM.Statistics.OptimizeMemory()
    assert_type(cleaned, "number", "OptimizeMemory should return a number")
    
    -- 测试 21: 测试统计重置
    print("\nTest 21: Testing statistics reset...")
    KM.Statistics.ResetStatistics()
    stats = KM.Statistics.GetStatistics()
    assert_equals(stats.TodayMatches, 0, "TodayMatches should be 0 after reset")
    assert_equals(stats.TotalMatches, 0, "TotalMatches should be 0 after reset")
    
    -- 测试 22: 验证向后兼容性接口
    print("\nTest 22: Verifying backward compatibility interfaces...")
    assert_type(KM.UpdateStatistics, "function", "KM:UpdateStatistics should exist")
    assert_type(KM.GetStatistics, "function", "KM:GetStatistics should exist")
    assert_type(KM.ResetStatistics, "function", "KM:ResetStatistics should exist")
    assert_type(KM.GetTopKeywords, "function", "KM:GetTopKeywords should exist")
    assert_type(KM.GetTopHours, "function", "KM:GetTopHours should exist")
    assert_type(KM.ShowStatisticsUI, "function", "KM:ShowStatisticsUI should exist")
    assert_type(KM.ShowPerformanceUI, "function", "KM:ShowPerformanceUI should exist")
    assert_type(KM.ShowTrendAnalysisUI, "function", "KM:ShowTrendAnalysisUI should exist")
    assert_type(KM.ShowCorrelationAnalysisUI, "function", "KM:ShowCorrelationAnalysisUI should exist")
    
    -- 测试 23: 测试 UI 创建（不显示）
    print("\nTest 23: Testing UI creation...")
    local uiSuccess, uiErr = pcall(function()
        KM.Statistics.ShowStatisticsUI()
        KM.Statistics.ShowPerformanceUI()
        KM.Statistics.ShowTrendAnalysisUI()
        KM.Statistics.ShowCorrelationAnalysisUI()
    end)
    
    if uiSuccess then
        print("✓ PASS: UI functions executed without errors")
        testResults.passed = testResults.passed + 1
        
        -- 验证 UI 框架已创建
        assert_not_nil(KM.statisticsFrame, "Statistics frame should be created")
        assert_not_nil(KM.performanceFrame, "Performance frame should be created")
        assert_not_nil(KM.trendFrame, "Trend frame should be created")
        assert_not_nil(KM.correlationFrame, "Correlation frame should be created")
    else
        print("✗ FAIL: UI creation failed - " .. tostring(uiErr))
        testResults.failed = testResults.failed + 1
        table.insert(testResults.errors, "UI creation error: " .. tostring(uiErr))
    end
    
    -- 打印测试总结
    print("\n========================================")
    print("Test Summary")
    print("========================================")
    print(string.format("Total Tests: %d", testResults.passed + testResults.failed))
    print(string.format("Passed: %d", testResults.passed))
    print(string.format("Failed: %d", testResults.failed))
    
    if testResults.failed > 0 then
        print("\nFailed Tests:")
        for i, error in ipairs(testResults.errors) do
            print(string.format("  %d. %s", i, error))
        end
    end
    
    print("========================================\n")
    
    return testResults
end

-- 运行测试
return runTests()

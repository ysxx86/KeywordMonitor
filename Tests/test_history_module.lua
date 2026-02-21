--[[
    History Module Test
    测试 History 模块独立加载和功能
    
    验证项：
    1. 模块文件存在且无语法错误
    2. 所有函数在 KM 命名空间中正确定义
    3. 历史记录添加功能正常
    4. 历史记录查询功能正常
    5. 历史记录清空功能正常
    6. 历史记录搜索功能正常
    7. 重复消息合并功能正常
    8. 历史记录数量限制功能正常
    9. 历史记录保留天数功能正常
    10. UI 函数正确定义
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
        
        function frame:SetFontObject(font)
            self.font = font
        end
        
        function frame:SetWidth(width)
            self.width = width
        end
        
        function frame:SetMaxLetters(max)
            self.maxLetters = max
        end
        
        function frame:SetMultiLine(multiline)
            self.multiline = multiline
        end
        
        function frame:SetAutoFocus(autofocus)
            self.autofocus = autofocus
        end
        
        function frame:SetFocus() end
        function frame:HighlightText() end
        function frame:SetCursorPosition(pos) end
        function frame:ClearFocus() end
        function frame:GetFontString()
            return {
                SetTextColor = function() end
            }
        end
        function frame:RegisterForClicks() end
        function frame:SetWordWrap() end
        
        return frame
    end
    
    _G.UIParent = CreateFrame("Frame", "UIParent")
    _G.ChatFontNormal = {}
    _G.GetTime = function() return os.clock() end
    
    -- 模拟 print 函数
    _G.print = function(...)
        local args = {...}
        local msg = ""
        for i, v in ipairs(args) do
            msg = msg .. tostring(v)
            if i < #args then msg = msg .. " " end
        end
        print("[WoW Print]", msg)
    end
end

-- 运行测试
local function runTests()
    print("\n========================================")
    print("开始测试 History 模块")
    print("========================================\n")
    
    -- 设置模拟环境
    setupMockEnvironment()
    
    -- 初始化全局命名空间
    _G.KeywordMonitor = {}
    local KM = _G.KeywordMonitor
    
    -- 模拟 KeywordMonitorDB
    _G.KeywordMonitorDB = {
        History = {},
        HistoryMaxCount = 100,
        HistoryRetentionDays = 3,
        UseNDuiStyle = false
    }
    
    -- 测试 1: 加载 Utils 模块（依赖）
    print("测试 1: 加载 Utils 模块...")
    local utilsPath = "AddOns/KeywordMonitor/Modules/Utils.lua"
    local utilsChunk, utilsErr = loadfile(utilsPath)
    if not utilsChunk then
        print("❌ Utils 模块加载失败: " .. tostring(utilsErr))
        return false
    end
    
    local utilsSuccess, utilsResult = pcall(utilsChunk)
    if not utilsSuccess then
        print("❌ Utils 模块执行失败: " .. tostring(utilsResult))
        return false
    end
    print("✓ Utils 模块加载成功")
    
    -- 测试 2: 加载 Config 模块（依赖）
    print("\n测试 2: 加载 Config 模块...")
    local configPath = "AddOns/KeywordMonitor/Modules/Config.lua"
    local configChunk, configErr = loadfile(configPath)
    if not configChunk then
        print("❌ Config 模块加载失败: " .. tostring(configErr))
        return false
    end
    
    local configSuccess, configResult = pcall(configChunk)
    if not configSuccess then
        print("❌ Config 模块执行失败: " .. tostring(configResult))
        return false
    end
    print("✓ Config 模块加载成功")
    
    -- 测试 3: 加载 History 模块
    print("\n测试 3: 加载 History 模块...")
    local historyPath = "AddOns/KeywordMonitor/Modules/History.lua"
    local historyChunk, historyErr = loadfile(historyPath)
    if not historyChunk then
        print("❌ History 模块加载失败: " .. tostring(historyErr))
        return false
    end
    
    local historySuccess, historyResult = pcall(historyChunk)
    if not historySuccess then
        print("❌ History 模块执行失败: " .. tostring(historyResult))
        return false
    end
    print("✓ History 模块加载成功")
    
    -- 测试 4: 验证函数定义
    print("\n测试 4: 验证函数定义...")
    local requiredFunctions = {
        "AddToHistory",
        "GetHistory",
        "ClearHistory",
        "SearchHistory",
        "ShowHistoryUI",
        "RefreshHistoryList",
        "ShowEditCopyDialog"
    }
    
    local allFunctionsExist = true
    for _, funcName in ipairs(requiredFunctions) do
        if type(KM[funcName]) ~= "function" then
            print("❌ 函数 " .. funcName .. " 未定义或不是函数")
            allFunctionsExist = false
        else
            print("✓ 函数 " .. funcName .. " 已定义")
        end
    end
    
    if not allFunctionsExist then
        return false
    end
    
    -- 测试 5: 测试添加历史记录
    print("\n测试 5: 测试添加历史记录...")
    local testRecord = {
        time = os.time(),
        timeStr = "12:00:00",
        name = "TestPlayer",
        msg = "Test message",
        channelName = "[综合]",
        r = 1,
        g = 0.5,
        b = 0.5
    }
    
    KM:AddToHistory(testRecord)
    local history = KM:GetHistory()
    
    if #history == 1 then
        print("✓ 历史记录添加成功，当前记录数: " .. #history)
    else
        print("❌ 历史记录添加失败，期望 1 条，实际 " .. #history .. " 条")
        return false
    end
    
    -- 测试 6: 测试获取历史记录
    print("\n测试 6: 测试获取历史记录...")
    local retrievedHistory = KM:GetHistory()
    if type(retrievedHistory) == "table" and #retrievedHistory == 1 then
        print("✓ 获取历史记录成功")
        print("  - 玩家名: " .. retrievedHistory[1].name)
        print("  - 消息: " .. retrievedHistory[1].msg)
    else
        print("❌ 获取历史记录失败")
        return false
    end
    
    -- 测试 7: 测试重复消息合并
    print("\n测试 7: 测试重复消息合并...")
    local duplicateRecord = {
        time = os.time(),
        timeStr = "12:00:30",
        name = "TestPlayer",
        msg = "Test message",
        channelName = "[世界]",
        r = 1,
        g = 0.5,
        b = 0.5
    }
    
    KM:AddToHistory(duplicateRecord)
    history = KM:GetHistory()
    
    if #history == 1 then
        print("✓ 重复消息合并成功，记录数保持为 1")
        print("  - 合并后频道: " .. history[1].channelName)
    else
        print("❌ 重复消息合并失败，期望 1 条，实际 " .. #history .. " 条")
        return false
    end
    
    -- 测试 8: 测试搜索历史记录
    print("\n测试 8: 测试搜索历史记录...")
    local searchResults = KM:SearchHistory("Test")
    if #searchResults == 1 then
        print("✓ 搜索历史记录成功，找到 " .. #searchResults .. " 条")
    else
        print("❌ 搜索历史记录失败")
        return false
    end
    
    local emptyResults = KM:SearchHistory("NonExistent")
    if #emptyResults == 0 then
        print("✓ 搜索不存在的内容返回空结果")
    else
        print("❌ 搜索不存在的内容应返回空结果")
        return false
    end
    
    -- 测试 9: 测试清空历史记录
    print("\n测试 9: 测试清空历史记录...")
    KM:ClearHistory()
    history = KM:GetHistory()
    
    if #history == 0 then
        print("✓ 清空历史记录成功")
    else
        print("❌ 清空历史记录失败，还有 " .. #history .. " 条记录")
        return false
    end
    
    -- 测试 10: 测试历史记录数量限制
    print("\n测试 10: 测试历史记录数量限制...")
    KeywordMonitorDB.HistoryMaxCount = 5
    
    for i = 1, 10 do
        local record = {
            time = os.time() + i,
            timeStr = "12:00:" .. string.format("%02d", i),
            name = "Player" .. i,
            msg = "Message " .. i,
            channelName = "[综合]",
            r = 1,
            g = 1,
            b = 1
        }
        KM:AddToHistory(record)
    end
    
    history = KM:GetHistory()
    if #history == 5 then
        print("✓ 历史记录数量限制正常，保持在 " .. #history .. " 条")
    else
        print("❌ 历史记录数量限制失败，期望 5 条，实际 " .. #history .. " 条")
        return false
    end
    
    -- 测试 11: 测试历史记录保留天数
    print("\n测试 11: 测试历史记录保留天数...")
    KM:ClearHistory()
    KeywordMonitorDB.HistoryRetentionDays = 3
    
    -- 添加一条旧记录（4天前）
    local oldRecord = {
        time = os.time() - (4 * 86400),
        timeStr = "12:00:00",
        name = "OldPlayer",
        msg = "Old message",
        channelName = "[综合]",
        r = 1,
        g = 1,
        b = 1
    }
    KM:AddToHistory(oldRecord)
    
    -- 添加一条新记录（触发清理）
    local newRecord = {
        time = os.time(),
        timeStr = "12:00:00",
        name = "NewPlayer",
        msg = "New message",
        channelName = "[综合]",
        r = 1,
        g = 1,
        b = 1
    }
    KM:AddToHistory(newRecord)
    
    history = KM:GetHistory()
    if #history == 1 and history[1].name == "NewPlayer" then
        print("✓ 历史记录保留天数限制正常，旧记录已清理")
    else
        print("❌ 历史记录保留天数限制失败")
        return false
    end
    
    -- 测试 12: 测试 UI 函数
    print("\n测试 12: 测试 UI 函数...")
    local uiSuccess, uiErr = pcall(function()
        KM:ShowHistoryUI()
    end)
    
    if uiSuccess then
        print("✓ ShowHistoryUI 函数执行成功")
        if KM.historyFrame then
            print("✓ 历史记录界面已创建")
        else
            print("❌ 历史记录界面未创建")
            return false
        end
    else
        print("❌ ShowHistoryUI 函数执行失败: " .. tostring(uiErr))
        return false
    end
    
    -- 测试 13: 测试 RefreshHistoryList 函数
    print("\n测试 13: 测试 RefreshHistoryList 函数...")
    local refreshSuccess, refreshErr = pcall(function()
        KM:RefreshHistoryList()
    end)
    
    if refreshSuccess then
        print("✓ RefreshHistoryList 函数执行成功")
    else
        print("❌ RefreshHistoryList 函数执行失败: " .. tostring(refreshErr))
        return false
    end
    
    -- 测试 14: 测试 ShowEditCopyDialog 函数
    print("\n测试 14: 测试 ShowEditCopyDialog 函数...")
    local dialogSuccess, dialogErr = pcall(function()
        KM:ShowEditCopyDialog(newRecord)
    end)
    
    if dialogSuccess then
        print("✓ ShowEditCopyDialog 函数执行成功")
        if KM.editCopyDialog then
            print("✓ 编辑复制对话框已创建")
        else
            print("❌ 编辑复制对话框未创建")
            return false
        end
    else
        print("❌ ShowEditCopyDialog 函数执行失败: " .. tostring(dialogErr))
        return false
    end
    
    print("\n========================================")
    print("✓ 所有测试通过！")
    print("========================================\n")
    
    return true
end

-- 执行测试
local success = runTests()
os.exit(success and 0 or 1)

--[[
    KeywordMonitor - History Module
    历史记录管理模块
    
    职责：
    - 提供历史记录的添加、查询、清空功能
    - 管理历史记录的存储和限制
    - 提供历史记录搜索功能
    - 提供历史记录界面显示和管理
    - 自动合并重复消息
    - 限制历史记录数量和保留天数
    
    依赖：Utils 模块、Config 模块
    
    公共接口：
    - AddToHistory(record) - 添加历史记录
    - GetHistory() - 获取历史记录
    - ClearHistory() - 清空历史记录
    - SearchHistory(searchText) - 搜索历史记录
    - ShowHistoryUI() - 显示历史记录界面
    - RefreshHistoryList(searchText) - 刷新历史列表
    - ShowEditCopyDialog(record) - 显示编辑复制对话框
--]]

local addonName, addon = ...

-- 确保全局命名空间存在
if not _G.KeywordMonitor then
	_G.KeywordMonitor = {}
end

-- 获取全局命名空间
local KM = _G.KeywordMonitor

-- 创建 History 模块命名空间
KM.History = {}
local History = KM.History

--[[============================================
    本地化全局函数（性能优化）
============================================]]--

local tinsert = table.insert
local tremove = table.remove
local time = time
local date = date
local sub = string.sub
local gsub = string.gsub
local find = string.find
local upper = string.upper


--[[============================================
    辅助函数
============================================]]--

-- 从 Config 模块获取配置
local function EnsureConfig()
    if KM.Config and KM.Config.EnsureConfig then
        KM.Config.EnsureConfig()
    end
end

-- 从 Utils 模块获取工具函数
local CleanText, CreateFS, CreateButton, CreateCheckBox, CreateEditBox, CreateCloseButton, CleanupUIElements

local function LoadUtilFunctions()
    if KM.Utils then
        CleanText = KM.Utils.CleanText
        CreateFS = KM.Utils.CreateFS
        CreateButton = KM.Utils.CreateButton
        CreateCheckBox = KM.Utils.CreateCheckBox
        CreateEditBox = KM.Utils.CreateEditBox
        CreateCloseButton = KM.Utils.CreateCloseButton
        CleanupUIElements = KM.Utils.CleanupUIElements
    end
end

--[[============================================
    历史记录管理函数
============================================]]--

--- 添加到历史记录
function History.AddToHistory(record)
    EnsureConfig()
    
    -- 只保存必要的字段，减少内存占用
    -- 消息内容限制在100字符以内
    local msg = record.msg
    if #msg > 100 then
        msg = sub(msg, 1, 100) .. "..."
    end
    
    -- 检查是否是重复消息（同一个人在60秒内发布的相同内容）
    local currentTime = record.time
    local isDuplicate = false
    local duplicateIndex = nil
    
    for i, existingRecord in ipairs(KeywordMonitorDB.History) do
        -- 检查是否是同一个人
        if existingRecord.name == record.name then
            -- 检查时间差是否在60秒内
            if currentTime - existingRecord.time <= 60 then
                -- 检查消息内容是否相似（去除空格和标点后比较）
                local cleanExisting = gsub(existingRecord.msg, "[%p%s]", "")
                local cleanNew = gsub(msg, "[%p%s]", "")
                
                if cleanExisting == cleanNew then
                    -- 找到重复消息
                    isDuplicate = true
                    duplicateIndex = i
                    break
                end
            end
        end
        
        -- 只检查最近的10条记录，提高性能
        if i >= 10 then break end
    end
    
    if isDuplicate and duplicateIndex then
        -- 合并频道信息
        local existingRecord = KeywordMonitorDB.History[duplicateIndex]
        
        -- 检查频道是否已经存在
        if not find(existingRecord.channelName, record.channelName, 1, true) then
            existingRecord.channelName = existingRecord.channelName .. " " .. record.channelName
        end
        
        -- 更新时间为最新的
        existingRecord.time = currentTime
        existingRecord.timeStr = record.timeStr
        
        -- 将这条记录移到最前面
        tremove(KeywordMonitorDB.History, duplicateIndex)
        tinsert(KeywordMonitorDB.History, 1, existingRecord)
    else
        -- 添加新记录
        local currentDate = date("%Y-%m-%d", currentTime)
        local simpleRecord = {
            time = record.time,
            date = currentDate,  -- 添加日期字段
            timeStr = record.timeStr,
            name = record.name,
            msg = msg,  -- 限制长度
            channelName = record.channelName,
            r = record.r or 1,  -- 保存职业颜色
            g = record.g or 1,
            b = record.b or 1,
        }
        
        -- 添加到历史记录开头
        tinsert(KeywordMonitorDB.History, 1, simpleRecord)
    end
    
    -- 清理超过3天的记录
    local retentionDays = KeywordMonitorDB.HistoryRetentionDays or 3
    local cutoffTime = currentTime - (retentionDays * 86400)
    
    for i = #KeywordMonitorDB.History, 1, -1 do
        if KeywordMonitorDB.History[i].time < cutoffTime then
            tremove(KeywordMonitorDB.History, i)
        end
    end
    
    -- 限制历史记录数量
    while #KeywordMonitorDB.History > KeywordMonitorDB.HistoryMaxCount do
        tremove(KeywordMonitorDB.History)
    end
    
    -- 如果历史记录界面已打开，实时刷新
    if KM.historyFrame and KM.historyFrame:IsShown() then
        History.RefreshHistoryList()
    end
end

--- 获取历史记录
function History.GetHistory()
    EnsureConfig()
    return KeywordMonitorDB.History or {}
end

--- 清空历史记录
function History.ClearHistory()
    EnsureConfig()
    KeywordMonitorDB.History = {}
    print("|cff00FF00[ChatKeyword]|r 历史记录已清空")
    
    -- 如果历史记录界面已打开，实时刷新
    if KM.historyFrame and KM.historyFrame:IsShown() then
        History.RefreshHistoryList()
    end
end

--- 搜索历史记录
function History.SearchHistory(searchText)
    EnsureConfig()
    if not searchText or searchText == "" then
        return KeywordMonitorDB.History
    end
    
    local results = {}
    local upperSearch = upper(searchText)
    
    for _, record in ipairs(KeywordMonitorDB.History) do
        local cleanMsg = CleanText(record.msg)
        local cleanName = upper(record.name)
        
        if find(cleanMsg, upperSearch, 1, true) or find(cleanName, upperSearch, 1, true) then
            tinsert(results, record)
        end
    end
    
    return results
end


--[[============================================
    历史记录界面函数
============================================]]--

--- 显示历史记录界面
function History.ShowHistoryUI()
    EnsureConfig()
    LoadUtilFunctions()
    
    if not KM.historyFrame then
        local frame = CreateFrame("Frame", "KeywordMonitor_HistoryUI", UIParent, "BackdropTemplate")
        frame:SetSize(700, 500)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetFrameLevel(100)
        
        if KeywordMonitorDB.UseNDuiStyle then
            frame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            frame:SetBackdropColor(0, 0, 0, 0.9)
            frame:SetBackdropBorderColor(0, 0, 0, 1)
        else
            frame:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true,
                tileSize = 32,
                edgeSize = 32,
                insets = { left = 11, right = 12, top = 12, bottom = 11 }
            })
        end
        
        frame:Hide()
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        
        local title = CreateFS(frame, 16, "历史记录", true)
        title:SetPoint("TOP", 0, -10)
        frame.title = title  -- 保存标题引用，用于更新
        
        local closeBtn = CreateCloseButton(frame)
        closeBtn:SetPoint("TOPRIGHT", -10, -10)
        closeBtn:SetScript("OnClick", function() frame:Hide() end)
        
        -- 日期筛选标签
        frame.selectedDateFilter = "all"  -- 默认显示全部
        
        local dateFilterLabel = CreateFS(frame, 12, "日期筛选:", false, "LEFT")
        dateFilterLabel:SetPoint("TOPLEFT", 20, -40)
        
        -- 创建日期筛选按钮
        local dateFilters = {
            {key = "today", label = "今天"},
            {key = "yesterday", label = "昨天"},
            {key = "recent3", label = "最近3天"},
            {key = "all", label = "全部"}
        }
        
        frame.dateFilterButtons = {}
        local xOffset = 80
        
        for _, filter in ipairs(dateFilters) do
            local btn = CreateButton(frame, 70, 25, filter.label)
            btn:SetPoint("TOPLEFT", xOffset, -35)
            
            -- 更新按钮外观
            local function UpdateButtonAppearance()
                local fontString = btn:GetFontString()
                if fontString then
                    if frame.selectedDateFilter == filter.key then
                        -- 选中状态：亮蓝色
                        fontString:SetTextColor(0.3, 0.7, 1)
                    else
                        -- 未选中状态：白色
                        fontString:SetTextColor(1, 1, 1)
                    end
                end
            end
            
            btn:SetScript("OnClick", function()
                frame.selectedDateFilter = filter.key
                -- 更新所有按钮外观
                for _, b in pairs(frame.dateFilterButtons) do
                    if b.updateAppearance then
                        b.updateAppearance()
                    end
                end
                -- 刷新列表
                History.RefreshHistoryList()
            end)
            
            btn.updateAppearance = UpdateButtonAppearance
            frame.dateFilterButtons[filter.key] = btn
            
            UpdateButtonAppearance()
            xOffset = xOffset + 75
        end
        
        -- 搜索框
        local searchLabel = CreateFS(frame, 12, "搜索:", false, "LEFT")
        searchLabel:SetPoint("TOPLEFT", 20, -70)
        
        local searchBox = CreateEditBox(frame, 200, 25)
        searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 5, 0)
        
        local searchBtn = CreateButton(frame, 60, 25, "搜索")
        searchBtn:SetPoint("LEFT", searchBox, "RIGHT", 5, 0)
        
        -- 清空按钮
        local clearBtn = CreateButton(frame, 100, 25, "清空历史")
        clearBtn:SetPoint("TOPRIGHT", -20, -70)
        clearBtn:SetScript("OnClick", function()
            History.ClearHistory()
            History.RefreshHistoryList()
        end)
        
        -- 操作提示（放在搜索框下方）
        local hintText = CreateFS(frame, 11, "提示：双击可复制消息，右键可快速回复", false, "LEFT")
        hintText:SetPoint("TOPLEFT", 20, -100)
        hintText:SetTextColor(1, 0.8, 0)  -- 使用黄色更醒目
        
        -- 历史记录列表
        local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 20, -125)  -- 调整顶部位置，为日期筛选和提示文字留出空间
        scrollFrame:SetPoint("BOTTOMRIGHT", -40, 20)
        
        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetSize(640, 1)
        scrollFrame:SetScrollChild(scrollChild)
        frame.scrollChild = scrollChild
        
        -- 搜索按钮事件
        searchBtn:SetScript("OnClick", function()
            History.RefreshHistoryList(searchBox:GetText())
        end)
        
        searchBox:SetScript("OnEnterPressed", function(self)
            History.RefreshHistoryList(self:GetText())
        end)
        
        frame:SetScript("OnShow", function()
            History.RefreshHistoryList()
        end)
        
        KM.historyFrame = frame
    end
    
    if KM.historyFrame:IsShown() then
        KM.historyFrame:Hide()
    else
        KM.historyFrame:Show()
    end
end


--- 刷新历史记录列表
function History.RefreshHistoryList(searchText)
    local frame = KM.historyFrame
    if not frame then return end
    
    -- 更新标题显示条数
    local currentCount = #KeywordMonitorDB.History
    local maxCount = KeywordMonitorDB.HistoryMaxCount
    if frame.title then
        frame.title:SetText(string.format("历史记录 (%d/%d)", currentCount, maxCount))
    end
    
    -- 使用保存在frame上的scrollChild
    local scrollChild = frame.scrollChild
    if not scrollChild then
        print("|cffFF0000[ChatKeyword]|r 刷新失败: scrollChild不存在")
        return
    end
    
    -- 确保records表存在
    if not scrollChild.records then
        scrollChild.records = {}
    end
    
    CleanupUIElements(scrollChild.records)
    scrollChild.records = {}
    
    -- 获取历史记录
    local history = searchText and History.SearchHistory(searchText) or History.GetHistory()
    
    -- 根据日期筛选过滤
    local dateFilter = frame.selectedDateFilter or "all"
    if dateFilter ~= "all" then
        local now = time()
        -- 获取今天0点的时间戳（使用date函数获取本地时间）
        local dateTable = date("*t", now)
        local todayStart = time({
            year = dateTable.year,
            month = dateTable.month,
            day = dateTable.day,
            hour = 0,
            min = 0,
            sec = 0
        })
        local yesterdayStart = todayStart - 86400  -- 昨天0点
        local recent3Start = todayStart - (86400 * 2)  -- 3天前0点
        
        local filtered = {}
        for _, record in ipairs(history) do
            local recordTime = record.time or 0  -- 使用time字段（时间戳）
            local include = false
            
            if dateFilter == "today" then
                include = recordTime >= todayStart
            elseif dateFilter == "yesterday" then
                include = recordTime >= yesterdayStart and recordTime < todayStart
            elseif dateFilter == "recent3" then
                include = recordTime >= recent3Start
            end
            
            if include then
                tinsert(filtered, record)
            end
        end
        
        history = filtered
    end
    
    local yOffset = -5
    for i, record in ipairs(history) do
        local recordFrame = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
        recordFrame:SetSize(620, 60)
        recordFrame:SetPoint("TOPLEFT", 5, yOffset)
        
        if KeywordMonitorDB.UseNDuiStyle then
            recordFrame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            recordFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
            recordFrame:SetBackdropBorderColor(0, 0, 0, 1)
        else
            recordFrame:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true,
                tileSize = 16,
                edgeSize = 12,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            recordFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
        end
        
        recordFrame:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
        end)
        recordFrame:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
        end)
        
        -- 时间和频道
        local timeText = CreateFS(recordFrame, 11, record.timeStr .. " " .. record.channelName, false, "LEFT")
        timeText:SetPoint("TOPLEFT", 5, -5)
        timeText:SetTextColor(0.7, 0.7, 0.7)
        
        -- 玩家名（使用职业颜色）
        local nameText = CreateFS(recordFrame, 12, record.name, false, "LEFT")
        nameText:SetPoint("TOPLEFT", 5, -20)
        nameText:SetTextColor(record.r or 1, record.g or 1, record.b or 1)
        
        -- 消息内容（也使用职业颜色）
        local msgText = CreateFS(recordFrame, 11, record.msg, false, "LEFT")
        msgText:SetPoint("TOPLEFT", 5, -35)
        msgText:SetPoint("RIGHT", -5, 0)
        msgText:SetWordWrap(false)
        msgText:SetTextColor(record.r or 1, record.g or 1, record.b or 1)  -- 使用职业颜色
        
        -- 注册左键和右键点击
        recordFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        
        -- 双击计时器
        local lastClickTime = 0
        
        -- 点击事件
        recordFrame:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                -- 左键：双击打开编辑复制对话框
                local currentTime = GetTime()
                
                if currentTime - lastClickTime < 0.3 then
                    -- 双击：显示编辑复制界面
                    History.ShowEditCopyDialog(record)
                    lastClickTime = 0  -- 重置
                else
                    -- 单击：记录时间，等待可能的第二次点击
                    lastClickTime = currentTime
                end
            elseif button == "RightButton" then
                -- 右键：显示快速回复菜单
                if KM.QuickReply and KM.QuickReply.ShowQuickReplyForPlayer then
                    KM.QuickReply.ShowQuickReplyForPlayer(record.author or record.name)
                end
            end
        end)
        
        tinsert(scrollChild.records, recordFrame)
        yOffset = yOffset - 65
    end
    
    scrollChild:SetHeight(math.max(1, -yOffset))
end


--- 显示编辑复制对话框
function History.ShowEditCopyDialog(record)
    LoadUtilFunctions()
    
    -- 创建或复用对话框
    if not KM.editCopyDialog then
        local dialog = CreateFrame("Frame", "KeywordMonitor_EditCopyDialog", UIParent, "BackdropTemplate")
        dialog:SetSize(500, 250)
        dialog:SetPoint("CENTER")
        dialog:SetFrameStrata("FULLSCREEN_DIALOG")
        dialog:SetFrameLevel(200)
        
        if KeywordMonitorDB.UseNDuiStyle then
            dialog:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            dialog:SetBackdropColor(0, 0, 0, 0.95)
            dialog:SetBackdropBorderColor(0, 0, 0, 1)
        else
            dialog:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true,
                tileSize = 32,
                edgeSize = 32,
                insets = { left = 11, right = 12, top = 12, bottom = 11 }
            })
        end
        
        dialog:Hide()
        dialog:SetMovable(true)
        dialog:EnableMouse(true)
        dialog:RegisterForDrag("LeftButton")
        dialog:SetScript("OnDragStart", dialog.StartMoving)
        dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
        
        local title = CreateFS(dialog, 14, "消息详情", true)
        title:SetPoint("TOP", 0, -10)
        
        local closeBtn = CreateCloseButton(dialog)
        closeBtn:SetPoint("TOPRIGHT", -10, -10)
        closeBtn:SetScript("OnClick", function() dialog:Hide() end)
        
        -- 玩家名标签
        local nameLabel = CreateFS(dialog, 12, "玩家:", false, "LEFT")
        nameLabel:SetPoint("TOPLEFT", 20, -40)
        
        local nameText = CreateFS(dialog, 12, "", false, "LEFT")
        nameText:SetPoint("LEFT", nameLabel, "RIGHT", 5, 0)
        dialog.nameText = nameText
        
        -- 时间和频道标签
        local infoLabel = CreateFS(dialog, 11, "", false, "LEFT")
        infoLabel:SetPoint("TOPLEFT", 20, -60)
        infoLabel:SetTextColor(0.7, 0.7, 0.7)
        dialog.infoLabel = infoLabel
        
        -- 消息内容编辑框
        local msgLabel = CreateFS(dialog, 12, "消息内容:", false, "LEFT")
        msgLabel:SetPoint("TOPLEFT", 20, -85)
        
        local scrollFrame = CreateFrame("ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 20, -105)
        scrollFrame:SetPoint("BOTTOMRIGHT", -40, 50)
        
        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject(ChatFontNormal)
        editBox:SetWidth(440)
        editBox:SetMaxLetters(0)
        scrollFrame:SetScrollChild(editBox)
        dialog.editBox = editBox
        
        -- 全选按钮
        local selectAllBtn = CreateButton(dialog, 80, 25, "全选")
        selectAllBtn:SetPoint("BOTTOMLEFT", 20, 15)
        selectAllBtn:SetScript("OnClick", function()
            editBox:SetFocus()
            editBox:HighlightText()
        end)
        
        -- 复制按钮（提示用户使用Ctrl+C）
        local copyBtn = CreateButton(dialog, 120, 25, "复制 (Ctrl+C)")
        copyBtn:SetPoint("LEFT", selectAllBtn, "RIGHT", 10, 0)
        copyBtn:SetScript("OnClick", function()
            editBox:SetFocus()
            editBox:HighlightText()
            print("|cff00FF00[ChatKeyword]|r 已全选，请按 Ctrl+C 复制")
        end)
        
        -- 关闭按钮
        local okBtn = CreateButton(dialog, 80, 25, "关闭")
        okBtn:SetPoint("BOTTOMRIGHT", -20, 15)
        okBtn:SetScript("OnClick", function() dialog:Hide() end)
        
        KM.editCopyDialog = dialog
    end
    
    -- 更新对话框内容
    local dialog = KM.editCopyDialog
    dialog.nameText:SetText(record.name)
    dialog.nameText:SetTextColor(record.r or 1, record.g or 1, record.b or 1)
    dialog.infoLabel:SetText(record.timeStr .. " " .. record.channelName)
    dialog.editBox:SetText(record.msg)
    dialog.editBox:SetCursorPosition(0)
    
    dialog:Show()
end

--[[============================================
    模块初始化
============================================]]--

-- 模块加载完成标记
KM.History.Loaded = true

-- 调试信息
if KM.Debug then
    print("|cff00ff00KeywordMonitor:|r History 模块已加载")
end

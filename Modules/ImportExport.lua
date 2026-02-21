--[[
    KeywordMonitor - ImportExport Module
    配置导入导出模块
    
    职责：
    - 提供配置的导入和导出功能
    - 支持数据序列化和反序列化
    - 提供 Base64 编码和解码
    - 提供导入导出界面显示和管理
    - 支持配置的跨账号/跨服务器共享
    
    依赖：Utils 模块、Config 模块
    
    公共接口：
    - ShowExportUI() - 显示导出界面
    - ShowImportUI() - 显示导入界面
    - ExportConfig() - 导出配置
    - ImportConfig(data) - 导入配置
    - Serialize(data) - 序列化数据
    - Deserialize(str) - 反序列化数据
    - Base64Encode(str) - Base64 编码
    - Base64Decode(str) - Base64 解码
--]]

local addonName, addon = ...

-- 确保全局命名空间存在
if not _G.KeywordMonitor then
	_G.KeywordMonitor = {}
end

-- 获取全局命名空间
local KM = _G.KeywordMonitor

-- 创建 ImportExport 模块命名空间
KM.ImportExport = {}
local ImportExport = KM.ImportExport

--[[============================================
    本地化全局函数（性能优化）
============================================]]--

local tinsert = table.insert
local tremove = table.remove
local pairs = pairs
local ipairs = ipairs
local type = type
local tostring = tostring
local tonumber = tonumber
local string = string
local math = math
local CreateFrame = CreateFrame
local UIParent = UIParent
local ChatFontNormal = ChatFontNormal

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
local CreateFS, CreateButton, CreateEditBox, CreateCloseButton, CleanupUIElements

local function LoadUtilFunctions()
    if KM.Utils then
        CreateFS = KM.Utils.CreateFS
        CreateButton = KM.Utils.CreateButton
        CreateEditBox = KM.Utils.CreateEditBox
        CreateCloseButton = KM.Utils.CreateCloseButton
        CleanupUIElements = KM.Utils.CleanupUIElements
    end
end

--[[============================================
    Base64 编码/解码
============================================]]--

-- Base64 字符表
local base64Chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

--- Base64 编码
-- @param data string 要编码的字符串
-- @return string Base64 编码后的字符串
function KM:Base64Encode(data)
    local result = {}
    local padding = ""
    
    for i = 1, #data, 3 do
        local a, b, c = string.byte(data, i, i + 2)
        b = b or 0
        c = c or 0
        
        local n = a * 65536 + b * 256 + c
        
        local c1 = math.floor(n / 262144) % 64 + 1
        local c2 = math.floor(n / 4096) % 64 + 1
        local c3 = math.floor(n / 64) % 64 + 1
        local c4 = n % 64 + 1
        
        tinsert(result, string.sub(base64Chars, c1, c1))
        tinsert(result, string.sub(base64Chars, c2, c2))
        tinsert(result, i + 1 <= #data and string.sub(base64Chars, c3, c3) or "=")
        tinsert(result, i + 2 <= #data and string.sub(base64Chars, c4, c4) or "=")
    end
    
    return table.concat(result)
end

--- Base64 解码
-- @param data string Base64 编码的字符串
-- @return string 解码后的字符串
function KM:Base64Decode(data)
    data = string.gsub(data, "[^" .. base64Chars .. "=]", "")
    
    local result = {}
    
    for i = 1, #data, 4 do
        local a, b, c, d = string.byte(data, i, i + 3)
        
        local function charToNum(char)
            if char == 61 then return 0 end  -- '='
            local pos = string.find(base64Chars, string.char(char))
            return pos and (pos - 1) or 0
        end
        
        local n1 = charToNum(a)
        local n2 = charToNum(b)
        local n3 = charToNum(c)
        local n4 = charToNum(d)
        
        local n = n1 * 262144 + n2 * 4096 + n3 * 64 + n4
        
        tinsert(result, string.char(math.floor(n / 65536) % 256))
        if c ~= 61 then
            tinsert(result, string.char(math.floor(n / 256) % 256))
        end
        if d ~= 61 then
            tinsert(result, string.char(n % 256))
        end
    end
    
    return table.concat(result)
end

--[[============================================
    序列化/反序列化
============================================]]--

--- 序列化数据
-- @param data table 要序列化的数据表
-- @return string 序列化后的字符串
function KM:Serialize(data)
    local function serializeValue(v)
        local t = type(v)
        if t == "string" then
            return string.format("%q", v)
        elseif t == "number" then
            return tostring(v)
        elseif t == "boolean" then
            return v and "true" or "false"
        elseif t == "table" then
            local parts = {}
            tinsert(parts, "{")
            for k, val in pairs(v) do
                local key = type(k) == "string" and string.format("[%q]", k) or string.format("[%d]", k)
                tinsert(parts, key .. "=" .. serializeValue(val) .. ",")
            end
            tinsert(parts, "}")
            return table.concat(parts)
        else
            return "nil"
        end
    end
    
    return "return " .. serializeValue(data)
end

--- 反序列化数据
-- @param str string 序列化的字符串
-- @return table|nil 反序列化后的数据表，失败返回 nil
function KM:Deserialize(str)
    if not str or str == "" then return nil end
    
    local func, err = loadstring(str)
    if not func then
        return nil
    end
    
    local success, result = pcall(func)
    if not success then
        return nil
    end
    
    return result
end

--[[============================================
    配置导入导出
============================================]]--

--- 导出配置
-- @return string 导出的配置字符串（Base64 编码）
function KM:ExportConfig()
    EnsureConfig()
    
    -- 准备导出数据
    local exportData = {
        version = "1.5.0",
        keywords = KeywordMonitorDB.Keywords,
        groups = KeywordMonitorDB.KeywordGroups,
        useGroups = KeywordMonitorDB.UseKeywordGroups,
        quickReplies = KeywordMonitorDB.QuickReplies,
        channels = KeywordMonitorDB.Channels,
    }
    
    -- 序列化为字符串
    local serialized = KM:Serialize(exportData)
    
    -- Base64编码
    local encoded = KM:Base64Encode(serialized)
    
    return encoded
end

--- 导入配置
-- @param encodedData string 导入的配置字符串（Base64 编码）
-- @return boolean 导入是否成功
function KM:ImportConfig(encodedData)
    EnsureConfig()
    
    if not encodedData or encodedData == "" then
        print("|cff00FF00[ChatKeyword]|r 导入数据为空")
        return false
    end
    
    -- Base64解码
    local decoded = KM:Base64Decode(encodedData)
    if not decoded then
        print("|cff00FF00[ChatKeyword]|r 导入失败：数据格式错误")
        return false
    end
    
    -- 反序列化
    local importData = KM:Deserialize(decoded)
    if not importData then
        print("|cff00FF00[ChatKeyword]|r 导入失败：数据解析错误")
        return false
    end
    
    -- 应用导入的配置
    if importData.keywords then
        KeywordMonitorDB.Keywords = importData.keywords
    end
    
    if importData.groups then
        KeywordMonitorDB.KeywordGroups = importData.groups
    end
    
    if importData.useGroups ~= nil then
        KeywordMonitorDB.UseKeywordGroups = importData.useGroups
    end
    
    if importData.quickReplies then
        KeywordMonitorDB.QuickReplies = importData.quickReplies
    end
    
    if importData.channels then
        KeywordMonitorDB.Channels = importData.channels
    end
    
    -- 更新关键词列表
    if KM.UpdateKeywordList then
        KM:UpdateKeywordList()
    end
    
    print("|cff00FF00[ChatKeyword]|r 配置导入成功")
    return true
end

--[[============================================
    用户界面
============================================]]--

--- 显示导出界面
function KM:ShowExportUI()
    EnsureConfig()
    LoadUtilFunctions()
    
    if not self.exportFrame then
        local frame = CreateFrame("Frame", "KeywordMonitor_ExportUI", UIParent, "BackdropTemplate")
        frame:SetSize(500, 300)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetFrameLevel(110)
        
        if KeywordMonitorDB.UseNDuiStyle then
            frame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            frame:SetBackdropColor(0, 0, 0, 0.95)
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
        
        local title = CreateFS(frame, 16, "导出配置", true)
        title:SetPoint("TOP", 0, -10)
        
        local closeBtn = CreateCloseButton(frame)
        closeBtn:SetPoint("TOPRIGHT", -10, -10)
        closeBtn:SetScript("OnClick", function() frame:Hide() end)
        
        local desc = CreateFS(frame, 11, "复制下方文本，保存到安全的地方", false, "LEFT")
        desc:SetPoint("TOPLEFT", 20, -40)
        desc:SetTextColor(0.7, 0.7, 0.7)
        
        -- 导出文本框
        local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 20, -65)
        scrollFrame:SetPoint("BOTTOMRIGHT", -40, 50)
        
        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject(ChatFontNormal)
        editBox:SetWidth(440)
        scrollFrame:SetScrollChild(editBox)
        frame.editBox = editBox
        
        -- 全选按钮
        local selectAllBtn = CreateButton(frame, 100, 25, "全选")
        selectAllBtn:SetPoint("BOTTOM", 0, 15)
        selectAllBtn:SetScript("OnClick", function()
            editBox:HighlightText()
            editBox:SetFocus()
        end)
        
        frame:SetScript("OnShow", function()
            local exported = KM:ExportConfig()
            editBox:SetText(exported)
            editBox:SetCursorPosition(0)
        end)
        
        self.exportFrame = frame
    end
    
    if self.exportFrame:IsShown() then
        self.exportFrame:Hide()
    else
        self.exportFrame:Show()
    end
end

--- 显示导入界面
function KM:ShowImportUI()
	EnsureConfig()
	LoadUtilFunctions()
	
	if not self.importFrame then
		local frame = CreateFrame("Frame", "KeywordMonitor_ImportUI", UIParent, "BackdropTemplate")
		frame:SetSize(500, 300)
		frame:SetPoint("CENTER")
		frame:SetFrameStrata("DIALOG")
		frame:SetFrameLevel(110)
		
		if KeywordMonitorDB.UseNDuiStyle then
			frame:SetBackdrop({
				bgFile = "Interface\\Buttons\\WHITE8X8",
				edgeFile = "Interface\\Buttons\\WHITE8X8",
				edgeSize = 1,
			})
			frame:SetBackdropColor(0, 0, 0, 0.95)
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
		
		local title = CreateFS(frame, 16, "导入配置", true)
		title:SetPoint("TOP", 0, -10)
		
		local closeBtn = CreateCloseButton(frame)
		closeBtn:SetPoint("TOPRIGHT", -10, -10)
		closeBtn:SetScript("OnClick", function() frame:Hide() end)
		
		local desc = CreateFS(frame, 11, "粘贴导出的配置文本到下方", false, "LEFT")
		desc:SetPoint("TOPLEFT", 20, -40)
		desc:SetTextColor(0.7, 0.7, 0.7)
		
		local warning = CreateFS(frame, 10, "警告：导入将覆盖当前配置", false, "LEFT")
		warning:SetPoint("TOPLEFT", 20, -55)
		warning:SetTextColor(1, 0, 0)
		
		-- 导入文本框
		local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
		scrollFrame:SetPoint("TOPLEFT", 20, -75)
		scrollFrame:SetPoint("BOTTOMRIGHT", -40, 50)
		
		local editBox = CreateFrame("EditBox", nil, scrollFrame)
		editBox:SetMultiLine(true)
		editBox:SetAutoFocus(false)
		editBox:SetFontObject(ChatFontNormal)
		editBox:SetWidth(440)
		scrollFrame:SetScrollChild(editBox)
		frame.editBox = editBox
		
		-- 导入按钮
		local importBtn = CreateButton(frame, 100, 25, "导入")
		importBtn:SetPoint("BOTTOM", 0, 15)
		importBtn:SetScript("OnClick", function()
			local text = editBox:GetText()
			if KM:ImportConfig(text) then
				frame:Hide()
				-- 刷新界面
				if self.groupsFrame then
					self.groupsFrame:Hide()
					C_Timer.After(0.1, function()
						self.groupsFrame:Show()
					end)
				end
			end
		end)
		
		frame:SetScript("OnShow", function()
			editBox:SetText("")
			editBox:SetFocus()
		end)
		
		self.importFrame = frame
	end
	
	if self.importFrame:IsShown() then
		self.importFrame:Hide()
	else
		self.importFrame:Show()
	end
end

--[[============================================
    模块初始化
============================================]]--

-- 模块加载完成标记
KM.ImportExport.Loaded = true

-- 调试信息
if KM.Debug then
    print("|cff00ff00KeywordMonitor:|r ImportExport 模块已加载")
end

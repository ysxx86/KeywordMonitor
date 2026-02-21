--[[
    KeywordMonitor - Utils Module
    工具函数模块
    
    职责：
    - 提供通用工具函数供其他模块使用
    - 提供 UI 辅助函数（按钮、复选框、编辑框等）
    - 提供文本处理函数（清理、分割等）
    - 本地化全局函数引用以优化性能
    
    依赖：无（基础模块，最先加载）
    
    公共接口：
    - CleanText(text) - 清理文本中的特殊字符
    - SplitString(str, delimiter) - 分割字符串
    - CreateBD(frame) - 创建背景
    - CreateFS(parent, size, text, justify) - 创建字体字符串
    - CreateButton(parent, width, height, text) - 创建按钮
    - CreateCheckBox(parent, text) - 创建复选框
    - CreateEditBox(parent, width, height) - 创建编辑框
    - CreateCloseButton(parent) - 创建关闭按钮
    - CleanupUIElements(elements) - 清理 UI 元素
--]]

local addonName, addon = ...

-- 确保全局命名空间存在
if not _G.KeywordMonitor then
	_G.KeywordMonitor = {}
end

-- 获取全局命名空间（不使用 local 变量）
local KM = _G.KeywordMonitor

-- 创建 Utils 模块命名空间
KM.Utils = {}
local Utils = KM.Utils

--[[============================================
    本地化全局函数引用（性能优化）
    将常用的全局函数缓存到本地变量，减少全局查找开销
============================================]]--

-- 基础 Lua 函数
local _G = _G
local type, pairs, ipairs, next = type, pairs, ipairs, next
local tonumber, tostring = tonumber, tostring
local pcall = pcall
local loadstring = loadstring
local collectgarbage = collectgarbage

-- 表操作函数
local tinsert, tremove, wipe, sort = table.insert, table.remove, wipe or table.wipe, table.sort

-- 字符串操作函数
local gsub, match, upper, strsplit, strlower, gmatch, find, sub, format = string.gsub, string.match, string.upper, strsplit, string.lower, string.gmatch, string.find, string.sub, string.format

-- 数学函数
local math_floor, math_max, math_min, math_huge, math_random = math.floor, math.max, math.min, math.huge, math.random

-- 时间相关函数
local GetServerTime, date, GetTime, time = GetServerTime, date, GetTime, time

-- 战斗和音效函数
local InCombatLockdown, PlaySound = InCombatLockdown, PlaySound
local PlaySoundFile = PlaySoundFile
local SOUNDKIT = SOUNDKIT

-- 玩家和单位函数
local Ambiguate, IsShiftKeyDown, UnitName = Ambiguate, IsShiftKeyDown, UnitName
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local GetColoredName, GetPlayerLink = GetColoredName, GetPlayerLink

-- C_API 函数
local C_Timer, C_FriendList, C_BattleNet = C_Timer, C_FriendList, C_BattleNet

-- 战网好友函数
local BNGetNumFriends, BNGetFriendInfoByID = BNGetNumFriends, BNGetFriendInfoByID
local BNET_CLIENT_WOW = BNET_CLIENT_WOW

-- UI 框架函数
local CreateFrame = CreateFrame
local UIParent = UIParent
local GameTooltip = GameTooltip

-- 聊天框架函数
local ChatEdit_ChooseBoxForSend = ChatEdit_ChooseBoxForSend
local ChatEdit_SendText = ChatEdit_SendText
local ChatFrame_SendTell = ChatFrame_SendTell
local ChatFrame_ReplaceIconAndGroupExpressions = C_ChatInfo and C_ChatInfo.ReplaceIconAndGroupExpressions or ChatFrame_ReplaceIconAndGroupExpressions
local ChatFrame_CanChatGroupPerformExpressionExpansion = ChatFrame_CanChatGroupPerformExpressionExpansion
local FCF_StartAlertFlash = FCF_StartAlertFlash
local GeneralDockManager = GeneralDockManager
local GetChatWindowInfo = GetChatWindowInfo
local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS

-- 插件内存函数
local UpdateAddOnMemoryUsage = UpdateAddOnMemoryUsage
local GetAddOnMemoryUsage = GetAddOnMemoryUsage

-- 常量
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local STANDARD_TEXT_FONT = STANDARD_TEXT_FONT

--[[============================================
    文本处理函数
============================================]]--

-- 清理文本中的特殊字符（优化版 - 减少gsub调用）
-- @param text string 要清理的文本
-- @return string 清理后的文本（大写，移除颜色代码、链接、标点和空格）
function Utils.CleanText(text)
	if not text then return "" end
	-- 合并多个gsub操作，减少字符串创建
	text = gsub(text, "|[HhTtCcRr][^|]*|[hHtT]", "")  -- 移除所有颜色和链接代码
	text = gsub(text, "[%p%s]", "")  -- 移除标点和空格
	return upper(text)
end

-- 分割字符串
-- @param str string 要分割的字符串
-- @param delimiter string 分隔符
-- @return table 分割后的字符串数组
function Utils.SplitString(str, delimiter)
	local result = {}
	if not str or str == "" then return result end
	
	str = gsub(str, "，", ",")
	for word in gmatch(str, "[^"..delimiter.."]+") do
		word = gsub(word, "^%s*(.-)%s*$", "%1")
		if word ~= "" then
			tinsert(result, word)
		end
	end
	return result
end

--[[============================================
    UI 辅助函数
============================================]]--

-- 创建背景
-- @param frame Frame 要添加背景的框架
-- @param alpha number 背景透明度（可选，默认 0.7）
function Utils.CreateBD(frame, alpha)
	-- 检查是否启用 NDui 美化风格
	local useNDui = KeywordMonitorDB and KeywordMonitorDB.UseNDuiStyle
	
	if useNDui then
		-- 使用 NDui 风格的简洁边框
		if not frame.SetBackdrop then return end
		frame:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Buttons\\WHITE8X8",
			edgeSize = 1,
		})
		frame:SetBackdropColor(0, 0, 0, alpha or 0.7)
		frame:SetBackdropBorderColor(0, 0, 0, 1)
	else
		-- 使用暴雪原生UI背景
		if not frame.SetBackdrop then return end
		frame:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = false,
			tileSize = 16,
			edgeSize = 12,
			insets = { left = 2, right = 2, top = 2, bottom = 2 }
		})
		frame:SetBackdropColor(0, 0, 0, alpha or 0.7)
		frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
	end
end

-- 创建字体字符串
-- @param frame Frame 父框架
-- @param size number 字体大小
-- @param text string 文本内容
-- @param bold boolean 是否加粗（可选）
-- @param justify string 对齐方式（可选）
-- @return FontString 创建的字体字符串
function Utils.CreateFS(frame, size, text, bold, justify)
	local fs = frame:CreateFontString(nil, "OVERLAY")
	fs:SetFont(STANDARD_TEXT_FONT, size, bold and "OUTLINE" or "")
	fs:SetText(text or "")
	if justify then
		fs:SetJustifyH(justify)
	end
	return fs
end

-- 创建按钮
-- @param parent Frame 父框架
-- @param width number 按钮宽度
-- @param height number 按钮高度
-- @param text string 按钮文本
-- @return Button 创建的按钮
function Utils.CreateButton(parent, width, height, text)
	local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	btn:SetSize(width, height)
	btn:SetText(text or "")
	return btn
end

-- 创建复选框
-- @param parent Frame 父框架
-- @return CheckButton 创建的复选框
function Utils.CreateCheckBox(parent)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	cb:SetSize(24, 24)
	return cb
end

-- 创建编辑框
-- @param parent Frame 父框架
-- @param width number 编辑框宽度
-- @param height number 编辑框高度
-- @return EditBox 创建的编辑框
function Utils.CreateEditBox(parent, width, height)
	local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	eb:SetSize(width, height)
	eb:SetAutoFocus(false)
	return eb
end

-- 创建关闭按钮
-- @param parent Frame 父框架
-- @return Button 创建的关闭按钮
function Utils.CreateCloseButton(parent)
	local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	btn:SetSize(28, 28)  -- 正方形，稍微大一点
	btn:SetText("×")  -- 使用更美观的乘号符号
	
	-- 设置字体更大更清晰
	local text = btn:GetFontString()
	if text then
		text:SetFont(STANDARD_TEXT_FONT, 18, "OUTLINE")
	end
	
	return btn
end

--[[============================================
    UI 清理函数
============================================]]--

-- 清理 UI 元素（防止内存泄漏 - 使用wipe优化）
-- @param elements table UI 元素数组
function Utils.CleanupUIElements(elements)
	if not elements then return end
	for i = #elements, 1, -1 do
		local element = elements[i]
		if element then
			-- 安全地清理所有SetScript（使用pcall避免错误）
			if element.SetScript then
				pcall(function() element:SetScript("OnClick", nil) end)
				pcall(function() element:SetScript("OnEnter", nil) end)
				pcall(function() element:SetScript("OnLeave", nil) end)
				pcall(function() element:SetScript("OnTextChanged", nil) end)
				pcall(function() element:SetScript("OnShow", nil) end)
				pcall(function() element:SetScript("OnHide", nil) end)
				pcall(function() element:SetScript("OnEnterPressed", nil) end)
				pcall(function() element:SetScript("OnEditFocusLost", nil) end)
			end
			-- 隐藏并移除
			if element.Hide then element:Hide() end
			if element.SetParent then element:SetParent(nil) end
			if element.ClearAllPoints then element:ClearAllPoints() end
		end
	end
	-- 使用 wipe 清空表而不是创建新表
	wipe(elements)
end

--[[============================================
    模块初始化
============================================]]--

-- 模块加载完成标记
KM.Utils.Loaded = true

-- 调试信息
if KM.Debug then
    print("|cff00ff00KeywordMonitor:|r Utils 模块已加载")
end

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

-- NDui 材质路径
local Media = "Interface\\Addons\\KeywordMonitor\\Media\\"
local bdTex = "Interface\\ChatFrame\\ChatFrameBackground"
local glowTex = Media.."glowTex"
local normTex = Media.."normTex"
local bgTex = Media.."bgTex"
local mult = 1  -- 边框倍数

-- SetOutside 辅助函数
local function SetOutside(frame, anchor, xOffset, yOffset, anchor2)
	xOffset = xOffset or 1
	yOffset = yOffset or 1
	anchor = anchor or frame:GetParent()

	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", -xOffset, yOffset)
	frame:SetPoint("BOTTOMRIGHT", anchor2 or anchor, "BOTTOMRIGHT", xOffset, -yOffset)
end

-- SetInside 辅助函数
local function SetInside(frame, anchor, xOffset, yOffset, anchor2)
	xOffset = xOffset or 1
	yOffset = yOffset or 1
	anchor = anchor or frame:GetParent()

	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", xOffset, -yOffset)
	frame:SetPoint("BOTTOMRIGHT", anchor2 or anchor, "BOTTOMRIGHT", -xOffset, yOffset)
end

-- 创建背景纹理
local function CreateTex(frame)
	if frame.__bgTex then return end

	local parent = frame
	if frame:IsObjectType("Texture") then parent = frame:GetParent() end

	local tex = parent:CreateTexture(nil, "BACKGROUND", nil, 1)
	tex:SetAllPoints(frame)
	tex:SetTexture(bgTex, true, true)
	tex:SetHorizTile(true)
	tex:SetVertTile(true)
	tex:SetBlendMode("ADD")

	frame.__bgTex = tex
end

-- 创建阴影
local shadowBackdrop = {edgeFile = glowTex}

local function CreateSD(frame, size, override)
	if frame.__shadow then return end

	local parent = frame
	if frame:IsObjectType("Texture") then parent = frame:GetParent() end

	shadowBackdrop.edgeSize = size or 5
	frame.__shadow = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	SetOutside(frame.__shadow, frame, size or 4, size or 4)
	frame.__shadow:SetBackdrop(shadowBackdrop)
	frame.__shadow:SetBackdropBorderColor(0, 0, 0, size and 1 or .4)
	frame.__shadow:SetFrameLevel(1)

	return frame.__shadow
end

-- 创建基础背景
local defaultBackdrop = {bgFile = bdTex, edgeFile = bdTex}

local function CreateBD(frame, alpha)
	defaultBackdrop.edgeSize = mult
	frame:SetBackdrop(defaultBackdrop)
	frame:SetBackdropColor(0, 0, 0, alpha or 0.7)
	frame:SetBackdropBorderColor(0, 0, 0, 1)
end

-- 创建背景框架
local function CreateBDFrame(frame, alpha, gradient)
	local parent = frame
	if frame:IsObjectType("Texture") then parent = frame:GetParent() end
	local lvl = parent:GetFrameLevel()

	local bg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	SetOutside(bg, frame)
	bg:SetFrameLevel(lvl == 0 and 0 or lvl - 1)
	CreateBD(bg, alpha)

	return bg
end

-- 设置背景（完整版）
local function SetBD(frame, alpha, x, y, x2, y2)
	local bg = CreateBDFrame(frame, alpha)
	if x then
		bg:ClearAllPoints()
		bg:SetPoint("TOPLEFT", frame, x, y)
		bg:SetPoint("BOTTOMRIGHT", frame, x2, y2)
	end
	CreateSD(bg)
	CreateTex(bg)

	return bg
end

-- 公共接口：创建背景
-- @param frame Frame 要添加背景的框架
-- @param alpha number 背景透明度（可选，默认 0.7）
function Utils.CreateBD(frame, alpha)
	-- 检查是否启用 NDui 美化风格
	local useNDui = KeywordMonitorDB and KeywordMonitorDB.UseNDuiStyle
	
	if useNDui then
		-- 使用完整的 NDui 风格美化
		if not frame.SetBackdrop then return end
		CreateBD(frame, alpha)
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

-- 公共接口：创建背景框架（NDui 风格）
-- @param frame Frame 要添加背景的框架
-- @param alpha number 背景透明度（可选）
-- @return Frame 创建的背景框架
function Utils.CreateBDFrame(frame, alpha)
	local useNDui = KeywordMonitorDB and KeywordMonitorDB.UseNDuiStyle
	
	if useNDui then
		return CreateBDFrame(frame, alpha)
	else
		-- 原生风格的简化版本
		local parent = frame
		if frame:IsObjectType("Texture") then parent = frame:GetParent() end
		
		local bg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
		SetOutside(bg, frame)
		bg:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = false,
			tileSize = 16,
			edgeSize = 12,
			insets = { left = 2, right = 2, top = 2, bottom = 2 }
		})
		bg:SetBackdropColor(0, 0, 0, alpha or 0.7)
		bg:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
		return bg
	end
end

-- 公共接口：设置背景（完整版，带阴影和纹理）
-- @param frame Frame 要添加背景的框架
-- @param alpha number 背景透明度（可选）
-- @param x, y, x2, y2 number 可选的偏移量
-- @return Frame 创建的背景框架
function Utils.SetBD(frame, alpha, x, y, x2, y2)
	local useNDui = KeywordMonitorDB and KeywordMonitorDB.UseNDuiStyle
	
	if useNDui then
		return SetBD(frame, alpha, x, y, x2, y2)
	else
		-- 原生风格
		local bg = Utils.CreateBDFrame(frame, alpha)
		if x then
			bg:ClearAllPoints()
			bg:SetPoint("TOPLEFT", frame, x, y)
			bg:SetPoint("BOTTOMRIGHT", frame, x2, y2)
		end
		return bg
	end
end

-- 公共接口：创建阴影
-- @param frame Frame 要添加阴影的框架
-- @param size number 阴影大小（可选）
-- @return Frame 创建的阴影框架
function Utils.CreateSD(frame, size)
	local useNDui = KeywordMonitorDB and KeywordMonitorDB.UseNDuiStyle
	
	if useNDui then
		return CreateSD(frame, size, true)
	end
	-- 原生风格不添加阴影
end

-- 公共接口：创建背景纹理
-- @param frame Frame 要添加纹理的框架
function Utils.CreateTex(frame)
	local useNDui = KeywordMonitorDB and KeywordMonitorDB.UseNDuiStyle
	
	if useNDui then
		CreateTex(frame)
	end
	-- 原生风格不添加纹理
end

-- 导出辅助函数供其他模块使用
Utils.SetOutside = SetOutside
Utils.SetInside = SetInside

--[[============================================
    NDui 风格美化函数
============================================]]--

-- 按钮鼠标悬停效果
local function Button_OnEnter(self)
	if self.__bg then
		self.__bg:SetBackdropBorderColor(0.7, 0.7, 0.7, 1)
	end
end

local function Button_OnLeave(self)
	if self.__bg then
		self.__bg:SetBackdropBorderColor(0, 0, 0, 1)
	end
end

-- 美化按钮（NDui 风格）
local function ReskinButton(button)
	if button.SetNormalTexture then button:SetNormalTexture(0) end
	if button.SetHighlightTexture then button:SetHighlightTexture(0) end
	if button.SetPushedTexture then button:SetPushedTexture(0) end
	if button.SetDisabledTexture then button:SetDisabledTexture("") end

	-- 移除暴雪默认纹理
	local regions = {"Left", "Middle", "Right", "Cover", "Border", "Background"}
	local buttonName = button.GetName and button:GetName()
	for _, region in pairs(regions) do
		local r = buttonName and _G[buttonName..region] or button[region]
		if r then
			r:SetAlpha(0)
			r:Hide()
		end
	end

	button.__bg = CreateBDFrame(button, 0)
	button.__bg:SetFrameLevel(button:GetFrameLevel())
	button.__bg:SetAllPoints()

	button:HookScript("OnEnter", Button_OnEnter)
	button:HookScript("OnLeave", Button_OnLeave)
end

-- 美化复选框（NDui 风格）
local function ReskinCheck(check)
	check:SetNormalTexture(0)
	check:SetPushedTexture(0)

	local bg = CreateBDFrame(check, 0)
	SetInside(bg, check, 4, 4)
	check.bg = bg

	check:SetHighlightTexture(bdTex)
	local hl = check:GetHighlightTexture()
	if hl then
		SetInside(hl, bg)
		hl:SetVertexColor(0.7, 0.7, 0.7, 0.25)
	end

	-- 创建勾选纹理
	local ch = check:CreateTexture(nil, "ARTWORK")
	ch:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
	ch:SetVertexColor(0, 0.8, 1)
	SetInside(ch, bg)
	check:SetCheckedTexture(ch)
end

-- 美化编辑框（NDui 风格）
local function ReskinEditBox(editbox)
	local regions = {"Left", "Middle", "Right", "Cover", "Border", "Background"}
	local frameName = editbox.GetName and editbox:GetName()
	for _, region in pairs(regions) do
		local r = frameName and _G[frameName..region] or editbox[region]
		if r then
			r:SetAlpha(0)
		end
	end

	local bg = CreateBDFrame(editbox, 0)
	bg:SetPoint("TOPLEFT", -2, 0)
	bg:SetPoint("BOTTOMRIGHT")
	editbox.bg = bg
end

-- 美化关闭按钮（NDui 风格）
local closeTex = Media.."Hutu\\close"  -- 使用 NDui 的关闭图标

local function ReskinClose(button, parent, xOffset, yOffset)
	parent = parent or button:GetParent()
	xOffset = xOffset or -6
	yOffset = yOffset or -6

	button:SetSize(16, 16)
	button:ClearAllPoints()
	button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", xOffset, yOffset)

	-- 移除默认纹理
	if button.SetNormalTexture then button:SetNormalTexture(0) end
	if button.SetHighlightTexture then button:SetHighlightTexture(0) end
	if button.SetPushedTexture then button:SetPushedTexture(0) end
	if button.Border then button.Border:SetAlpha(0) end

	local bg = CreateBDFrame(button, 0)
	bg:SetAllPoints()

	button:SetDisabledTexture(bdTex)
	local dis = button:GetDisabledTexture()
	dis:SetVertexColor(0, 0, 0, .4)
	dis:SetDrawLayer("OVERLAY")
	dis:SetAllPoints()

	-- 创建 X 图标
	local tex = button:CreateTexture()
	tex:SetTexture(closeTex)
	tex:SetAllPoints()
	tex:SetVertexColor(1, 1, 1)
	button.__texture = tex

	button:HookScript("OnEnter", function(self)
		if self.bg then
			self.bg:SetBackdropColor(0.7, 0, 0, 0.25)
		end
		if self.__texture then
			self.__texture:SetVertexColor(1, 0, 0)
		end
	end)
	button:HookScript("OnLeave", function(self)
		if self.bg then
			self.bg:SetBackdropColor(0, 0, 0, 0.25)
		end
		if self.__texture then
			self.__texture:SetVertexColor(1, 1, 1)
		end
	end)
end

--[[============================================
    公共 UI 创建函数
============================================]]--

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
	local useNDui = KeywordMonitorDB and KeywordMonitorDB.UseNDuiStyle
	
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(width, height)
	btn:EnableMouse(true)
	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	
	if useNDui then
		-- NDui 风格按钮
		ReskinButton(btn)
		
		-- 创建文本
		local fs = btn:CreateFontString(nil, "OVERLAY")
		fs:SetFont(STANDARD_TEXT_FONT, 13)
		fs:SetText(text or "")
		fs:SetPoint("CENTER")
		btn:SetFontString(fs)
	else
		-- 原生风格按钮
		btn:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up")
		btn:SetPushedTexture("Interface\\Buttons\\UI-Panel-Button-Down")
		btn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
		
		-- 获取纹理并设置正确的坐标
		local normalTexture = btn:GetNormalTexture()
		if normalTexture then
			normalTexture:SetTexCoord(0, 0.625, 0, 0.6875)
		end
		local pushedTexture = btn:GetPushedTexture()
		if pushedTexture then
			pushedTexture:SetTexCoord(0, 0.625, 0, 0.6875)
		end
		local highlightTexture = btn:GetHighlightTexture()
		if highlightTexture then
			highlightTexture:SetTexCoord(0, 0.625, 0, 0.6875)
			highlightTexture:SetBlendMode("ADD")
		end
		
		local fs = btn:CreateFontString(nil, "OVERLAY")
		fs:SetFont(STANDARD_TEXT_FONT, 13)
		fs:SetText(text or "")
		fs:SetPoint("CENTER", 0, 0)
		btn:SetFontString(fs)
	end
	
	return btn
end

-- 创建复选框
-- @param parent Frame 父框架
-- @return CheckButton 创建的复选框
function Utils.CreateCheckBox(parent)
	local useNDui = KeywordMonitorDB and KeywordMonitorDB.UseNDuiStyle
	
	local cb = CreateFrame("CheckButton", nil, parent)
	cb:SetSize(20, 20)
	cb:EnableMouse(true)
	cb:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	
	if useNDui then
		-- NDui 风格复选框
		ReskinCheck(cb)
	else
		-- 原生风格复选框
		cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
		cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
		cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
		cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
		cb:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
	end
	
	return cb
end

-- 创建编辑框
-- @param parent Frame 父框架
-- @param width number 编辑框宽度
-- @param height number 编辑框高度
-- @return EditBox 创建的编辑框
function Utils.CreateEditBox(parent, width, height)
	local useNDui = KeywordMonitorDB and KeywordMonitorDB.UseNDuiStyle
	
	-- 创建 EditBox 时添加 BackdropTemplate 支持
	local eb = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
	eb:SetSize(width, height)
	eb:SetAutoFocus(false)
	eb:SetFontObject(ChatFontNormal)
	
	if useNDui then
		-- NDui 风格编辑框
		ReskinEditBox(eb)
	else
		-- 原生风格编辑框
		eb:SetBackdrop({
			bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true,
			tileSize = 16,
			edgeSize = 16,
			insets = { left = 3, right = 3, top = 3, bottom = 3 }
		})
		eb:SetBackdropColor(0, 0, 0, 0.5)
		eb:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
	end
	
	eb:SetTextInsets(5, 5, 0, 0)
	return eb
end

-- 创建关闭按钮
-- @param parent Frame 父框架
-- @return Button 创建的关闭按钮
function Utils.CreateCloseButton(parent)
	local useNDui = KeywordMonitorDB and KeywordMonitorDB.UseNDuiStyle
	
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(32, 32)  -- 改为32x32，更大更容易点击
	
	if useNDui then
		-- NDui 风格关闭按钮
		ReskinClose(btn, parent)
	else
		-- 原生风格关闭按钮
		btn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
		btn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
		btn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
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

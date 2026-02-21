--[[
    KeywordMonitor - UI Module
    用户界面模块
    
    职责：
    - 提供配置界面创建和管理功能
    - 提供控制按钮创建和状态更新
    - 支持 NDui 美化风格和原生 UI 风格切换
    - 管理所有界面元素的创建和交互
    
    依赖：Utils 模块、Config 模块、Core 模块
    
    公共接口：
    - CreateConfigFrame() - 创建配置界面
    - CreateKeywordButton() - 创建控制按钮
    - UpdateButtonStatus() - 更新按钮状态
--]]

local addonName, addon = ...

-- 确保全局命名空间存在
if not _G.KeywordMonitor then
	_G.KeywordMonitor = {}
end

-- 获取全局命名空间（不使用 local 变量）
local KM = _G.KeywordMonitor

-- 创建 UI 模块命名空间
KM.UI = {}
local UI = KM.UI

-- 引用依赖模块（延迟加载，在函数调用时才访问）
local Utils, Config, Core

local function LoadDependencies()
	if not Utils then
		Utils = KM.Utils
		Config = KM.Config
		Core = KM.Core
		
		-- 依赖检查
		if not Utils then
			error("KeywordMonitor UI 模块需要 Utils 模块先加载")
		end
		if not Config then
			error("KeywordMonitor UI 模块需要 Config 模块先加载")
		end
		if not Core then
			error("KeywordMonitor UI 模块需要 Core 模块先加载")
		end
	end
end

--[[============================================
    本地化全局函数引用（性能优化）
============================================]]--

-- 基础 Lua 函数
local _G = _G
local type, pairs, ipairs, next = type, pairs, ipairs, next
local tonumber, tostring = tonumber, tostring
local pcall = pcall

-- 表操作函数
local tinsert, tremove, wipe, sort = table.insert, table.remove, wipe or table.wipe, table.sort

-- 字符串操作函数
local gsub, match, upper, strsplit, strlower, gmatch, find, sub, format = string.gsub, string.match, string.upper, strsplit, string.lower, string.gmatch, string.find, string.sub, string.format

-- 数学函数
local math_floor, math_max, math_min = math.floor, math.max, math.min

-- 时间相关函数
local GetServerTime, date, GetTime = GetServerTime, date, GetTime

-- 战斗和音效函数
local InCombatLockdown, PlaySound = InCombatLockdown, PlaySound
local PlaySoundFile = PlaySoundFile
local SOUNDKIT = SOUNDKIT

-- 插件检测函数
local IsAddOnLoaded = IsAddOnLoaded

-- 玩家和单位函数
local Ambiguate, IsShiftKeyDown, UnitName = Ambiguate, IsShiftKeyDown, UnitName
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local GetColoredName, GetPlayerLink = GetColoredName, GetPlayerLink

-- C_API 函数
local C_Timer, C_FriendList, C_BattleNet = C_Timer, C_FriendList, C_BattleNet

-- UI 框架函数
local CreateFrame = CreateFrame
local UIParent = UIParent
local GameTooltip = GameTooltip

-- 聊天框架函数
local ChatEdit_ChooseBoxForSend = ChatEdit_ChooseBoxForSend
local ChatEdit_SendText = ChatEdit_SendText
local ChatFrame_SendTell = ChatFrame_SendTell
local GetChatWindowInfo = GetChatWindowInfo
local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS
local FCF_StartAlertFlash = FCF_StartAlertFlash
local GeneralDockManager = GeneralDockManager

-- 字体和音效常量
local STANDARD_TEXT_FONT = STANDARD_TEXT_FONT

--[[============================================
    模块私有变量
============================================]]--

-- UI 元素引用
local configFrame = nil
local keywordButton = nil

--[[============================================
    公共接口函数
============================================]]--

--[[
    CreateConfigFrame()
    创建配置界面
    
    返回值：
    - frame: 配置界面框架
    
    说明：
    - 如果配置界面已存在，直接返回
    - 根据 UseNDuiStyle 配置选择界面风格
    - 创建所有配置选项和控件
--]]
function UI.CreateConfigFrame()
	LoadDependencies()
	if configFrame then return configFrame end
	Config.EnsureConfig()
	
	local frame = CreateFrame("Frame", "KeywordMonitor_Config", UIParent, "BackdropTemplate")
	frame:SetSize(500, 600)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	
	-- 根据配置选择UI风格
	local useNDui = KeywordMonitorDB.UseNDuiStyle
	if useNDui then
		-- 使用完整的 NDui 风格美化（带阴影和纹理）
		Utils.SetBD(frame)
	else
		-- 使用暴雪原生UI背景和边框（集结号风格）
		frame:SetBackdrop({
			bgFile = "Interface\\FrameGeneral\\UI-Background-Rock",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true,
			tileSize = 256,
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
	
	local title = Utils.CreateFS(frame, 16, "聊天关键词提取过滤", true)
	title:SetPoint("TOP", 0, -10)
	
	-- 版本号和作者（可点击）
	local versionBtn = CreateFrame("Button", nil, frame)
	versionBtn:SetSize(150, 20)
	versionBtn:SetPoint("TOPRIGHT", -25, -8)
	
	local versionText = Utils.CreateFS(versionBtn, 9, "v2.0.0 by 专业打地鼠", false, "RIGHT")
	versionText:SetPoint("RIGHT", 0, 0)
	versionText:SetTextColor(0.7, 0.7, 0.7)
	
	-- 鼠标悬停效果
	versionBtn:SetScript("OnEnter", function(self)
		versionText:SetTextColor(0, 1, 0)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("点击查看使用说明", 1, 1, 1)
		GameTooltip:Show()
	end)
	
	versionBtn:SetScript("OnLeave", function(self)
		versionText:SetTextColor(0.7, 0.7, 0.7)
		GameTooltip:Hide()
	end)
	
	-- 点击打开欢迎界面
	versionBtn:SetScript("OnClick", function()
		if KM.UI and KM.UI.ShowWelcomeDialog then
			local currentVersion = GetAddOnMetadata("KeywordMonitor", "Version") or "2.0.0"
			local author = GetAddOnMetadata("KeywordMonitor", "Author") or "专业打地鼠"
			KM.UI.ShowWelcomeDialog(currentVersion, "", author)  -- 空字符串表示显示首次安装界面
		end
	end)
	
	local closeBtn = Utils.CreateCloseButton(frame)
	closeBtn:SetPoint("TOPRIGHT", -15, -15)  -- 从-10,-10改为-15,-15，更宽松
	closeBtn:SetScript("OnClick", function() frame:Hide() end)
	
	local enableCheck = Utils.CreateCheckBox(frame)
	enableCheck:SetPoint("TOPLEFT", 20, -40)
	enableCheck:SetChecked(KeywordMonitorDB.Enabled)
	local enableLabel = Utils.CreateFS(frame, 14, "启用提取关注信息", false, "LEFT")
	enableLabel:SetPoint("LEFT", enableCheck, "RIGHT", 5, 0)
	enableLabel:SetTextColor(0, 1, 0)
	
	local keywordLabel = Utils.CreateFS(frame, 13, "关键词", false, "LEFT")
	keywordLabel:SetPoint("TOPLEFT", 20, -75)
	
	local keywordBox = Utils.CreateEditBox(frame, 460, 30)
	keywordBox:SetPoint("TOPLEFT", 20, -95)
	keywordBox:SetMaxLetters(500)
	keywordBox:SetText(KeywordMonitorDB.Keywords)
	
	-- 只在回车或失去焦点时保存
	keywordBox:SetScript("OnEnterPressed", function(self)
		local text = self:GetText()
		KeywordMonitorDB.Keywords = text
		Core.UpdateKeywordList(text)
		self:ClearFocus()
		print("|cff00FF00[ChatKeyword]|r 关键词已更新")
	end)
	
	keywordBox:SetScript("OnEditFocusLost", function(self)
		local text = self:GetText()
		KeywordMonitorDB.Keywords = text
		Core.UpdateKeywordList(text)
	end)
	
	local helpText1 = Utils.CreateFS(frame, 12, "关键词规则（用逗号分隔）：", false, "LEFT")
	helpText1:SetPoint("TOPLEFT", 20, -130)
	helpText1:SetTextColor(1, 0.8, 0)
	
	local helpText2 = Utils.CreateFS(frame, 11, "• 单个关键词：MC  →  匹配包含 MC 的消息", false, "LEFT")
	helpText2:SetPoint("TOPLEFT", 30, -150)
	helpText2:SetTextColor(0.7, 0.7, 0.7)
	
	local helpText3 = Utils.CreateFS(frame, 11, "• 同时包含（AND）：MC+FS 或 MC#FS  →  必须同时包含 MC 和 FS", false, "LEFT")
	helpText3:SetPoint("TOPLEFT", 30, -165)
	helpText3:SetTextColor(0, 1, 0)
	
	local helpText4 = Utils.CreateFS(frame, 11, "• 排除关键词：MC&ZS  →  包含 MC 但不包含 ZS", false, "LEFT")
	helpText4:SetPoint("TOPLEFT", 30, -180)
	helpText4:SetTextColor(0.7, 0.7, 0.7)
	
	local helpExample = Utils.CreateFS(frame, 11, "示例：MC+FS 可匹配 \"MC 24=1FS\" 但不匹配 \"MC 25=1\"", false, "LEFT")
	helpExample:SetPoint("TOPLEFT", 30, -200)
	helpExample:SetTextColor(0.5, 0.8, 1)
	
	local audioCheck = Utils.CreateCheckBox(frame)
	audioCheck:SetPoint("TOPLEFT", 20, -230)
	audioCheck:SetChecked(KeywordMonitorDB.AudioEnabled)
	local audioLabel = Utils.CreateFS(frame, 13, "提示音", false, "LEFT")
	audioLabel:SetPoint("LEFT", audioCheck, "RIGHT", 5, 0)
	
	audioCheck:SetScript("OnClick", function(self)
		local checked = self:GetChecked()
		KeywordMonitorDB.AudioEnabled = checked
	end)
	
	local audioText = Utils.CreateFS(frame, 12, "有关注消息", false, "LEFT")
	audioText:SetPoint("LEFT", audioLabel, "RIGHT", 10, 0)
	audioText:SetTextColor(0.7, 0.7, 0.7)
	
	-- 职业染色开关
	local classColorCheck = Utils.CreateCheckBox(frame)
	classColorCheck:SetPoint("LEFT", audioText, "RIGHT", 20, 0)
	classColorCheck:SetChecked(KeywordMonitorDB.ClassColorEnabled)
	local classColorLabel = Utils.CreateFS(frame, 13, "职业染色", false, "LEFT")
	classColorLabel:SetPoint("LEFT", classColorCheck, "RIGHT", 5, 0)
	
	classColorCheck:SetScript("OnClick", function(self)
		local checked = self:GetChecked()
		KeywordMonitorDB.ClassColorEnabled = checked
	end)
	
	local inheritCheck = Utils.CreateCheckBox(frame)
	inheritCheck:SetPoint("TOPLEFT", 20, -260)
	inheritCheck:SetChecked(KeywordMonitorDB.InheritFilter)
	local inheritLabel = Utils.CreateFS(frame, 13, "继承过滤设置再提取", false, "LEFT")
	inheritLabel:SetPoint("LEFT", inheritCheck, "RIGHT", 5, 0)
	
	inheritCheck:SetScript("OnClick", function(self)
		local checked = self:GetChecked()
		KeywordMonitorDB.InheritFilter = checked
	end)
	
	-- 频道选择按钮
	local channelBtn = Utils.CreateButton(frame, 120, 25, "频道选择")
	channelBtn:SetPoint("TOPLEFT", 20, -290)
	channelBtn:SetScript("OnClick", function()
		-- 创建频道选择弹窗
		if not frame.channelPopup then
			local popup = CreateFrame("Frame", nil, frame, "BackdropTemplate")
			popup:SetSize(250, 220)
			popup:SetPoint("CENTER", frame, "CENTER", -130, 0)
			popup:SetFrameLevel(frame:GetFrameLevel() + 10)
			
			if KeywordMonitorDB.UseNDuiStyle then
				Utils.SetBD(popup, 0.9)
			else
				popup:SetBackdrop({
					bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
					edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
					tile = true,
					tileSize = 16,
					edgeSize = 12,
					insets = { left = 2, right = 2, top = 2, bottom = 2 }
				})
			end
			
			popup:Hide()
			
			local popupTitle = Utils.CreateFS(popup, 14, "选择监控频道", true)
			popupTitle:SetPoint("TOP", 0, -10)
			
			local channels = {
				{key = "CHANNEL", label = "频道聊天"},
				{key = "SAY", label = "说"},
				{key = "YELL", label = "大喊"},
				{key = "WHISPER", label = "密语"},
				{key = "GUILD", label = "公会"},
				{key = "PARTY", label = "队伍"},
				{key = "RAID", label = "团队"},
			}
			
			popup.checks = {}
			for i, ch in ipairs(channels) do
				local check = Utils.CreateCheckBox(popup)
				check:SetPoint("TOPLEFT", 20, -30 - (i-1)*25)
				check:SetChecked(KeywordMonitorDB.Channels[ch.key])
				
				local label = Utils.CreateFS(popup, 12, ch.label, false, "LEFT")
				label:SetPoint("LEFT", check, "RIGHT", 5, 0)
				
				check:SetScript("OnClick", function(self)
					KeywordMonitorDB.Channels[ch.key] = self:GetChecked()
					-- 重新注册过滤器
					if KeywordMonitorDB.Enabled then
						Core.ToggleKeywordMonitor(false)
						Core.ToggleKeywordMonitor(true)
					end
				end)
				
				popup.checks[ch.key] = check
			end
			
			local closeBtn = Utils.CreateButton(popup, 60, 20, "关闭")
			closeBtn:SetPoint("BOTTOM", 0, 10)
			closeBtn:SetScript("OnClick", function() popup:Hide() end)
			
			frame.channelPopup = popup
		end
		
		if frame.channelPopup:IsShown() then
			frame.channelPopup:Hide()
		else
			frame.channelPopup:Show()
		end
	end)
	
	-- 黑名单管理按钮
	local blacklistBtn = Utils.CreateButton(frame, 120, 25, "黑名单管理")
	blacklistBtn:SetPoint("LEFT", channelBtn, "RIGHT", 10, 0)
	blacklistBtn:SetScript("OnClick", function()
		-- 创建黑名单管理弹窗
		if not frame.blacklistPopup then
			local popup = CreateFrame("Frame", nil, frame, "BackdropTemplate")
			popup:SetSize(300, 350)
			popup:SetPoint("CENTER", frame, "CENTER", 130, 0)
			popup:SetFrameLevel(frame:GetFrameLevel() + 10)
			
			if KeywordMonitorDB.UseNDuiStyle then
				Utils.SetBD(popup, 0.9)
			else
				popup:SetBackdrop({
					bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
					edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
					tile = true,
					tileSize = 16,
					edgeSize = 12,
					insets = { left = 2, right = 2, top = 2, bottom = 2 }
				})
			end
			
			popup:Hide()
			
			local popupTitle = Utils.CreateFS(popup, 14, "黑名单管理", true)
			popupTitle:SetPoint("TOP", 0, -10)
			
			-- 玩家黑名单
			local playerLabel = Utils.CreateFS(popup, 13, "玩家黑名单:", false, "LEFT")
			playerLabel:SetPoint("TOPLEFT", 15, -35)
			
			local playerInput = Utils.CreateEditBox(popup, 180, 25)
			playerInput:SetPoint("TOPLEFT", 15, -55)
			
			local playerAddBtn = Utils.CreateButton(popup, 60, 25, "添加")
			playerAddBtn:SetPoint("LEFT", playerInput, "RIGHT", 5, 0)
			playerAddBtn:SetScript("OnClick", function()
				local name = playerInput:GetText()
				if name and name ~= "" then
					KeywordMonitorDB.Blacklist.Players[name] = true
					playerInput:SetText("")
					print("|cff00FF00[ChatKeyword]|r 已将 |cffFFFF00" .. name .. "|r 加入玩家黑名单")
					-- 刷新列表
					if popup.playerList then
						if KM.Blacklist and KM.Blacklist.GetBlacklistPlayers then
							popup.playerList:SetText(table.concat(KM.Blacklist.GetBlacklistPlayers(), "\n"))
						else
							-- 临时实现：直接从配置读取
							local players = {}
							for pname, _ in pairs(KeywordMonitorDB.Blacklist.Players) do
								tinsert(players, pname)
							end
							sort(players)
							popup.playerList:SetText(table.concat(players, "\n"))
						end
					end
				end
			end)
			
			local playerListScroll = CreateFrame("ScrollFrame", nil, popup)
			playerListScroll:SetSize(260, 80)
			playerListScroll:SetPoint("TOPLEFT", 15, -85)
			
			local playerList = CreateFrame("EditBox", nil, playerListScroll)
			playerList:SetMultiLine(true)
			playerList:SetAutoFocus(false)
			playerList:SetFontObject(ChatFontNormal)
			playerList:SetWidth(260)
			playerListScroll:SetScrollChild(playerList)
			popup.playerList = playerList
			
			local playerClearBtn = Utils.CreateButton(popup, 100, 20, "清空玩家黑名单")
			playerClearBtn:SetPoint("TOPLEFT", 15, -170)
			playerClearBtn:SetScript("OnClick", function()
				KeywordMonitorDB.Blacklist.Players = {}
				playerList:SetText("")
				print("|cff00FF00[ChatKeyword]|r 已清空玩家黑名单")
			end)
			
			-- 关键词黑名单
			local keywordLabel = Utils.CreateFS(popup, 13, "关键词黑名单:", false, "LEFT")
			keywordLabel:SetPoint("TOPLEFT", 15, -200)
			
			local keywordInput = Utils.CreateEditBox(popup, 180, 25)
			keywordInput:SetPoint("TOPLEFT", 15, -220)
			
			local keywordAddBtn = Utils.CreateButton(popup, 60, 25, "添加")
			keywordAddBtn:SetPoint("LEFT", keywordInput, "RIGHT", 5, 0)
			keywordAddBtn:SetScript("OnClick", function()
				local kw = keywordInput:GetText()
				if kw and kw ~= "" then
					KeywordMonitorDB.Blacklist.Keywords[kw] = true
					keywordInput:SetText("")
					print("|cff00FF00[ChatKeyword]|r 已将 |cffFFFF00" .. kw .. "|r 加入关键词黑名单")
					-- 刷新列表
					if popup.keywordList then
						if KM.Blacklist and KM.Blacklist.GetBlacklistKeywords then
							popup.keywordList:SetText(table.concat(KM.Blacklist.GetBlacklistKeywords(), "\n"))
						else
							-- 临时实现：直接从配置读取
							local keywords = {}
							for keyword, _ in pairs(KeywordMonitorDB.Blacklist.Keywords) do
								tinsert(keywords, keyword)
							end
							sort(keywords)
							popup.keywordList:SetText(table.concat(keywords, "\n"))
						end
					end
				end
			end)
			
			local keywordListScroll = CreateFrame("ScrollFrame", nil, popup)
			keywordListScroll:SetSize(260, 50)
			keywordListScroll:SetPoint("TOPLEFT", 15, -250)
			
			local keywordList = CreateFrame("EditBox", nil, keywordListScroll)
			keywordList:SetMultiLine(true)
			keywordList:SetAutoFocus(false)
			keywordList:SetFontObject(ChatFontNormal)
			keywordList:SetWidth(260)
			keywordListScroll:SetScrollChild(keywordList)
			popup.keywordList = keywordList
			
			local keywordClearBtn = Utils.CreateButton(popup, 120, 20, "清空关键词黑名单")
			keywordClearBtn:SetPoint("TOPLEFT", 15, -305)
			keywordClearBtn:SetScript("OnClick", function()
				KeywordMonitorDB.Blacklist.Keywords = {}
				keywordList:SetText("")
				print("|cff00FF00[ChatKeyword]|r 已清空关键词黑名单")
			end)
			
			local closeBtn = Utils.CreateButton(popup, 60, 20, "关闭")
			closeBtn:SetPoint("BOTTOM", 0, 10)
			closeBtn:SetScript("OnClick", function() popup:Hide() end)
			
			-- 显示时刷新列表
			popup:SetScript("OnShow", function(self)
				if KM.Blacklist and KM.Blacklist.GetBlacklistPlayers and KM.Blacklist.GetBlacklistKeywords then
					playerList:SetText(table.concat(KM.Blacklist.GetBlacklistPlayers(), "\n"))
					keywordList:SetText(table.concat(KM.Blacklist.GetBlacklistKeywords(), "\n"))
				else
					-- 临时实现：直接从配置读取
					local players = {}
					for pname, _ in pairs(KeywordMonitorDB.Blacklist.Players) do
						tinsert(players, pname)
					end
					sort(players)
					playerList:SetText(table.concat(players, "\n"))
					
					local keywords = {}
					for keyword, _ in pairs(KeywordMonitorDB.Blacklist.Keywords) do
						tinsert(keywords, keyword)
					end
					sort(keywords)
					keywordList:SetText(table.concat(keywords, "\n"))
				end
			end)
			
			frame.blacklistPopup = popup
		end
		
		if frame.blacklistPopup:IsShown() then
			frame.blacklistPopup:Hide()
		else
			frame.blacklistPopup:Show()
		end
	end)
	
	-- 关键词分组管理按钮
	local groupBtn = Utils.CreateButton(frame, 120, 25, "关键词分组")
	groupBtn:SetPoint("TOPLEFT", 20, -320)
	groupBtn:SetScript("OnClick", function()
		if KM.Groups and KM.Groups.ShowKeywordGroupsUI then
			KM.Groups.ShowKeywordGroupsUI()
		else
			print("|cffFF0000[ChatKeyword]|r 分组管理模块尚未加载")
		end
	end)
	
	-- NDui 美化开关（始终可用）
	local nduiCheck = Utils.CreateCheckBox(frame)
	nduiCheck:SetPoint("TOPLEFT", 20, -355)
	nduiCheck:SetChecked(KeywordMonitorDB.UseNDuiStyle)
	local nduiLabel = Utils.CreateFS(frame, 13, "使用 NDui 美化风格", false, "LEFT")
	nduiLabel:SetPoint("LEFT", nduiCheck, "RIGHT", 5, 0)
	nduiLabel:SetTextColor(1, 0.8, 0)
	
	local nduiHint = Utils.CreateFS(frame, 11, "(完整 NDui 风格：背景、按钮、边框、阴影)", false, "LEFT")
	nduiHint:SetPoint("LEFT", nduiLabel, "RIGHT", 10, 0)
	nduiHint:SetTextColor(0.7, 0.7, 0.7)
	
	-- 重载按钮（初始隐藏）
	local reloadBtn = Utils.CreateButton(frame, 100, 25, "重载界面")
	reloadBtn:SetPoint("TOPLEFT", 20, -380)
	reloadBtn:Hide()
	reloadBtn:SetScript("OnClick", function()
		ReloadUI()
	end)
	
	nduiCheck:SetScript("OnClick", function(self)
		local checked = self:GetChecked()
		KeywordMonitorDB.UseNDuiStyle = checked
		-- 显示重载按钮
		reloadBtn:Show()
	end)
	
	local outputLabel = Utils.CreateFS(frame, 14, "输出方式:", false, "LEFT")
	outputLabel:SetPoint("TOPLEFT", 20, -410)
	
	local systemRadio = Utils.CreateCheckBox(frame)
	systemRadio:SetPoint("TOPLEFT", 40, -435)
	systemRadio:SetChecked(KeywordMonitorDB.OutputMode == 1)
	local systemLabel = Utils.CreateFS(frame, 13, "系统聊天窗口", false, "LEFT")
	systemLabel:SetPoint("LEFT", systemRadio, "RIGHT", 5, 0)
	
	local independentRadio = Utils.CreateCheckBox(frame)
	independentRadio:SetPoint("TOPLEFT", 40, -460)
	independentRadio:SetChecked(KeywordMonitorDB.OutputMode == 2)
	local independentLabel = Utils.CreateFS(frame, 13, "独立聊天窗口", false, "LEFT")
	independentLabel:SetPoint("LEFT", independentRadio, "RIGHT", 5, 0)
	
	local chatFrameLabel = Utils.CreateFS(frame, 13, "输出到聊天窗口", false, "LEFT")
	chatFrameLabel:SetPoint("TOPLEFT", 60, -490)
	
	local chatFrameDropdown = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	chatFrameDropdown:SetSize(150, 30)
	chatFrameDropdown:SetPoint("LEFT", chatFrameLabel, "RIGHT", 10, 0)
	Utils.CreateBD(chatFrameDropdown, .3)
	
	chatFrameDropdown.Text = Utils.CreateFS(chatFrameDropdown, 12, "", false, "LEFT")
	chatFrameDropdown.Text:SetPoint("LEFT", 10, 0)
	chatFrameDropdown.Text:SetPoint("RIGHT", -25, 0)
	
	chatFrameDropdown.Arrow = chatFrameDropdown:CreateTexture(nil, "ARTWORK")
	chatFrameDropdown.Arrow:SetSize(8, 8)
	chatFrameDropdown.Arrow:SetPoint("RIGHT", -10, 0)
	chatFrameDropdown.Arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
	
	chatFrameDropdown.List = CreateFrame("Frame", nil, chatFrameDropdown, "BackdropTemplate")
	chatFrameDropdown.List:SetPoint("TOP", chatFrameDropdown, "BOTTOM", 0, -2)
	chatFrameDropdown.List:SetWidth(chatFrameDropdown:GetWidth())
	Utils.CreateBD(chatFrameDropdown.List, .9)
	chatFrameDropdown.List:Hide()
	chatFrameDropdown.List:SetFrameStrata("DIALOG")
	
	local function UpdateChatFrameDropdown()
		local options = {}
		local dockedFrames = {}
		if GeneralDockManager then
			for _, chatFrame in ipairs(GeneralDockManager.DOCKED_CHAT_FRAMES) do
				if chatFrame then
					local id = chatFrame:GetID()
					dockedFrames[id] = true
				end
			end
		end
		
		for i = 1, NUM_CHAT_WINDOWS do
			local name = GetChatWindowInfo(i)
			if name and name ~= "" and dockedFrames[i] then
				tinsert(options, {
					text = name,
					value = i,
				})
			end
		end
		
		chatFrameDropdown.options = options
		
		local currentFrame = KeywordMonitorDB.OutputChatFrame
		local currentName = GetChatWindowInfo(currentFrame)
		
		local found = false
		for _, option in ipairs(options) do
			if option.value == currentFrame then
				found = true
				break
			end
		end
		
		if found and currentName and currentName ~= "" then
			chatFrameDropdown.Text:SetText(currentName)
		elseif #options > 0 then
			KeywordMonitorDB.OutputChatFrame = options[1].value
			chatFrameDropdown.Text:SetText(options[1].text)
		else
			chatFrameDropdown.Text:SetText("无可用窗口")
		end
	end
	
	chatFrameDropdown:SetScript("OnMouseDown", function(self)
		if self.List:IsShown() then
			self.List:Hide()
			return
		end
		
		UpdateChatFrameDropdown()
		
		if self.buttons then
			for _, btn in ipairs(self.buttons) do
				btn:Hide()
			end
		else
			self.buttons = {}
		end
		
		for i, option in ipairs(self.options) do
			local btn = self.buttons[i]
			if not btn then
				btn = CreateFrame("Button", nil, self.List, "BackdropTemplate")
				btn:SetSize(self.List:GetWidth() - 2, 20)
				Utils.CreateBD(btn, .3)
				
				btn.text = Utils.CreateFS(btn, 12, "", false, "LEFT")
				btn.text:SetPoint("LEFT", 5, 0)
				
				btn:SetScript("OnEnter", function(b)
					b:SetBackdropColor(1, 1, 1, .25)
				end)
				btn:SetScript("OnLeave", function(b)
					b:SetBackdropColor(0, 0, 0, .3)
				end)
				
				self.buttons[i] = btn
			end
			
			btn.text:SetText(option.text)
			btn:Show()
			
			if i == 1 then
				btn:SetPoint("TOPLEFT", self.List, "TOPLEFT", 1, -1)
			else
				btn:SetPoint("TOPLEFT", self.buttons[i-1], "BOTTOMLEFT", 0, -1)
			end
			
			btn:SetScript("OnClick", function()
				KeywordMonitorDB.OutputChatFrame = option.value
				self.Text:SetText(option.text)
				self.List:Hide()
			end)
		end
		
		local listHeight = #self.options * 21 + 2
		self.List:SetHeight(listHeight)
		self.List:Show()
	end)
	
	chatFrameDropdown.List:SetScript("OnHide", function(self)
		self:GetParent().Arrow:SetRotation(0)
	end)
	chatFrameDropdown.List:SetScript("OnShow", function(self)
		self:GetParent().Arrow:SetRotation(math.pi)
	end)
	
	UpdateChatFrameDropdown()
	
	local updateFrame = CreateFrame("Frame")
	updateFrame:RegisterEvent("UPDATE_CHAT_WINDOWS")
	updateFrame:SetScript("OnEvent", function(self, event)
		if event == "UPDATE_CHAT_WINDOWS" and frame:IsShown() then
			UpdateChatFrameDropdown()
		end
	end)
	
	local flashCheck = Utils.CreateCheckBox(frame)
	flashCheck:SetPoint("TOPLEFT", 60, -520)
	flashCheck:SetChecked(KeywordMonitorDB.FlashOnMatch)
	local flashLabel = Utils.CreateFS(frame, 13, "提取成功窗口标签闪动", false, "LEFT")
	flashLabel:SetPoint("LEFT", flashCheck, "RIGHT", 5, 0)
	
	flashCheck:SetScript("OnClick", function(self)
		local checked = self:GetChecked()
		KeywordMonitorDB.FlashOnMatch = checked
	end)
	
	local combatHideCheck = Utils.CreateCheckBox(frame)
	combatHideCheck:SetPoint("TOPLEFT", 60, -545)
	combatHideCheck:SetChecked(KeywordMonitorDB.CombatHide)
	local combatHideLabel = Utils.CreateFS(frame, 13, "战斗中隐藏独立窗口", false, "LEFT")
	combatHideLabel:SetPoint("LEFT", combatHideCheck, "RIGHT", 5, 0)
	
	combatHideCheck:SetScript("OnClick", function(self)
		local checked = self:GetChecked()
		KeywordMonitorDB.CombatHide = checked
	end)
	
	local function UpdateOptionsVisibility()
		local isEnabled = KeywordMonitorDB.Enabled
		local isSystemMode = KeywordMonitorDB.OutputMode == 1
		
		if isEnabled then
			keywordBox:Show()
			keywordLabel:Show()
			helpText1:Show()
			helpText2:Show()
			helpText3:Show()
			helpText4:Show()
			helpExample:Show()
			audioCheck:Show()
			audioLabel:Show()
			audioText:Show()
			classColorCheck:Show()
			classColorLabel:Show()
			inheritCheck:Show()
			inheritLabel:Show()
			
			-- 功能按钮
			channelBtn:Show()
			blacklistBtn:Show()
			groupBtn:Show()
			
			-- NDui 美化开关（始终显示）
			nduiCheck:Show()
			nduiLabel:Show()
			nduiHint:Show()
			
			outputLabel:Show()
			systemRadio:Show()
			systemLabel:Show()
			independentRadio:Show()
			independentLabel:Show()
			
			if isSystemMode then
				chatFrameLabel:Show()
				chatFrameDropdown:Show()
				flashCheck:Show()
				flashLabel:Show()
				combatHideCheck:Hide()
				combatHideLabel:Hide()
			else
				chatFrameLabel:Hide()
				chatFrameDropdown:Hide()
				flashCheck:Hide()
				flashLabel:Hide()
				combatHideCheck:Show()
				combatHideLabel:Show()
			end
		else
			keywordBox:Hide()
			keywordLabel:Hide()
			helpText1:Hide()
			helpText2:Hide()
			helpText3:Hide()
			helpText4:Hide()
			helpExample:Hide()
			audioCheck:Hide()
			audioLabel:Hide()
			audioText:Hide()
			classColorCheck:Hide()
			classColorLabel:Hide()
			inheritCheck:Hide()
			inheritLabel:Hide()
			
			-- 功能按钮
			channelBtn:Hide()
			blacklistBtn:Hide()
			groupBtn:Hide()
			
			-- NDui 美化开关
			nduiCheck:Hide()
			nduiLabel:Hide()
			nduiHint:Hide()
			
			outputLabel:Hide()
			systemRadio:Hide()
			systemLabel:Hide()
			independentRadio:Hide()
			independentLabel:Hide()
			chatFrameLabel:Hide()
			chatFrameDropdown:Hide()
			flashCheck:Hide()
			flashLabel:Hide()
			combatHideCheck:Hide()
			combatHideLabel:Hide()
		end
	end
	
	enableCheck:SetScript("OnClick", function(self)
		local checked = self:GetChecked()
		KeywordMonitorDB.Enabled = checked
		Core.ToggleKeywordMonitor(KeywordMonitorDB.Enabled)
		UpdateOptionsVisibility()
	end)
	
	systemRadio:SetScript("OnClick", function(self)
		if self:GetChecked() then
			KeywordMonitorDB.OutputMode = 1
			independentRadio:SetChecked(false)
			if chatFrameDropdown.List then
				chatFrameDropdown.List:Hide()
			end
			UpdateOptionsVisibility()
			Core.ToggleKeywordMonitor(KeywordMonitorDB.Enabled)
		else
			self:SetChecked(true)
		end
	end)
	
	independentRadio:SetScript("OnClick", function(self)
		if self:GetChecked() then
			KeywordMonitorDB.OutputMode = 2
			systemRadio:SetChecked(false)
			if chatFrameDropdown.List then
				chatFrameDropdown.List:Hide()
			end
			UpdateOptionsVisibility()
			Core.ToggleKeywordMonitor(KeywordMonitorDB.Enabled)
		else
			self:SetChecked(true)
		end
	end)
	
	UpdateOptionsVisibility()
	
	frame:SetScript("OnShow", function(self)
		enableCheck:SetChecked(KeywordMonitorDB.Enabled)
		reloadBtn:Hide()  -- 重新打开界面时隐藏重载按钮
		UpdateOptionsVisibility()
	end)
	
	configFrame = frame
	return frame
end

--[[
    CreateKeywordButton()
    创建控制按钮
    
    返回值：
    - button: 控制按钮框架
    
    说明：
    - 创建用于启用/禁用监控的控制按钮
    - 支持拖动和点击交互
    - 根据 UseNDuiStyle 配置选择按钮风格
    - 如果按钮已存在，直接返回
--]]
function UI.CreateKeywordButton()
	LoadDependencies()
	if keywordButton then return keywordButton end
	Config.EnsureConfig()
	
	local bu
	
	-- 检查是否启用 NDui 风格
	local useNDuiStyle = KeywordMonitorDB.UseNDuiStyle
	
	if useNDuiStyle then
		-- 创建 NDui 风格按钮
		bu = CreateFrame("Button", "KeywordMonitor_Button", UIParent, "BackdropTemplate")
		bu:SetSize(28, 28)
		
		-- 默认位置：综合频道标签的上方
		local chatTab = _G["ChatFrame1Tab"]
		if chatTab then
			bu:SetPoint("BOTTOM", chatTab, "TOP", 0, 5)
		else
			bu:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", 0, 5)
		end
		
		bu:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		bu:SetMovable(true)
		bu:SetClampedToScreen(true)
		
		-- 直接在按钮上设置 NDui 风格背景
		Utils.CreateBD(bu, 0.7)
		
		-- 创建阴影
		Utils.CreateSD(bu)
		
		-- 创建背景纹理
		Utils.CreateTex(bu)
		
		-- 创建图标
		bu.Icon = bu:CreateTexture(nil, "ARTWORK")
		bu.Icon:SetSize(18, 18)
		bu.Icon:SetPoint("CENTER", 0, 0)
		bu.Icon:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ArmoryChat")
		bu.Icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
		
		-- 高亮效果
		bu:SetScript("OnEnter", function(self)
			self:SetBackdropBorderColor(0.7, 0.7, 0.7, 1)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:AddLine("聊天关键词提取", 1, 1, 1)
			GameTooltip:AddLine("|cff00FFff左键|r - 打开配置", 0.7, 0.7, 0.7)
			GameTooltip:AddLine("|cff00FFff右键|r - 启用/关闭", 0.7, 0.7, 0.7)
			GameTooltip:AddLine("|cffFFFF00Shift+拖拽|r - 移动按钮", 0.7, 0.7, 0.7)
			GameTooltip:Show()
		end)
		bu:SetScript("OnLeave", function(self)
			self:SetBackdropBorderColor(0, 0, 0, 1)
			GameTooltip:Hide()
		end)
		
		-- 恢复保存的位置
		if KeywordMonitorDB.ButtonPos then
			bu:ClearAllPoints()
			bu:SetPoint(KeywordMonitorDB.ButtonPos.point, UIParent, KeywordMonitorDB.ButtonPos.relativePoint, 
				KeywordMonitorDB.ButtonPos.x, KeywordMonitorDB.ButtonPos.y)
		end
		
		-- 拖拽功能
		bu:RegisterForDrag("LeftButton")
		bu:SetScript("OnDragStart", function(self)
			if IsShiftKeyDown() then
				self:StartMoving()
			end
		end)
		bu:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing()
			local point, _, relativePoint, x, y = self:GetPoint()
			KeywordMonitorDB.ButtonPos = {
				point = point,
				relativePoint = relativePoint,
				x = x,
				y = y
			}
		end)
	else
		-- 创建类似暴雪UI的按钮样式
		bu = CreateFrame("Button", "KeywordMonitor_Button", UIParent, "BackdropTemplate")
		bu:SetSize(28, 28)
		
		-- 默认位置：综合频道标签的上方
		-- ChatFrame1Tab 是综合频道的标签
		local chatTab = _G["ChatFrame1Tab"]
		if chatTab then
			bu:SetPoint("BOTTOM", chatTab, "TOP", 0, 5)
		else
			-- 如果找不到标签，使用聊天框左上角作为备用位置
			bu:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", 0, 5)
		end
		
		bu:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		bu:SetMovable(true)
		bu:SetClampedToScreen(true)
		
		-- 使用暴雪标准的背景和边框
		bu:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = false,
			tileSize = 16,
			edgeSize = 12,
			insets = { left = 2, right = 2, top = 2, bottom = 2 }
		})
		bu:SetBackdropColor(0, 0, 0, 0.8)
		bu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
		
		-- 创建喇叭图标
		local icon = bu:CreateTexture(nil, "ARTWORK")
		icon:SetSize(18, 18)
		icon:SetPoint("CENTER", 0, 0)
		icon:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ArmoryChat")
		bu.Icon = icon
		
		-- 按下效果
		bu:SetScript("OnMouseDown", function(self)
			if not IsShiftKeyDown() then
				icon:SetPoint("CENTER", 1, -1)
			end
		end)
		bu:SetScript("OnMouseUp", function(self)
			icon:SetPoint("CENTER", 0, 0)
		end)
		
		-- 高亮效果
		local highlight = bu:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetAllPoints(icon)
		highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
		highlight:SetBlendMode("ADD")
		
		-- 恢复保存的位置
		if KeywordMonitorDB.ButtonPos then
			bu:ClearAllPoints()
			bu:SetPoint(KeywordMonitorDB.ButtonPos.point, UIParent, KeywordMonitorDB.ButtonPos.relativePoint, 
				KeywordMonitorDB.ButtonPos.x, KeywordMonitorDB.ButtonPos.y)
		end
		
		-- 拖拽功能
		bu:RegisterForDrag("LeftButton")
		bu:SetScript("OnDragStart", function(self)
			if IsShiftKeyDown() then
				self:StartMoving()
			end
		end)
		bu:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing()
			-- 保存位置
			local point, _, relativePoint, x, y = self:GetPoint()
			KeywordMonitorDB.ButtonPos = {
				point = point,
				relativePoint = relativePoint,
				x = x,
				y = y
			}
		end)
		
		-- 添加鼠标提示
		bu:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:AddLine("聊天关键词提取", 1, 1, 1)
			GameTooltip:AddLine("|cff00FFff左键|r - 打开配置", 0.7, 0.7, 0.7)
			GameTooltip:AddLine("|cff00FFff右键|r - 启用/关闭", 0.7, 0.7, 0.7)
			GameTooltip:AddLine("|cffFFFF00Shift+拖拽|r - 移动按钮", 0.7, 0.7, 0.7)
			GameTooltip:Show()
		end)
		bu:SetScript("OnLeave", function(self)
			GameTooltip:Hide()
		end)
	end
	
	-- 点击事件处理
	bu:SetScript("OnClick", function(self, button)
		if button == "LeftButton" then
			local frame = configFrame
			if not frame then
				frame = UI.CreateConfigFrame()
			end
			
			if frame and frame:IsShown() then
				frame:Hide()
			elseif frame then
				frame:Show()
			end
		elseif button == "RightButton" then
			if IsShiftKeyDown() then
				print("|cff00FF00[ChatKeyword]|r 过滤功能请使用其他插件")
			else
				KeywordMonitorDB.Enabled = not KeywordMonitorDB.Enabled
				Core.ToggleKeywordMonitor(KeywordMonitorDB.Enabled)
				print("|cff00FF00[ChatKeyword]|r 关键词提取: " .. (KeywordMonitorDB.Enabled and "|cff00FF00已开启|r" or "|cffFF0000已关闭|r"))
			end
		end
	end)
	
	keywordButton = bu
	UI.UpdateButtonStatus()
	return bu
end

--[[
    UpdateButtonStatus()
    更新按钮状态
    
    说明：
    - 根据当前监控启用状态更新按钮外观
    - 启用时图标显示绿色
    - 禁用时图标显示红色
--]]
function UI.UpdateButtonStatus()
	LoadDependencies()
	if not keywordButton then return end
	Config.EnsureConfig()
	
	if KeywordMonitorDB.Enabled then
		if keywordButton.Icon then
			keywordButton.Icon:SetVertexColor(0, 1, 0)
		end
	else
		if keywordButton.Icon then
			keywordButton.Icon:SetVertexColor(1, 0, 0)
		end
	end
end

--[[
    ShowWelcomeDialog(currentVersion, lastVersion, author)
    显示欢迎/更新对话框
    
    参数：
    - currentVersion: 当前版本号
    - lastVersion: 上次版本号（空字符串表示首次安装）
    - author: 作者名称
    
    说明：
    - 首次安装显示欢迎界面
    - 版本更新显示更新日志
--]]
function UI.ShowWelcomeDialog(currentVersion, lastVersion, author)
	LoadDependencies()
	
	local isFirstInstall = lastVersion == ""
	
	-- 创建对话框
	local dialog = CreateFrame("Frame", "KeywordMonitor_WelcomeDialog", UIParent, "BackdropTemplate")
	dialog:SetSize(600, 500)
	dialog:SetPoint("CENTER")
	dialog:SetFrameStrata("FULLSCREEN_DIALOG")
	dialog:SetFrameLevel(200)
	
	-- 根据配置选择UI风格
	local useNDui = KeywordMonitorDB.UseNDuiStyle
	if useNDui then
		Utils.SetBD(dialog)
	else
		-- 使用暴雪原生UI风格（集结号风格）
		dialog:SetBackdrop({
			bgFile = "Interface\\FrameGeneral\\UI-Background-Rock",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true,
			tileSize = 256,
			edgeSize = 32,
			insets = { left = 11, right = 12, top = 12, bottom = 11 }
		})
	end
	
	dialog:EnableMouse(true)
	dialog:SetMovable(true)
	dialog:RegisterForDrag("LeftButton")
	dialog:SetScript("OnDragStart", dialog.StartMoving)
	dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
	
	-- 标题
	local title = Utils.CreateFS(dialog, 18, isFirstInstall and "欢迎使用 KeywordMonitor" or "KeywordMonitor 已更新", true)
	title:SetPoint("TOP", 0, -20)
	title:SetTextColor(0, 1, 0)
	
	-- 版本信息
	local versionText = Utils.CreateFS(dialog, 14, "当前版本: v" .. currentVersion, false, "CENTER")
	versionText:SetPoint("TOP", 0, -50)
	versionText:SetTextColor(1, 1, 1)
	
	if not isFirstInstall then
		local lastVersionText = Utils.CreateFS(dialog, 12, "(上次: v" .. lastVersion .. ")", false, "CENTER")
		lastVersionText:SetPoint("TOP", 0, -70)
		lastVersionText:SetTextColor(0.5, 0.5, 0.5)
	end
	
	-- 作者信息
	local authorText = Utils.CreateFS(dialog, 12, "作者: " .. author, false, "CENTER")
	authorText:SetPoint("TOP", 0, isFirstInstall and -70 or -90)
	authorText:SetTextColor(0.7, 0.7, 0.7)
	
	-- 分隔线
	local separator = dialog:CreateTexture(nil, "ARTWORK")
	separator:SetSize(560, 1)
	separator:SetPoint("TOP", 0, isFirstInstall and -100 or -120)
	separator:SetColorTexture(0.3, 0.3, 0.3, 1)
	
	-- 内容区域（滚动框）
	local scrollFrame = CreateFrame("ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", 20, isFirstInstall and -120 or -140)
	scrollFrame:SetPoint("BOTTOMRIGHT", -40, 60)
	
	local scrollChild = CreateFrame("Frame", nil, scrollFrame)
	scrollChild:SetSize(540, 1)
	scrollFrame:SetScrollChild(scrollChild)
	
	local yOffset = -10
	
	if isFirstInstall then
		-- 首次安装：显示使用说明
		local usageTitle = Utils.CreateFS(scrollChild, 14, "使用说明", true)
		usageTitle:SetPoint("TOPLEFT", 10, yOffset)
		usageTitle:SetTextColor(1, 0.8, 0)
		yOffset = yOffset - 25
		
		local commands = {
			"/km - 打开配置界面",
			"/km on - 开启监控",
			"/km off - 关闭监控",
		}
		
		for _, cmd in ipairs(commands) do
			local cmdText = Utils.CreateFS(scrollChild, 12, "  • " .. cmd, false, "LEFT")
			cmdText:SetPoint("TOPLEFT", 10, yOffset)
			cmdText:SetTextColor(0.9, 0.9, 0.9)
			yOffset = yOffset - 20
		end
		
		yOffset = yOffset - 10
		
		-- 主要功能
		local featuresTitle = Utils.CreateFS(scrollChild, 14, "主要功能", true)
		featuresTitle:SetPoint("TOPLEFT", 10, yOffset)
		featuresTitle:SetTextColor(1, 0.8, 0)
		yOffset = yOffset - 25
		
		local features = {
			"关键词分组管理 - 灵活管理多组关键词",
			"预设方案 - 一键应用常用配置",
			"导入/导出 - 轻松备份和分享配置",
			"黑名单管理 - 过滤不想看到的玩家和关键词",
			"职业染色 - 根据职业显示不同颜色",
			"频道选择 - 自定义监控哪些聊天频道",
		}
		
		for _, feature in ipairs(features) do
			local featureText = Utils.CreateFS(scrollChild, 12, "  • " .. feature, false, "LEFT")
			featureText:SetPoint("TOPLEFT", 10, yOffset)
			featureText:SetTextColor(0.9, 0.9, 0.9)
			yOffset = yOffset - 20
		end
	else
		-- 版本更新：显示更新日志
		local updateTitle = Utils.CreateFS(scrollChild, 14, "v" .. currentVersion .. " 更新内容", true)
		updateTitle:SetPoint("TOPLEFT", 10, yOffset)
		updateTitle:SetTextColor(1, 0.8, 0)
		yOffset = yOffset - 25
		
		local updates = {
			"完成代码模块化重构",
			"将 6000+ 行代码拆分为 11 个独立模块",
			"新增职业染色开关功能",
			"提高代码可维护性和可扩展性",
			"优化模块加载顺序和性能",
			"保持所有原有功能不变",
			"保持数据完全兼容",
		}
		
		for _, update in ipairs(updates) do
			local updateText = Utils.CreateFS(scrollChild, 12, "  • " .. update, false, "LEFT")
			updateText:SetPoint("TOPLEFT", 10, yOffset)
			updateText:SetTextColor(0.9, 0.9, 0.9)
			yOffset = yOffset - 20
		end
	end
	
	scrollChild:SetHeight(math.abs(yOffset) + 20)
	
	-- 关闭按钮
	local closeBtn = Utils.CreateButton(dialog, 100, 30, "知道了")
	closeBtn:SetPoint("BOTTOM", 0, 20)
	closeBtn:SetScript("OnClick", function()
		dialog:Hide()
	end)
	
	-- 显示对话框
	dialog:Show()
end

--[[============================================
    模块初始化
============================================]]--

-- 模块加载完成标记
KM.UI.Loaded = true

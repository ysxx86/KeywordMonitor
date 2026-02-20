-- 聊天关键词提取过滤插件 (ChatKeyword)
-- 作者：专业打地鼠
-- 支持 NDui 美化和原生 UI

local addonName = "KeywordMonitor"
local KM = {}
_G[addonName] = KM

-- 本地化函数
local gsub, match, upper, strsplit, strlower, gmatch, find, sub = string.gsub, string.match, string.upper, strsplit, string.lower, string.gmatch, string.find, string.sub
local GetServerTime, date, GetTime = GetServerTime, date, GetTime
local InCombatLockdown, PlaySound = InCombatLockdown, PlaySound
local Ambiguate, IsShiftKeyDown, UnitName = Ambiguate, IsShiftKeyDown, UnitName
local C_Timer, C_FriendList, C_BattleNet = C_Timer, C_FriendList, C_BattleNet
local BNGetNumFriends, BNGetFriendInfoByID = BNGetNumFriends, BNGetFriendInfoByID
local tinsert, tremove = table.insert, table.remove
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local FCF_StartAlertFlash = FCF_StartAlertFlash
local GeneralDockManager = GeneralDockManager
local GetColoredName, GetPlayerLink = GetColoredName, GetPlayerLink
local ChatFrame_ReplaceIconAndGroupExpressions = C_ChatInfo and C_ChatInfo.ReplaceIconAndGroupExpressions or ChatFrame_ReplaceIconAndGroupExpressions
local ChatFrame_CanChatGroupPerformExpressionExpansion = ChatFrame_CanChatGroupPerformExpressionExpansion
local BNET_CLIENT_WOW = BNET_CLIENT_WOW

-- 全局变量
local keywordFrame
local keywords = {}
local keywordButton
local configFrame
local lastSoundTime = 0
local repeatMessageCache = {}

-- 检测是否有 NDui
local hasNDui = IsAddOnLoaded("NDui")
local B, C, L, DB
if hasNDui then
	local ns = select(2, ...)
	B, C, L, DB = unpack(ns)
end

-- 默认配置
local defaultConfig = {
	Enabled = false,
	Keywords = "",
	AudioEnabled = true,
	OutputMode = 2,
	OutputChatFrame = 1,
	FlashOnMatch = true,
	CombatHide = false,
	InheritFilter = true,
	KeywordFrameHeight = 180,
	BgColor = {0, 0, 0, 0.4},
	UseNDuiStyle = false,  -- 是否使用 NDui 美化
	-- 多频道支持
	Channels = {
		CHANNEL = true,   -- 频道聊天（默认开启，保持原有功能）
		SAY = false,      -- 说
		YELL = false,     -- 大喊
		WHISPER = false,  -- 密语
		GUILD = false,    -- 公会
		PARTY = false,    -- 队伍
		RAID = false,     -- 团队
	},
	-- 黑名单
	Blacklist = {
		Players = {},     -- 玩家黑名单 {["玩家名"] = true}
		Keywords = {},    -- 关键词黑名单 {["关键词"] = true}
	}
}

-- 初始化配置
local function EnsureConfig()
	if not KeywordMonitorDB then
		KeywordMonitorDB = {}
	end
	
	for k, v in pairs(defaultConfig) do
		if KeywordMonitorDB[k] == nil then
			if type(v) == "table" then
				KeywordMonitorDB[k] = {}
				for sk, sv in pairs(v) do
					KeywordMonitorDB[k][sk] = sv
				end
			else
				KeywordMonitorDB[k] = v
			end
		end
	end
	
	-- 确保子表存在
	if not KeywordMonitorDB.Channels then
		KeywordMonitorDB.Channels = defaultConfig.Channels
	end
	if not KeywordMonitorDB.Blacklist then
		KeywordMonitorDB.Blacklist = {Players = {}, Keywords = {}}
	end
	if not KeywordMonitorDB.Blacklist.Players then
		KeywordMonitorDB.Blacklist.Players = {}
	end
	if not KeywordMonitorDB.Blacklist.Keywords then
		KeywordMonitorDB.Blacklist.Keywords = {}
	end
end

-- UI 辅助函数（兼容 NDui 和原生）
local function CreateBD(frame, alpha)
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

local function CreateFS(frame, size, text, bold, justify)
	local fs = frame:CreateFontString(nil, "OVERLAY")
	fs:SetFont(STANDARD_TEXT_FONT, size, bold and "OUTLINE" or "")
	fs:SetText(text or "")
	if justify then
		fs:SetJustifyH(justify)
	end
	return fs
end

local function CreateButton(parent, width, height, text)
	local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	btn:SetSize(width, height)
	btn:SetText(text or "")
	return btn
end

local function CreateCheckBox(parent)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	cb:SetSize(24, 24)
	return cb
end

local function CreateEditBox(parent, width, height)
	local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	eb:SetSize(width, height)
	eb:SetAutoFocus(false)
	return eb
end

-- 检查是否是好友
local function IsFriend(name)
	if not name then return false end
	
	local numOnline = C_FriendList.GetNumOnlineFriends()
	for i = 1, numOnline do
		local info = C_FriendList.GetFriendInfoByIndex(i)
		if info and info.name == name then
			return true
		end
	end
	
	local _, numBNetOnline = BNGetNumFriends()
	for i = 1, numBNetOnline do
		local numGameAccounts = C_BattleNet.GetFriendNumGameAccounts(i)
		for j = 1, numGameAccounts do
			local gameAccountInfo = C_BattleNet.GetFriendGameAccountInfo(i, j)
			if gameAccountInfo and gameAccountInfo.clientProgram == BNET_CLIENT_WOW then
				if gameAccountInfo.characterName == name then
					return true
				end
			end
		end
	end
	
	return false
end

-- 清理文本函数
local function CleanText(text)
	if not text then return "" end
	text = gsub(text, "|H.-|h%[.-%]|h", "")
	text = gsub(text, "|c%x%x%x%x%x%x%x%x", "")
	text = gsub(text, "|r", "")
	text = gsub(text, "|T[^|]+|t", "")
	text = gsub(text, "|T[^|]+|T", "")
	text = gsub(text, "[%p%s]", "")
	text = upper(text)
	return text
end

-- 检查是否在黑名单中
local function IsBlacklisted(name, text)
	EnsureConfig()
	
	-- 检查玩家黑名单
	if name and KeywordMonitorDB.Blacklist.Players[name] then
		return true
	end
	
	-- 检查关键词黑名单
	if text then
		local cleanText = CleanText(text)
		for keyword, _ in pairs(KeywordMonitorDB.Blacklist.Keywords) do
			local cleanKeyword = upper(keyword)
			if find(cleanText, cleanKeyword, 1, true) then
				return true
			end
		end
	end
	
	return false
end

-- 检查是否是重复消息
local function IsRepeatMessage(text)
	local currentTime = GetTime()
	
	for i = #repeatMessageCache, 1, -1 do
		if currentTime - repeatMessageCache[i].time > 60 then
			tremove(repeatMessageCache, i)
		end
	end
	
	for _, cache in ipairs(repeatMessageCache) do
		if cache.text == text then
			return true
		end
	end
	
	tinsert(repeatMessageCache, {text = text, time = currentTime})
	return false
end

-- 工具函数：分割字符串
local function SplitString(str, delimiter)
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

-- 高亮关键词
local function HighlightKeyword(msg, matchedKeyword)
	if not matchedKeyword or not msg then return msg end
	
	local keywordsToHighlight = {}
	
	if type(matchedKeyword) == "string" then
		tinsert(keywordsToHighlight, matchedKeyword)
	elseif type(matchedKeyword) == "table" then
		for _, kw in ipairs(matchedKeyword) do
			if sub(kw, 1, 1) ~= "&" then
				tinsert(keywordsToHighlight, kw)
			end
		end
	end
	
	if #keywordsToHighlight == 0 then return msg end
	
	local result = msg
	local upperResult = upper(result)
	local highlights = {}
	
	for _, keyword in ipairs(keywordsToHighlight) do
		local upperKeyword = upper(keyword)
		local searchPos = 1
		
		while true do
			local startPos = find(upperResult, upperKeyword, searchPos, true)
			if not startPos then break end
			
			local endPos = startPos + #keyword - 1
			
			local overlap = false
			for _, hl in ipairs(highlights) do
				if not (endPos < hl.startPos or startPos > hl.endPos) then
					overlap = true
					break
				end
			end
			
			if not overlap then
				tinsert(highlights, {
					startPos = startPos,
					endPos = endPos,
					keyword = keyword
				})
			end
			
			searchPos = startPos + 1
		end
	end
	
	table.sort(highlights, function(a, b) return a.startPos > b.startPos end)
	
	for _, hl in ipairs(highlights) do
		local originalKeyword = sub(result, hl.startPos, hl.endPos)
		local highlighted = "|cff00FF00" .. originalKeyword .. "|r"
		result = sub(result, 1, hl.startPos - 1) .. highlighted .. sub(result, hl.endPos + 1)
	end
	
	return result
end

-- 检查是否匹配关键词
local function MatchKeywords(text)
	if #keywords == 0 then return false end
	
	local cleanText = CleanText(text)
	
	for i, keyword in ipairs(keywords) do
		if type(keyword) == "string" then
			if find(cleanText, keyword, 1, true) then
				return true, keyword
			end
		elseif type(keyword) == "table" then
			local allMatch = true
			for _, subKey in ipairs(keyword) do
				local isExclude = sub(subKey, 1, 1) == "&"
				local checkKey = isExclude and sub(subKey, 2) or subKey
				
				if isExclude then
					if find(cleanText, checkKey, 1, true) then
						allMatch = false
						break
					end
				else
					if not find(cleanText, checkKey, 1, true) then
						allMatch = false
						break
					end
				end
			end
			
			if allMatch then
				return true, keyword
			end
		end
	end
	
	return false
end

-- 更新关键词列表
function KM:UpdateKeywordList(keywordStr)
	keywords = {}
	if not keywordStr or keywordStr == "" then return end
	
	keywordStr = gsub(keywordStr, "，", ",")
	keywordStr = gsub(keywordStr, "＋", "+")
	
	local list = SplitString(keywordStr, ",")
	
	for _, word in ipairs(list) do
		if match(word, "&") or match(word, "#") or match(word, "+") then
			local subList = {}
			local currentWord = ""
			local isExclude = false
			
			for i = 1, #word do
				local char = sub(word, i, i)
				
				if char == "+" or char == "#" then
					currentWord = gsub(currentWord, "^%s*(.-)%s*$", "%1")
					if currentWord ~= "" then
						tinsert(subList, upper(currentWord))
					end
					currentWord = ""
					isExclude = false
				elseif char == "&" then
					currentWord = gsub(currentWord, "^%s*(.-)%s*$", "%1")
					if currentWord ~= "" then
						tinsert(subList, upper(currentWord))
					end
					currentWord = ""
					isExclude = true
				else
					currentWord = currentWord .. char
				end
			end
			
			currentWord = gsub(currentWord, "^%s*(.-)%s*$", "%1")
			if currentWord ~= "" then
				if isExclude then
					tinsert(subList, "&" .. upper(currentWord))
				else
					tinsert(subList, upper(currentWord))
				end
			end
			
			if #subList > 0 then
				tinsert(keywords, subList)
			end
		else
			local upperWord = upper(word)
			tinsert(keywords, upperWord)
		end
	end
end

-- 创建独立监控窗口
local function CreateKeywordFrame()
	if keywordFrame then return keywordFrame end
	EnsureConfig()
	
	local frame = CreateFrame("ScrollingMessageFrame", "KeywordMonitor_Frame", UIParent, "BackdropTemplate")
	frame:SetSize(ChatFrame1:GetWidth(), KeywordMonitorDB.KeywordFrameHeight)
	frame:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", 0, 30)
	frame:SetFrameStrata("MEDIUM")
	frame:SetFading(false)
	frame:SetMaxLines(100)
	frame:SetHyperlinksEnabled(true)
	frame:EnableMouse(true)
	frame:EnableMouseWheel(true)
	
	local fontPath, fontSize = ChatFrame1:GetFont()
	frame:SetFont(fontPath, fontSize, "OUTLINE")
	frame:SetShadowColor(0, 0, 0, 0)
	frame:SetJustifyH("LEFT")
	
	CreateBD(frame)
	
	local scrollBtn = CreateFrame("Button", nil, frame)
	scrollBtn:SetSize(20, 20)
	scrollBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 5)
	scrollBtn:SetAlpha(0.5)
	
	local icon = scrollBtn:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollEnd-Up")
	scrollBtn.icon = icon
	
	scrollBtn:Hide()
	scrollBtn:SetScript("OnEnter", function(self) self:SetAlpha(1) end)
	scrollBtn:SetScript("OnLeave", function(self) self:SetAlpha(0.5) end)
	scrollBtn:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_CHAT_BOTTOM)
		frame:ScrollToBottom()
		scrollBtn:Hide()
	end)
	frame.ScrollToBottomButton = scrollBtn
	
	frame:SetScript("OnMouseWheel", function(self, delta)
		if self:GetNumMessages() == 0 then return end
		scrollBtn:Show()
		if delta == 1 then
			self:ScrollUp()
		else
			self:ScrollDown()
			if self:AtBottom() then
				scrollBtn:Hide()
			end
		end
	end)
	
	frame:Hide()
	keywordFrame = frame
	return frame
end

-- 显示关键词消息
local function ShowKeywordMessage(self, event, msg, author, ...)
	EnsureConfig()
	if not KeywordMonitorDB.Enabled then return false end
	
	local guid = select(11, ...)
	local name = Ambiguate(author, "none")
	
	-- 过滤自己的消息
	if name == UnitName("player") then
		return false
	end
	
	-- 过滤好友消息
	if IsFriend(name) then
		return false
	end
	
	-- 检查黑名单
	if IsBlacklisted(name, msg) then
		return false
	end
	
	-- 检查关键词匹配
	local matched, keyword = MatchKeywords(msg)
	if not matched then return false end
	
	local cleanMsg = CleanText(msg)
	
	-- 过滤重复消息
	if IsRepeatMessage(cleanMsg) then
		return false
	end
	
	local time = GetServerTime()
	local timeStr = date("%H:%M", time)
	
	local language = select(1, ...)
	local channelString = select(2, ...)
	local channelName = ""
	
	if channelString and channelString ~= "" then
		local channelText = channelString:match("^%d+%. (.+)$")
		if channelText then
			channelName = string.format("[%s]", channelText)
		else
			channelName = string.format("[%s]", channelString)
		end
	else
		channelName = "[频道]"
	end
	
	local coloredName = GetColoredName(event, msg, author, ...)
	local playerLink = GetPlayerLink(author, "["..coloredName.."]")
	
	local r, g, b = 1, 1, 1
	local colorCode = coloredName:match("|cff(%x%x%x%x%x%x)")
	if colorCode then
		r = tonumber(colorCode:sub(1, 2), 16) / 255
		g = tonumber(colorCode:sub(3, 4), 16) / 255
		b = tonumber(colorCode:sub(5, 6), 16) / 255
	end
	
	local outMsg = msg
	if ChatFrame_ReplaceIconAndGroupExpressions then
		outMsg = ChatFrame_ReplaceIconAndGroupExpressions(msg, select(17, ...), not ChatFrame_CanChatGroupPerformExpressionExpansion("CHANNEL"))
	end
	
	outMsg = HighlightKeyword(outMsg, keyword)
	
	local output
	if KeywordMonitorDB.OutputMode == 1 then
		output = string.format("|cff808080%s|r |cffFFD700%s|r [|cff00FF00关注|r] %s: %s", timeStr, channelName, playerLink, outMsg)
	else
		output = string.format("|cff808080%s|r |cffFFD700%s|r %s: %s", timeStr, channelName, playerLink, outMsg)
	end
	
	if KeywordMonitorDB.OutputMode == 1 then
		local chatFrame = _G["ChatFrame"..KeywordMonitorDB.OutputChatFrame]
		if chatFrame then
			chatFrame:AddMessage(output, r, g, b)
			if KeywordMonitorDB.FlashOnMatch and GeneralDockManager.selected ~= chatFrame then
				FCF_StartAlertFlash(chatFrame)
			end
		end
	elseif KeywordMonitorDB.OutputMode == 2 then
		if keywordFrame and keywordFrame:IsShown() then
			keywordFrame:AddMessage(output, r, g, b)
		end
	end
	
	if KeywordMonitorDB.AudioEnabled then
		PlaySoundFile("Interface\\AddOns\\KeywordMonitor\\Audio\\FollowMsg_1.ogg", "Master")
	end
	
	return false
end

-- 更新按钮状态
local function UpdateButtonStatus()
	if not keywordButton then return end
	EnsureConfig()
	
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

-- 切换关键词监控
function KM:ToggleKeywordMonitor(enable)
	EnsureConfig()
	KeywordMonitorDB.Enabled = enable
	
	-- 移除所有频道的过滤器
	local channelEvents = {
		CHANNEL = "CHAT_MSG_CHANNEL",
		SAY = "CHAT_MSG_SAY",
		YELL = "CHAT_MSG_YELL",
		WHISPER = "CHAT_MSG_WHISPER",
		GUILD = "CHAT_MSG_GUILD",
		PARTY = "CHAT_MSG_PARTY",
		RAID = "CHAT_MSG_RAID",
	}
	
	for _, eventName in pairs(channelEvents) do
		ChatFrame_RemoveMessageEventFilter(eventName, ShowKeywordMessage)
	end
	
	if enable then
		if KeywordMonitorDB.OutputMode == 2 then
			if not keywordFrame then
				CreateKeywordFrame()
			end
			
			if keywordFrame then
				if KeywordMonitorDB.CombatHide then
					if not InCombatLockdown() then
						keywordFrame:Show()
					end
				else
					keywordFrame:Show()
				end
			end
		else
			if keywordFrame then
				keywordFrame:Hide()
				keywordFrame:SetParent(nil)
				keywordFrame = nil
			end
		end
		
		-- 注册已启用的频道过滤器
		for channelKey, eventName in pairs(channelEvents) do
			if KeywordMonitorDB.Channels[channelKey] then
				ChatFrame_AddMessageEventFilter(eventName, ShowKeywordMessage)
			end
		end
	else
		if keywordFrame then
			keywordFrame:Hide()
		end
	end
	
	UpdateButtonStatus()
end

-- 战斗隐藏处理
local function HandleCombatVisibility()
	EnsureConfig()
	if not KeywordMonitorDB.Enabled or KeywordMonitorDB.OutputMode ~= 2 or not KeywordMonitorDB.CombatHide then return end
	if not keywordFrame then return end
	
	if InCombatLockdown() then
		keywordFrame:Hide()
	else
		keywordFrame:Show()
	end
end

-- 创建配置界面
local function CreateConfigFrame()
	if configFrame then return configFrame end
	EnsureConfig()
	
	local frame = CreateFrame("Frame", "KeywordMonitor_Config", UIParent, "BackdropTemplate")
	frame:SetSize(500, 550)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	
	-- 根据配置选择UI风格
	local useNDui = KeywordMonitorDB.UseNDuiStyle
	if useNDui then
		-- 使用 NDui 风格的简洁边框
		frame:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Buttons\\WHITE8X8",
			edgeSize = 1,
		})
		frame:SetBackdropColor(0, 0, 0, 0.7)
		frame:SetBackdropBorderColor(0, 0, 0, 1)
	else
		-- 使用暴雪原生UI背景和边框
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
	
	local title = CreateFS(frame, 16, "聊天关键词提取过滤", true)
	title:SetPoint("TOP", 0, -10)
	
	local closeBtn = CreateButton(frame, 20, 20, "X")
	closeBtn:SetPoint("TOPRIGHT", -5, -5)
	closeBtn:SetScript("OnClick", function() frame:Hide() end)
	
	local enableCheck = CreateCheckBox(frame)
	enableCheck:SetPoint("TOPLEFT", 20, -40)
	enableCheck:SetChecked(KeywordMonitorDB.Enabled)
	local enableLabel = CreateFS(frame, 14, "启用提取关注信息", false, "LEFT")
	enableLabel:SetPoint("LEFT", enableCheck, "RIGHT", 5, 0)
	enableLabel:SetTextColor(0, 1, 0)
	
	local keywordLabel = CreateFS(frame, 13, "关键词", false, "LEFT")
	keywordLabel:SetPoint("TOPLEFT", 20, -75)
	
	local keywordBox = CreateEditBox(frame, 460, 30)
	keywordBox:SetPoint("TOPLEFT", 20, -95)
	keywordBox:SetMaxLetters(500)
	keywordBox:SetText(KeywordMonitorDB.Keywords)
	
	C_Timer.After(0, function()
		keywordBox:SetScript("OnTextChanged", function(self)
			local text = self:GetText()
			KeywordMonitorDB.Keywords = text
			KM:UpdateKeywordList(text)
		end)
	end)
	
	local helpText1 = CreateFS(frame, 12, "关键词规则（用逗号分隔）：", false, "LEFT")
	helpText1:SetPoint("TOPLEFT", 20, -130)
	helpText1:SetTextColor(1, 0.8, 0)
	
	local helpText2 = CreateFS(frame, 11, "• 单个关键词：MC  →  匹配包含 MC 的消息", false, "LEFT")
	helpText2:SetPoint("TOPLEFT", 30, -150)
	helpText2:SetTextColor(0.7, 0.7, 0.7)
	
	local helpText3 = CreateFS(frame, 11, "• 同时包含（AND）：MC+FS 或 MC#FS  →  必须同时包含 MC 和 FS", false, "LEFT")
	helpText3:SetPoint("TOPLEFT", 30, -165)
	helpText3:SetTextColor(0, 1, 0)
	
	local helpText4 = CreateFS(frame, 11, "• 排除关键词：MC&ZS  →  包含 MC 但不包含 ZS", false, "LEFT")
	helpText4:SetPoint("TOPLEFT", 30, -180)
	helpText4:SetTextColor(0.7, 0.7, 0.7)
	
	local helpExample = CreateFS(frame, 11, "示例：MC+FS 可匹配 \"MC 24=1FS\" 但不匹配 \"MC 25=1\"", false, "LEFT")
	helpExample:SetPoint("TOPLEFT", 30, -200)
	helpExample:SetTextColor(0.5, 0.8, 1)
	
	local audioCheck = CreateCheckBox(frame)
	audioCheck:SetPoint("TOPLEFT", 20, -230)
	audioCheck:SetChecked(KeywordMonitorDB.AudioEnabled)
	local audioLabel = CreateFS(frame, 13, "提示音", false, "LEFT")
	audioLabel:SetPoint("LEFT", audioCheck, "RIGHT", 5, 0)
	
	audioCheck:SetScript("OnClick", function(self)
		local checked = self:GetChecked()
		KeywordMonitorDB.AudioEnabled = checked
	end)
	
	local audioText = CreateFS(frame, 12, "有关注消息", false, "LEFT")
	audioText:SetPoint("LEFT", audioLabel, "RIGHT", 10, 0)
	audioText:SetTextColor(0.7, 0.7, 0.7)
	
	local inheritCheck = CreateCheckBox(frame)
	inheritCheck:SetPoint("TOPLEFT", 20, -260)
	inheritCheck:SetChecked(KeywordMonitorDB.InheritFilter)
	local inheritLabel = CreateFS(frame, 13, "继承过滤设置再提取", false, "LEFT")
	inheritLabel:SetPoint("LEFT", inheritCheck, "RIGHT", 5, 0)
	
	inheritCheck:SetScript("OnClick", function(self)
		local checked = self:GetChecked()
		KeywordMonitorDB.InheritFilter = checked
	end)
	
	-- 频道选择按钮
	local channelBtn = CreateButton(frame, 120, 25, "频道选择")
	channelBtn:SetPoint("TOPLEFT", 20, -290)
	channelBtn:SetScript("OnClick", function()
		-- 创建频道选择弹窗
		if not frame.channelPopup then
			local popup = CreateFrame("Frame", nil, frame, "BackdropTemplate")
			popup:SetSize(250, 220)
			popup:SetPoint("CENTER", frame, "CENTER", -130, 0)
			popup:SetFrameLevel(frame:GetFrameLevel() + 10)
			
			if KeywordMonitorDB.UseNDuiStyle then
				popup:SetBackdrop({
					bgFile = "Interface\\Buttons\\WHITE8X8",
					edgeFile = "Interface\\Buttons\\WHITE8X8",
					edgeSize = 1,
				})
				popup:SetBackdropColor(0, 0, 0, 0.9)
				popup:SetBackdropBorderColor(0, 0, 0, 1)
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
			
			local popupTitle = CreateFS(popup, 14, "选择监控频道", true)
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
				local check = CreateCheckBox(popup)
				check:SetPoint("TOPLEFT", 20, -30 - (i-1)*25)
				check:SetChecked(KeywordMonitorDB.Channels[ch.key])
				
				local label = CreateFS(popup, 12, ch.label, false, "LEFT")
				label:SetPoint("LEFT", check, "RIGHT", 5, 0)
				
				check:SetScript("OnClick", function(self)
					KeywordMonitorDB.Channels[ch.key] = self:GetChecked()
					-- 重新注册过滤器
					if KeywordMonitorDB.Enabled then
						KM:ToggleKeywordMonitor(false)
						KM:ToggleKeywordMonitor(true)
					end
				end)
				
				popup.checks[ch.key] = check
			end
			
			local closeBtn = CreateButton(popup, 60, 20, "关闭")
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
	local blacklistBtn = CreateButton(frame, 120, 25, "黑名单管理")
	blacklistBtn:SetPoint("LEFT", channelBtn, "RIGHT", 10, 0)
	blacklistBtn:SetScript("OnClick", function()
		-- 创建黑名单管理弹窗
		if not frame.blacklistPopup then
			local popup = CreateFrame("Frame", nil, frame, "BackdropTemplate")
			popup:SetSize(300, 350)
			popup:SetPoint("CENTER", frame, "CENTER", 130, 0)
			popup:SetFrameLevel(frame:GetFrameLevel() + 10)
			
			if KeywordMonitorDB.UseNDuiStyle then
				popup:SetBackdrop({
					bgFile = "Interface\\Buttons\\WHITE8X8",
					edgeFile = "Interface\\Buttons\\WHITE8X8",
					edgeSize = 1,
				})
				popup:SetBackdropColor(0, 0, 0, 0.9)
				popup:SetBackdropBorderColor(0, 0, 0, 1)
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
			
			local popupTitle = CreateFS(popup, 14, "黑名单管理", true)
			popupTitle:SetPoint("TOP", 0, -10)
			
			-- 玩家黑名单
			local playerLabel = CreateFS(popup, 13, "玩家黑名单:", false, "LEFT")
			playerLabel:SetPoint("TOPLEFT", 15, -35)
			
			local playerInput = CreateEditBox(popup, 180, 25)
			playerInput:SetPoint("TOPLEFT", 15, -55)
			
			local playerAddBtn = CreateButton(popup, 60, 25, "添加")
			playerAddBtn:SetPoint("LEFT", playerInput, "RIGHT", 5, 0)
			playerAddBtn:SetScript("OnClick", function()
				local name = playerInput:GetText()
				if name and name ~= "" then
					KeywordMonitorDB.Blacklist.Players[name] = true
					playerInput:SetText("")
					print("|cff00FF00[ChatKeyword]|r 已将 |cffFFFF00" .. name .. "|r 加入玩家黑名单")
					-- 刷新列表
					if popup.playerList then
						popup.playerList:SetText(table.concat(KM:GetBlacklistPlayers(), "\n"))
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
			
			local playerClearBtn = CreateButton(popup, 100, 20, "清空玩家黑名单")
			playerClearBtn:SetPoint("TOPLEFT", 15, -170)
			playerClearBtn:SetScript("OnClick", function()
				KeywordMonitorDB.Blacklist.Players = {}
				playerList:SetText("")
				print("|cff00FF00[ChatKeyword]|r 已清空玩家黑名单")
			end)
			
			-- 关键词黑名单
			local keywordLabel = CreateFS(popup, 13, "关键词黑名单:", false, "LEFT")
			keywordLabel:SetPoint("TOPLEFT", 15, -200)
			
			local keywordInput = CreateEditBox(popup, 180, 25)
			keywordInput:SetPoint("TOPLEFT", 15, -220)
			
			local keywordAddBtn = CreateButton(popup, 60, 25, "添加")
			keywordAddBtn:SetPoint("LEFT", keywordInput, "RIGHT", 5, 0)
			keywordAddBtn:SetScript("OnClick", function()
				local kw = keywordInput:GetText()
				if kw and kw ~= "" then
					KeywordMonitorDB.Blacklist.Keywords[kw] = true
					keywordInput:SetText("")
					print("|cff00FF00[ChatKeyword]|r 已将 |cffFFFF00" .. kw .. "|r 加入关键词黑名单")
					-- 刷新列表
					if popup.keywordList then
						popup.keywordList:SetText(table.concat(KM:GetBlacklistKeywords(), "\n"))
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
			
			local keywordClearBtn = CreateButton(popup, 120, 20, "清空关键词黑名单")
			keywordClearBtn:SetPoint("TOPLEFT", 15, -305)
			keywordClearBtn:SetScript("OnClick", function()
				KeywordMonitorDB.Blacklist.Keywords = {}
				keywordList:SetText("")
				print("|cff00FF00[ChatKeyword]|r 已清空关键词黑名单")
			end)
			
			local closeBtn = CreateButton(popup, 60, 20, "关闭")
			closeBtn:SetPoint("BOTTOM", 0, 10)
			closeBtn:SetScript("OnClick", function() popup:Hide() end)
			
			-- 显示时刷新列表
			popup:SetScript("OnShow", function(self)
				playerList:SetText(table.concat(KM:GetBlacklistPlayers(), "\n"))
				keywordList:SetText(table.concat(KM:GetBlacklistKeywords(), "\n"))
			end)
			
			frame.blacklistPopup = popup
		end
		
		if frame.blacklistPopup:IsShown() then
			frame.blacklistPopup:Hide()
		else
			frame.blacklistPopup:Show()
		end
	end)
	
	-- NDui 美化开关（始终可用）
	local nduiCheck = CreateCheckBox(frame)
	nduiCheck:SetPoint("TOPLEFT", 20, -325)
	nduiCheck:SetChecked(KeywordMonitorDB.UseNDuiStyle)
	local nduiLabel = CreateFS(frame, 13, "使用 NDui 美化风格", false, "LEFT")
	nduiLabel:SetPoint("LEFT", nduiCheck, "RIGHT", 5, 0)
	nduiLabel:SetTextColor(1, 0.8, 0)
	
	local nduiHint = CreateFS(frame, 11, "(简洁黑色边框)", false, "LEFT")
	nduiHint:SetPoint("LEFT", nduiLabel, "RIGHT", 10, 0)
	nduiHint:SetTextColor(0.7, 0.7, 0.7)
	
	nduiCheck:SetScript("OnClick", function(self)
		local checked = self:GetChecked()
		KeywordMonitorDB.UseNDuiStyle = checked
		-- 提示需要重载界面
		print("|cff00FF00[ChatKeyword]|r 美化风格已更改，请 |cffFFFF00/reload|r 重载界面生效")
	end)
	
	local outputLabel = CreateFS(frame, 14, "输出方式:", false, "LEFT")
	outputLabel:SetPoint("TOPLEFT", 20, -355)
	
	local systemRadio = CreateCheckBox(frame)
	systemRadio:SetPoint("TOPLEFT", 40, -380)
	systemRadio:SetChecked(KeywordMonitorDB.OutputMode == 1)
	local systemLabel = CreateFS(frame, 13, "系统聊天窗口", false, "LEFT")
	systemLabel:SetPoint("LEFT", systemRadio, "RIGHT", 5, 0)
	
	local independentRadio = CreateCheckBox(frame)
	independentRadio:SetPoint("LEFT", systemLabel, "RIGHT", 30, 0)
	independentRadio:SetChecked(KeywordMonitorDB.OutputMode == 2)
	local independentLabel = CreateFS(frame, 13, "独立聊天窗口", false, "LEFT")
	independentLabel:SetPoint("LEFT", independentRadio, "RIGHT", 5, 0)
	
	local chatFrameLabel = CreateFS(frame, 13, "输出到聊天窗口", false, "LEFT")
	chatFrameLabel:SetPoint("TOPLEFT", 60, -410)
	
	local chatFrameDropdown = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	chatFrameDropdown:SetSize(150, 30)
	chatFrameDropdown:SetPoint("LEFT", chatFrameLabel, "RIGHT", 10, 0)
	CreateBD(chatFrameDropdown, .3)
	
	chatFrameDropdown.Text = CreateFS(chatFrameDropdown, 12, "", false, "LEFT")
	chatFrameDropdown.Text:SetPoint("LEFT", 10, 0)
	chatFrameDropdown.Text:SetPoint("RIGHT", -25, 0)
	
	chatFrameDropdown.Arrow = chatFrameDropdown:CreateTexture(nil, "ARTWORK")
	chatFrameDropdown.Arrow:SetSize(8, 8)
	chatFrameDropdown.Arrow:SetPoint("RIGHT", -10, 0)
	chatFrameDropdown.Arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
	
	chatFrameDropdown.List = CreateFrame("Frame", nil, chatFrameDropdown, "BackdropTemplate")
	chatFrameDropdown.List:SetPoint("TOP", chatFrameDropdown, "BOTTOM", 0, -2)
	chatFrameDropdown.List:SetWidth(chatFrameDropdown:GetWidth())
	CreateBD(chatFrameDropdown.List, .9)
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
				CreateBD(btn, .3)
				
				btn.text = CreateFS(btn, 12, "", false, "LEFT")
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
	
	local flashCheck = CreateCheckBox(frame)
	flashCheck:SetPoint("TOPLEFT", 60, -440)
	flashCheck:SetChecked(KeywordMonitorDB.FlashOnMatch)
	local flashLabel = CreateFS(frame, 13, "提取成功窗口标签闪动", false, "LEFT")
	flashLabel:SetPoint("LEFT", flashCheck, "RIGHT", 5, 0)
	
	flashCheck:SetScript("OnClick", function(self)
		local checked = self:GetChecked()
		KeywordMonitorDB.FlashOnMatch = checked
	end)
	
	local combatHideCheck = CreateCheckBox(frame)
	combatHideCheck:SetPoint("TOPLEFT", 60, -470)
	combatHideCheck:SetChecked(KeywordMonitorDB.CombatHide)
	local combatHideLabel = CreateFS(frame, 13, "战斗中隐藏独立窗口", false, "LEFT")
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
			inheritCheck:Show()
			inheritLabel:Show()
			
			-- 频道选择和黑名单按钮
			channelBtn:Show()
			blacklistBtn:Show()
			
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
			inheritCheck:Hide()
			inheritLabel:Hide()
			
			-- 频道选择和黑名单按钮
			channelBtn:Hide()
			blacklistBtn:Hide()
			
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
		KM:ToggleKeywordMonitor(KeywordMonitorDB.Enabled)
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
			KM:ToggleKeywordMonitor(KeywordMonitorDB.Enabled)
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
			KM:ToggleKeywordMonitor(KeywordMonitorDB.Enabled)
		else
			self:SetChecked(true)
		end
	end)
	
	UpdateOptionsVisibility()
	
	frame:SetScript("OnShow", function(self)
		enableCheck:SetChecked(KeywordMonitorDB.Enabled)
		UpdateOptionsVisibility()
	end)
	
	configFrame = frame
	return frame
end

-- 创建按钮
function KM:CreateKeywordButton()
	if keywordButton then return keywordButton end
	EnsureConfig()
	
	local bu
	
	if hasNDui then
		local chatbar = _G["NDui_ChatBar"]
		if not chatbar then return end
		
		local width, height = 40, 8
		bu = CreateFrame("Button", "KeywordMonitor_Button", chatbar, "BackdropTemplate")
		bu:SetSize(width, height)
		
		if B and B.PixelIcon then
			B.PixelIcon(bu, DB.normTex, true)
			B.CreateSD(bu)
			bu.Icon:SetVertexColor(1, 0, 0)
		end
		
		bu:SetHitRectInsets(0, 0, -8, -8)
		bu:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		
		if B and B.AddTooltip then
			B.AddTooltip(bu, "ANCHOR_TOP", 
				"|cff00FFff左键|r - 设置提取过滤\n" ..
				"|cff00FFff右键|r - 启用/关闭提取\n" ..
				"|cff00FFffShift+右键|r - 启用/关闭过滤"
			)
		end
		
		local children = {chatbar:GetChildren()}
		local lastButton
		for i = #children, 1, -1 do
			if children[i]:IsObjectType("Button") and children[i] ~= bu then
				lastButton = children[i]
				break
			end
		end
		
		if lastButton then
			bu:SetPoint("LEFT", lastButton, "RIGHT", 5, 0)
		else
			bu:SetPoint("LEFT", chatbar, "LEFT", 0, 0)
		end
	else
		-- 创建类似暴雪UI的按钮样式
		bu = CreateFrame("Button", "KeywordMonitor_Button", UIParent, "BackdropTemplate")
		bu:SetSize(28, 28)
		bu:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", 0, 5)
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
	
	bu:SetScript("OnClick", function(self, button)
		if button == "LeftButton" then
			local frame = configFrame
			if not frame then
				frame = CreateConfigFrame()
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
				KM:ToggleKeywordMonitor(KeywordMonitorDB.Enabled)
				print("|cff00FF00[ChatKeyword]|r 关键词提取: " .. (KeywordMonitorDB.Enabled and "|cff00FF00已开启|r" or "|cffFF0000已关闭|r"))
			end
		end
	end)
	
	keywordButton = bu
	UpdateButtonStatus()
	return bu
end

-- 获取玩家黑名单列表
function KM:GetBlacklistPlayers()
	EnsureConfig()
	local list = {}
	for name, _ in pairs(KeywordMonitorDB.Blacklist.Players) do
		tinsert(list, name)
	end
	table.sort(list)
	return list
end

-- 获取关键词黑名单列表
function KM:GetBlacklistKeywords()
	EnsureConfig()
	local list = {}
	for keyword, _ in pairs(KeywordMonitorDB.Blacklist.Keywords) do
		tinsert(list, keyword)
	end
	table.sort(list)
	return list
end

-- 初始化
function KM:Init()
	EnsureConfig()
	
	C_Timer.After(2, function()
		if KeywordMonitorDB.Keywords and KeywordMonitorDB.Keywords ~= "" then
			KM:UpdateKeywordList(KeywordMonitorDB.Keywords)
		end
		
		KM:CreateKeywordButton()
		
		if KeywordMonitorDB.Enabled then
			KM:ToggleKeywordMonitor(true)
		end
	end)
	
	local eventFrame = CreateFrame("Frame")
	eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
	eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	eventFrame:SetScript("OnEvent", function(self, event)
		HandleCombatVisibility()
	end)
	
	SlashCmdList["KEYWORDMONITOR"] = function(msg)
		local cmd, args = strsplit(" ", msg, 2)
		cmd = strlower(cmd or "")
		
		if cmd == "on" or cmd == "开启" then
			KeywordMonitorDB.Enabled = true
			KM:ToggleKeywordMonitor(true)
			print("|cff00FF00[ChatKeyword]|r 关键词提取已开启")
		elseif cmd == "off" or cmd == "关闭" then
			KeywordMonitorDB.Enabled = false
			KM:ToggleKeywordMonitor(false)
			print("|cff00FF00[ChatKeyword]|r 关键词提取已关闭")
		elseif cmd == "set" or cmd == "设置" then
			if args and args ~= "" then
				KeywordMonitorDB.Keywords = args
				KM:UpdateKeywordList(args)
				print("|cff00FF00[ChatKeyword]|r 关键词已设置为: " .. args)
			else
				print("|cff00FF00[ChatKeyword]|r 用法: /keyword set 关键词1,关键词2")
			end
		elseif cmd == "debug" or cmd == "调试" then
			print("|cff00FF00[ChatKeyword 调试]|r")
			if #keywords == 0 then
				print("  当前没有设置关键词")
			else
				for i, kw in ipairs(keywords) do
					if type(kw) == "string" then
						print(string.format("  [%d] 单个: %s", i, kw))
					elseif type(kw) == "table" then
						local parts = {}
						for _, subKw in ipairs(kw) do
							if sub(subKw, 1, 1) == "&" then
								tinsert(parts, "|cffFF0000排除:" .. sub(subKw, 2) .. "|r")
							else
								tinsert(parts, "|cff00FF00包含:" .. subKw .. "|r")
							end
						end
						print(string.format("  [%d] 组合: %s", i, table.concat(parts, " ")))
					end
				end
			end
		elseif cmd == "config" or cmd == "配置" or cmd == "" then
			if not configFrame then
				CreateConfigFrame()
			end
			if configFrame:IsShown() then
				configFrame:Hide()
			else
				configFrame:Show()
			end
		else
			print("|cff00FF00[ChatKeyword]|r")
			print("  /keyword on - 开启提取")
			print("  /keyword off - 关闭提取")
			print("  /keyword set 关键词1,关键词2 - 设置关键词")
			print("  /keyword debug - 显示当前关键词解析结果")
			print("  /keyword config - 打开配置界面")
		end
	end
	SLASH_KEYWORDMONITOR1 = "/keyword"
	SLASH_KEYWORDMONITOR2 = "/关键词"
end

-- 启动
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addon)
	if addon == addonName then
		KM:Init()
		self:UnregisterEvent("ADDON_LOADED")
	end
end)

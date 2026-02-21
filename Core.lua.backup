-- 聊天关键词提取过滤插件 (ChatKeyword)
-- 作者：专业打地鼠
-- 支持 NDui 美化和原生 UI

local addonName = "KeywordMonitor"
local KM = {}
_G[addonName] = KM

-- 本地化全局函数（性能优化 - 避免全局查找）
local _G = _G
local type, pairs, ipairs, next = type, pairs, ipairs, next
local tinsert, tremove, wipe, sort = table.insert, table.remove, wipe or table.wipe, table.sort
local gsub, match, upper, strsplit, strlower, gmatch, find, sub, format = string.gsub, string.match, string.upper, strsplit, string.lower, string.gmatch, string.find, string.sub, string.format
local GetServerTime, date, GetTime, time = GetServerTime, date, GetTime, time
local InCombatLockdown, PlaySound = InCombatLockdown, PlaySound
local Ambiguate, IsShiftKeyDown, UnitName = Ambiguate, IsShiftKeyDown, UnitName
local C_Timer, C_FriendList, C_BattleNet = C_Timer, C_FriendList, C_BattleNet
local BNGetNumFriends, BNGetFriendInfoByID = BNGetNumFriends, BNGetFriendInfoByID
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local FCF_StartAlertFlash = FCF_StartAlertFlash
local GeneralDockManager = GeneralDockManager
local GetColoredName, GetPlayerLink = GetColoredName, GetPlayerLink
local ChatFrame_ReplaceIconAndGroupExpressions = C_ChatInfo and C_ChatInfo.ReplaceIconAndGroupExpressions or ChatFrame_ReplaceIconAndGroupExpressions
local ChatFrame_CanChatGroupPerformExpressionExpansion = ChatFrame_CanChatGroupPerformExpressionExpansion
local BNET_CLIENT_WOW = BNET_CLIENT_WOW
local CreateFrame = CreateFrame
local UIParent = UIParent
local GameTooltip = GameTooltip
local ChatEdit_ChooseBoxForSend = ChatEdit_ChooseBoxForSend
local ChatEdit_SendText = ChatEdit_SendText
local ChatFrame_SendTell = ChatFrame_SendTell
local UpdateAddOnMemoryUsage = UpdateAddOnMemoryUsage
local GetAddOnMemoryUsage = GetAddOnMemoryUsage
local GetChatWindowInfo = GetChatWindowInfo
local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS
local STANDARD_TEXT_FONT = STANDARD_TEXT_FONT
local SOUNDKIT = SOUNDKIT
local PlaySoundFile = PlaySoundFile
local collectgarbage = collectgarbage
local loadstring = loadstring
local pcall = pcall
local tonumber, tostring = tonumber, tostring
local math_floor, math_max, math_min, math_huge, math_random = math.floor, math.max, math.min, math.huge, math.random

-- 全局变量
local keywordFrame
local keywords = {}
local keywordButton
local configFrame

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
	},
	-- 关键词分组
	KeywordGroups = {
		{name = "默认组", keywords = "", enabled = true, color = {0, 1, 0}},
	},
	UseKeywordGroups = false,  -- 是否使用分组模式
	-- 历史记录
	History = {},  -- 最近的匹配消息
	HistoryMaxCount = 500,  -- 最多保存500条（3天的数据）
	HistoryRetentionDays = 3,  -- 保留3天
	-- 快速回复
	QuickReplies = {
		"有兴趣，密我",
		"什么价格？",
		"还在吗？",
	},
	-- 统计数据
	Statistics = {
		TodayMatches = 0,           -- 今日匹配次数
		LastResetDate = "",         -- 上次重置日期
		KeywordCounts = {},         -- 关键词匹配次数 {["关键词"] = 次数}
		HourCounts = {},            -- 每小时匹配次数 {[0-23] = 次数}
		TotalMatches = 0,           -- 总匹配次数
	},
	-- 预设方案
	Presets = {},  -- 用户自定义的预设方案
	-- 时间触发
	TimeTriggers = {},  -- 时间段自动启用 {groupIndex = {startHour, endHour}}
	-- 趋势分析
	TrendData = {
		Daily = {},  -- 每日数据 {["2026-02-20"] = {total = 100, keywords = {MC = 50}}}
		Hourly = {}, -- 每小时数据（最近24小时）
	},
	-- 关键词关联
	KeywordCorrelation = {},  -- 关键词关联 {["MC"] = {["FS"] = 10, ["ZS"] = 5}}
	-- 性能监控
	Performance = {
		MessageCount = 0,        -- 处理的消息总数
		LastResetTime = 0,       -- 上次重置时间
		MessagesPerSecond = 0,   -- 每秒处理消息数
	},
	-- 数据清理
	AutoCleanOldData = true,     -- 自动清理旧数据
	DataRetentionDays = 3,       -- 数据保留天数（从7改为3）
	LastVersion = "",            -- 上次运行的版本
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
	if not KeywordMonitorDB.KeywordGroups then
		KeywordMonitorDB.KeywordGroups = defaultConfig.KeywordGroups
	end
	if not KeywordMonitorDB.History then
		KeywordMonitorDB.History = {}
	end
	if not KeywordMonitorDB.QuickReplies then
		KeywordMonitorDB.QuickReplies = defaultConfig.QuickReplies
	end
	if KeywordMonitorDB.UseKeywordGroups == nil then
		KeywordMonitorDB.UseKeywordGroups = false
	end
	if not KeywordMonitorDB.HistoryMaxCount then
		KeywordMonitorDB.HistoryMaxCount = 50  -- 从100改为50
	end
	if not KeywordMonitorDB.Statistics then
		KeywordMonitorDB.Statistics = {
			TodayMatches = 0,
			LastResetDate = date("%Y-%m-%d", GetServerTime()),
			KeywordCounts = {},
			HourCounts = {},
			TotalMatches = 0,
		}
	end
	
	-- 检查是否需要重置今日统计
	local currentDate = date("%Y-%m-%d", GetServerTime())
	if KeywordMonitorDB.Statistics.LastResetDate ~= currentDate then
		KeywordMonitorDB.Statistics.TodayMatches = 0
		KeywordMonitorDB.Statistics.LastResetDate = currentDate
	end
	
	-- 初始化小时统计
	if not KeywordMonitorDB.Statistics.HourCounts then
		KeywordMonitorDB.Statistics.HourCounts = {}
	end
	for i = 0, 23 do
		if not KeywordMonitorDB.Statistics.HourCounts[i] then
			KeywordMonitorDB.Statistics.HourCounts[i] = 0
		end
	end
	

	
	-- 初始化预设方案
	if not KeywordMonitorDB.Presets then
		KeywordMonitorDB.Presets = {}
	end
	
	-- 初始化时间触发
	if not KeywordMonitorDB.TimeTriggers then
		KeywordMonitorDB.TimeTriggers = {}
	end
	
	-- 初始化趋势数据
	if not KeywordMonitorDB.TrendData then
		KeywordMonitorDB.TrendData = {
			Daily = {},
			Hourly = {},
		}
	end
	
	-- 初始化关键词关联
	if not KeywordMonitorDB.KeywordCorrelation then
		KeywordMonitorDB.KeywordCorrelation = {}
	end
	
	-- 初始化性能监控
	if not KeywordMonitorDB.Performance then
		KeywordMonitorDB.Performance = {
			MessageCount = 0,
			LastResetTime = GetTime(),
			MessagesPerSecond = 0,
		}
	end
	
	-- 初始化数据清理设置
	if KeywordMonitorDB.AutoCleanOldData == nil then
		KeywordMonitorDB.AutoCleanOldData = true
	end
	if not KeywordMonitorDB.DataRetentionDays then
		KeywordMonitorDB.DataRetentionDays = 3  -- 从7改为3
	end
	
	-- 初始化自定义停用词列表
	if not KeywordMonitorDB.CustomStopWords then
		KeywordMonitorDB.CustomStopWords = {}
	end
	
	-- 初始化词汇替换映射表
	if not KeywordMonitorDB.WordReplacements then
		KeywordMonitorDB.WordReplacements = {}
	end
	
	if not KeywordMonitorDB.LastVersion then
		KeywordMonitorDB.LastVersion = ""
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

-- 创建美观的关闭按钮
local function CreateCloseButton(parent)
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

-- 清理文本函数（优化版 - 减少gsub调用）
local function CleanText(text)
	if not text then return "" end
	-- 合并多个gsub操作，减少字符串创建
	text = gsub(text, "|[HhTtCcRr][^|]*|[hHtT]", "")  -- 移除所有颜色和链接代码
	text = gsub(text, "[%p%s]", "")  -- 移除标点和空格
	return upper(text)
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
		local cleanedText = CleanText(text)
		for keyword, _ in pairs(KeywordMonitorDB.Blacklist.Keywords) do
			local cleanKeyword = upper(keyword)
			if find(cleanedText, cleanKeyword, 1, true) then
				return true
			end
		end
	end
	
	return false
end

-- 检查是否是重复消息（优化版 - 使用固定大小的循环缓存）
local repeatMessageCache = {}
local repeatMessageIndex = {}  -- 用于快速查找
local repeatMessageQueue = {}  -- 用于维护顺序
local repeatMessageCount = 0
local MAX_CACHE_SIZE = 50

local function IsRepeatMessage(text)
	local currentTime = GetTime()
	
	-- 快速查找
	local cachedTime = repeatMessageIndex[text]
	if cachedTime then
		-- 如果在60秒内重复，返回true
		if currentTime - cachedTime < 60 then
			repeatMessageIndex[text] = currentTime
			return true
		end
	end
	
	-- 如果缓存满了，移除最旧的
	if repeatMessageCount >= MAX_CACHE_SIZE then
		local oldestText = repeatMessageQueue[1]
		if oldestText then
			repeatMessageIndex[oldestText] = nil
			tremove(repeatMessageQueue, 1)
			repeatMessageCount = repeatMessageCount - 1
		end
	end
	
	-- 添加新消息
	repeatMessageIndex[text] = currentTime
	tinsert(repeatMessageQueue, text)
	repeatMessageCount = repeatMessageCount + 1
	return false
end

-- 清理重复消息缓存（定时调用）
local function CleanRepeatMessageCache()
	local currentTime = GetTime()
	local cleaned = 0
	local newQueue = {}
	
	for i = 1, #repeatMessageQueue do
		local text = repeatMessageQueue[i]
		local timestamp = repeatMessageIndex[text]
		if timestamp and currentTime - timestamp <= 180 then
			tinsert(newQueue, text)
		else
			repeatMessageIndex[text] = nil
			cleaned = cleaned + 1
		end
	end
	
	repeatMessageQueue = newQueue
	repeatMessageCount = #newQueue
	return cleaned
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

-- 工具函数：清理UI元素列表（防止内存泄漏 - 使用wipe优化）
local function CleanupUIElements(elements)
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

-- 高亮关键词（支持多关键词高亮）
local function HighlightKeyword(msg, matchedKeyword)
	if not matchedKeyword or not msg then return msg end
	
	-- 收集所有需要高亮的关键词
	local keywordsToHighlight = {}
	
	if type(matchedKeyword) == "string" then
		tinsert(keywordsToHighlight, matchedKeyword)
	elseif type(matchedKeyword) == "table" then
		-- 收集所有非排除的关键词
		for i = 1, #matchedKeyword do
			local kw = matchedKeyword[i]
			if sub(kw, 1, 1) ~= "&" then
				tinsert(keywordsToHighlight, kw)
			end
		end
	end
	
	if #keywordsToHighlight == 0 then return msg end
	
	-- 高亮所有匹配的关键词
	local upperMsg = upper(msg)
	local result = msg
	
	-- 收集所有匹配位置
	local matches = {}
	for _, keyword in ipairs(keywordsToHighlight) do
		local upperKeyword = upper(keyword)
		local startPos = 1
		while true do
			local pos = find(upperMsg, upperKeyword, startPos, true)
			if not pos then break end
			tinsert(matches, {pos = pos, len = #keyword})
			startPos = pos + 1
		end
	end
	
	-- 按位置排序（从后往前，避免位置偏移）
	sort(matches, function(a, b) return a.pos > b.pos end)
	
	-- 应用高亮
	for _, match in ipairs(matches) do
		local startPos = match.pos
		local endPos = startPos + match.len - 1
		local originalKeyword = sub(result, startPos, endPos)
		result = sub(result, 1, startPos - 1) .. "|cff00FF00" .. originalKeyword .. "|r" .. sub(result, endPos + 1)
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
	
	EnsureConfig()
	
	-- 如果启用了分组模式，使用分组关键词
	if KeywordMonitorDB.UseKeywordGroups then
		for _, group in ipairs(KeywordMonitorDB.KeywordGroups) do
			if group.enabled and group.keywords and group.keywords ~= "" then
				local groupKeywordStr = group.keywords
				groupKeywordStr = gsub(groupKeywordStr, "，", ",")
				groupKeywordStr = gsub(groupKeywordStr, "＋", "+")
				
				local list = SplitString(groupKeywordStr, ",")
				
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
		end
		return
	end
	
	-- 传统模式：使用单一关键词字符串
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

-- 更新性能统计
function KM:UpdatePerformance()
	EnsureConfig()
	
	KeywordMonitorDB.Performance.MessageCount = KeywordMonitorDB.Performance.MessageCount + 1
	
	local currentTime = GetTime()
	local elapsed = currentTime - KeywordMonitorDB.Performance.LastResetTime
	
	-- 每10秒更新一次每秒处理消息数
	if elapsed >= 10 then
		KeywordMonitorDB.Performance.MessagesPerSecond = KeywordMonitorDB.Performance.MessageCount / elapsed
		KeywordMonitorDB.Performance.MessageCount = 0
		KeywordMonitorDB.Performance.LastResetTime = currentTime
	end
end

-- 获取插件内存使用（KB）- 使用缓存避免频繁调用
local lastMemoryCheck = 0
local cachedMemory = 0
function KM:GetMemoryUsage()
	local currentTime = GetTime()
	-- 只在5秒后才重新检查内存，避免频繁调用导致性能问题
	if currentTime - lastMemoryCheck > 5 then
		UpdateAddOnMemoryUsage()
		cachedMemory = GetAddOnMemoryUsage("KeywordMonitor")
		lastMemoryCheck = currentTime
	end
	return cachedMemory
end

-- 获取性能统计
function KM:GetPerformanceStats()
	EnsureConfig()
	
	return {
		memory = KM:GetMemoryUsage(),
		messagesPerSecond = KeywordMonitorDB.Performance.MessagesPerSecond,
		totalMessages = KeywordMonitorDB.Statistics.TotalMatches or 0,
	}
end

-- 清理旧数据
function KM:CleanOldData()
	EnsureConfig()
	
	if not KeywordMonitorDB.AutoCleanOldData then
		return
	end
	
	local retentionDays = KeywordMonitorDB.DataRetentionDays or 7
	local currentTime = GetServerTime()
	local cutoffTime = currentTime - retentionDays * 86400
	
	-- 清理每日趋势数据
	local cleaned = 0
	for dateStr, _ in pairs(KeywordMonitorDB.TrendData.Daily) do
		local year, month, day = dateStr:match("(%d+)-(%d+)-(%d+)")
		if year and month and day then
			local dataTime = time({year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = 0, min = 0, sec = 0})
			if dataTime < cutoffTime then
				KeywordMonitorDB.TrendData.Daily[dateStr] = nil
				cleaned = cleaned + 1
			end
		end
	end
	
	if cleaned > 0 then
		print("|cff00FF00[ChatKeyword]|r 已清理 " .. cleaned .. " 天的旧数据")
	end
	
	-- 额外的内存优化
	KM:OptimizeMemory()
end

-- 内存优化（优化版 - 使用更高效的清理方式）
function KM:OptimizeMemory()
	EnsureConfig()
	
	local cleaned = 0
	
	-- 1. 限制历史记录
	local history = KeywordMonitorDB.History
	local historyMax = KeywordMonitorDB.HistoryMaxCount
	if #history > historyMax then
		local toRemove = #history - historyMax
		for i = 1, toRemove do
			tremove(history)
			cleaned = cleaned + 1
		end
	end
	
	-- 2. 清理关键词关联低频数据
	local correlation = KeywordMonitorDB.KeywordCorrelation
	for kw1, correlations in pairs(correlation) do
		for kw2, count in pairs(correlations) do
			if count < 5 then
				correlations[kw2] = nil
				cleaned = cleaned + 1
			end
		end
		-- 检查是否为空
		local hasData = false
		for _ in pairs(correlations) do
			hasData = true
			break
		end
		if not hasData then
			correlation[kw1] = nil
		end
	end
	
	-- 3. 清理重复消息缓存
	local cacheCleared = CleanRepeatMessageCache()
	cleaned = cleaned + cacheCleared
	
	-- 4. 清理趋势数据中的低频关键词
	local trendDaily = KeywordMonitorDB.TrendData.Daily
	for dateStr, data in pairs(trendDaily) do
		if data.keywords then
			for kw, count in pairs(data.keywords) do
				if count < 2 then
					data.keywords[kw] = nil
					cleaned = cleaned + 1
				end
			end
		end
	end
	
	-- 5. 只在清理了足够多数据后才执行垃圾回收
	if cleaned > 10 then
		collectgarbage("collect")
	end
	
	return cleaned
end

-- 检查是否需要显示更新日志
function KM:CheckVersionUpdate()
	EnsureConfig()
	
	local currentVersion = "1.7.2"
	local lastVersion = KeywordMonitorDB.LastVersion or ""
	
	if lastVersion ~= currentVersion then
		-- 显示更新日志
		C_Timer.After(3, function()
			KM:ShowUpdateLog(currentVersion, lastVersion)
		end)
		
		-- 更新版本号
		KeywordMonitorDB.LastVersion = currentVersion
	end
end

-- 显示更新日志
function KM:ShowUpdateLog(currentVersion, lastVersion)
	local isFirstInstall = lastVersion == ""
	
	if isFirstInstall then
		print("|cff00FF00===========================================|r")
		print("|cff00FF00[ChatKeyword]|r 欢迎使用聊天关键词提取过滤插件！")
		print("|cff00FF00当前版本：|r v" .. currentVersion)
		print("|cff00FF00作者：|r 专业打地鼠")
		print("|cff00FF00===========================================|r")
		print("|cffFFFF00使用说明：|r")
		print("  /keyword - 打开配置界面")
		print("  /keyword on - 开启监控")
		print("  /keyword off - 关闭监控")
		print("|cffFFFF00主要功能：|r")
		print("  • 关键词分组管理")
		print("  • 预设方案一键应用")
		print("  • 导入/导出配置")
		print("  • 趋势分析和关联分析")
		print("  • 历史记录和快速回复")
		print("|cff00FF00===========================================|r")
	else
		print("|cff00FF00===========================================|r")
		print("|cff00FF00[ChatKeyword]|r 插件已更新！")
		print("|cff00FF00当前版本：|r v" .. currentVersion .. " |cff808080(上次: v" .. lastVersion .. ")|r")
		print("|cff00FF00===========================================|r")
		print("|cffFFFF00v1.7.2 更新内容：|r")
		print("  • 学习 NDui/Recount 等优秀插件的内存管理技巧")
		print("  • 本地化所有全局函数，避免全局查找")
		print("  • 使用 wipe() 清空表而不是创建新表")
		print("  • 优化重复消息缓存为循环队列结构")
		print("  • 避免在循环和频繁调用中创建临时表")
		print("  • 使用增量式GC代替强制GC，避免卡顿")
		print("  • 保留所有原有功能，只优化内存管理")
		print("|cff00FF00===========================================|r")
	end
end

-- 显示关键词消息（优化版 - 减少内存占用）
local function ShowKeywordMessage(self, event, msg, author, ...)
	EnsureConfig()
	if not KeywordMonitorDB.Enabled then return false end
	
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
	
	local timestamp = GetServerTime()
	local timeStr = date("%H:%M", timestamp)
	
	-- 简化频道名称获取
	local channelString = select(2, ...)
	local channelName = "[频道]"
	if channelString and channelString ~= "" then
		local channelText = channelString:match("^%d+%. (.+)$")
		if channelText then
			channelName = "[" .. channelText .. "]"
		end
	end
	
	-- 简化颜色获取
	local coloredName = GetColoredName(event, msg, author, ...)
	local playerLink = GetPlayerLink(author, "["..coloredName.."]")
	
	local r, g, b = 1, 1, 1
	local colorCode = coloredName:match("|cff(%x%x%x%x%x%x)")
	if colorCode then
		r = tonumber(colorCode:sub(1, 2), 16) / 255
		g = tonumber(colorCode:sub(3, 4), 16) / 255
		b = tonumber(colorCode:sub(5, 6), 16) / 255
	end
	
	-- 简化消息处理 - 不进行复杂的表达式替换
	local outMsg = HighlightKeyword(msg, keyword)
	
	-- 构建输出消息
	local output
	if KeywordMonitorDB.OutputMode == 1 then
		output = string.format("|cff808080%s|r |cffFFD700%s|r [|cff00FF00关注|r] %s: %s", timeStr, channelName, playerLink, outMsg)
	else
		output = string.format("|cff808080%s|r |cffFFD700%s|r %s: %s", timeStr, channelName, playerLink, outMsg)
	end
	
	-- 输出消息
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
	
	-- 保存到历史记录（只保存最基本的信息）
	KM:AddToHistory({
		time = timestamp,
		timeStr = timeStr,
		name = name,
		msg = msg,
		channelName = channelName,
		r = r,  -- 保存职业颜色
		g = g,
		b = b,
	})
	
	-- 更新统计数据
	KM:UpdateStatistics(keyword, timestamp)
	
	-- 更新性能统计
	KM:UpdatePerformance()
	
	-- 播放提示音
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
	frame:SetSize(500, 600)
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
	
	-- 版本号和作者
	local versionText = CreateFS(frame, 9, "v1.7.0 by 专业打地鼠", false, "RIGHT")
	versionText:SetPoint("TOPRIGHT", -25, -8)
	versionText:SetTextColor(0.7, 0.7, 0.7)
	
	local closeBtn = CreateCloseButton(frame)
	closeBtn:SetPoint("TOPRIGHT", -10, -10)
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
	
	-- 只在回车或失去焦点时保存
	keywordBox:SetScript("OnEnterPressed", function(self)
		local text = self:GetText()
		KeywordMonitorDB.Keywords = text
		KM:UpdateKeywordList(text)
		self:ClearFocus()
		print("|cff00FF00[ChatKeyword]|r 关键词已更新")
	end)
	
	keywordBox:SetScript("OnEditFocusLost", function(self)
		local text = self:GetText()
		KeywordMonitorDB.Keywords = text
		KM:UpdateKeywordList(text)
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
	
	-- 关键词分组管理按钮
	local groupBtn = CreateButton(frame, 120, 25, "关键词分组")
	groupBtn:SetPoint("TOPLEFT", 20, -320)
	groupBtn:SetScript("OnClick", function()
		KM:ShowKeywordGroupsUI()
	end)
	
	-- 历史记录按钮
	local historyBtn = CreateButton(frame, 120, 25, "历史记录")
	historyBtn:SetPoint("LEFT", groupBtn, "RIGHT", 10, 0)
	historyBtn:SetScript("OnClick", function()
		KM:ShowHistoryUI()
	end)
	
	-- 快速回复按钮
	local quickReplyBtn = CreateButton(frame, 120, 25, "快速回复")
	quickReplyBtn:SetPoint("LEFT", historyBtn, "RIGHT", 10, 0)
	quickReplyBtn:SetScript("OnClick", function()
		KM:ShowQuickReplyUI()
	end)
	
	-- 统计数据按钮
	local statsBtn = CreateButton(frame, 120, 25, "统计数据")
	statsBtn:SetPoint("TOPLEFT", 20, -350)
	statsBtn:SetScript("OnClick", function()
		KM:ShowStatisticsUI()
	end)
	
	-- 性能监控按钮
	local perfBtn = CreateButton(frame, 120, 25, "性能监控")
	perfBtn:SetPoint("LEFT", statsBtn, "RIGHT", 10, 0)
	perfBtn:SetScript("OnClick", function()
		KM:ShowPerformanceUI()
	end)
	
	-- NDui 美化开关（始终可用）
	local nduiCheck = CreateCheckBox(frame)
	nduiCheck:SetPoint("TOPLEFT", 20, -385)
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
	outputLabel:SetPoint("TOPLEFT", 20, -415)
	
	local systemRadio = CreateCheckBox(frame)
	systemRadio:SetPoint("TOPLEFT", 40, -440)
	systemRadio:SetChecked(KeywordMonitorDB.OutputMode == 1)
	local systemLabel = CreateFS(frame, 13, "系统聊天窗口", false, "LEFT")
	systemLabel:SetPoint("LEFT", systemRadio, "RIGHT", 5, 0)
	
	local independentRadio = CreateCheckBox(frame)
	independentRadio:SetPoint("TOPLEFT", 40, -465)
	independentRadio:SetChecked(KeywordMonitorDB.OutputMode == 2)
	local independentLabel = CreateFS(frame, 13, "独立聊天窗口", false, "LEFT")
	independentLabel:SetPoint("LEFT", independentRadio, "RIGHT", 5, 0)
	
	local chatFrameLabel = CreateFS(frame, 13, "输出到聊天窗口", false, "LEFT")
	chatFrameLabel:SetPoint("TOPLEFT", 60, -495)
	
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
	flashCheck:SetPoint("TOPLEFT", 60, -525)
	flashCheck:SetChecked(KeywordMonitorDB.FlashOnMatch)
	local flashLabel = CreateFS(frame, 13, "提取成功窗口标签闪动", false, "LEFT")
	flashLabel:SetPoint("LEFT", flashCheck, "RIGHT", 5, 0)
	
	flashCheck:SetScript("OnClick", function(self)
		local checked = self:GetChecked()
		KeywordMonitorDB.FlashOnMatch = checked
	end)
	
	local combatHideCheck = CreateCheckBox(frame)
	combatHideCheck:SetPoint("TOPLEFT", 60, -550)
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

-- 添加到历史记录
function KM:AddToHistory(record)
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
	if self.historyFrame and self.historyFrame:IsShown() then
		self:RefreshHistoryList()
	end
end

-- 获取历史记录
function KM:GetHistory()
	EnsureConfig()
	return KeywordMonitorDB.History or {}
end

-- 清空历史记录
function KM:ClearHistory()
	EnsureConfig()
	KeywordMonitorDB.History = {}
	print("|cff00FF00[ChatKeyword]|r 历史记录已清空")
	
	-- 如果历史记录界面已打开，实时刷新
	if self.historyFrame and self.historyFrame:IsShown() then
		self:RefreshHistoryList()
	end
end

-- 搜索历史记录
function KM:SearchHistory(searchText)
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

-- 添加快速回复模板
function KM:AddQuickReply(text)
	EnsureConfig()
	if not text or text == "" then return end
	
	-- 检查是否已存在
	for _, reply in ipairs(KeywordMonitorDB.QuickReplies) do
		if reply == text then
			print("|cff00FF00[ChatKeyword]|r 该回复模板已存在")
			return
		end
	end
	
	tinsert(KeywordMonitorDB.QuickReplies, text)
	print("|cff00FF00[ChatKeyword]|r 已添加快速回复: " .. text)
end

-- 删除快速回复模板
function KM:RemoveQuickReply(index)
	EnsureConfig()
	if index and KeywordMonitorDB.QuickReplies[index] then
		local text = KeywordMonitorDB.QuickReplies[index]
		tremove(KeywordMonitorDB.QuickReplies, index)
		print("|cff00FF00[ChatKeyword]|r 已删除快速回复: " .. text)
	end
end

-- 发送快速回复
function KM:SendQuickReply(playerName, replyText)
	if not playerName or not replyText then return end
	
	-- 设置密语目标并发送消息
	ChatFrame_SendTell(playerName)
	
	-- 延迟发送消息，确保密语框已打开
	C_Timer.After(0.1, function()
		local editBox = ChatEdit_ChooseBoxForSend()
		if editBox then
			editBox:SetText(replyText)
			ChatEdit_SendText(editBox)
		end
	end)
end

-- 添加关键词组
function KM:AddKeywordGroup(name, keywords, color)
	EnsureConfig()
	
	local group = {
		name = name or "新分组",
		keywords = keywords or "",
		enabled = true,
		color = color or {math.random(), math.random(), math.random()},
	}
	
	tinsert(KeywordMonitorDB.KeywordGroups, group)
	print("|cff00FF00[ChatKeyword]|r 已添加关键词组: " .. group.name)
	
	return group
end

-- 删除关键词组
function KM:RemoveKeywordGroup(index)
	EnsureConfig()
	if index and KeywordMonitorDB.KeywordGroups[index] then
		local name = KeywordMonitorDB.KeywordGroups[index].name
		tremove(KeywordMonitorDB.KeywordGroups, index)
		print("|cff00FF00[ChatKeyword]|r 已删除关键词组: " .. name)
		-- 删除后更新关键词列表
		KM:UpdateKeywordList()
	else
		print("|cffFF0000[ChatKeyword]|r 删除失败: 无效的索引 " .. tostring(index))
	end
end

-- 更新关键词组
function KM:UpdateKeywordGroup(index, name, keywords, enabled, color)
	EnsureConfig()
	if index and KeywordMonitorDB.KeywordGroups[index] then
		local group = KeywordMonitorDB.KeywordGroups[index]
		if name then group.name = name end
		if keywords ~= nil then group.keywords = keywords end
		if enabled ~= nil then group.enabled = enabled end
		if color then group.color = color end
	end
end

-- 获取所有启用的关键词组
function KM:GetEnabledKeywordGroups()
	EnsureConfig()
	local enabled = {}
	for _, group in ipairs(KeywordMonitorDB.KeywordGroups) do
		if group.enabled then
			tinsert(enabled, group)
		end
	end
	return enabled
end

-- 显示关键词分组管理界面
function KM:ShowKeywordGroupsUI()
	EnsureConfig()
	
	if not self.groupsFrame then
		local frame = CreateFrame("Frame", "KeywordMonitor_GroupsUI", UIParent, "BackdropTemplate")
		frame:SetSize(600, 450)
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
		
		local title = CreateFS(frame, 16, "关键词分组管理", true)
		title:SetPoint("TOP", 0, -10)
		
		local closeBtn = CreateCloseButton(frame)
		closeBtn:SetPoint("TOPRIGHT", -10, -10)
		closeBtn:SetScript("OnClick", function() frame:Hide() end)
		
		-- 使用分组模式开关
		local useGroupCheck = CreateCheckBox(frame)
		useGroupCheck:SetPoint("TOPLEFT", 20, -40)
		useGroupCheck:SetChecked(KeywordMonitorDB.UseKeywordGroups)
		local useGroupLabel = CreateFS(frame, 13, "启用分组模式", false, "LEFT")
		useGroupLabel:SetPoint("LEFT", useGroupCheck, "RIGHT", 5, 0)
		useGroupLabel:SetTextColor(1, 0.8, 0)
		
		useGroupCheck:SetScript("OnClick", function(self)
			local isEnabled = self:GetChecked()
			
			-- 如果从分组模式切换到传统模式，保留传统模式的关键词
			-- 如果从传统模式切换到分组模式，保留分组设置
			KeywordMonitorDB.UseKeywordGroups = isEnabled
			
			-- 更新关键词列表（会根据当前模式自动选择使用分组或传统关键词）
			if isEnabled then
				-- 切换到分组模式
				KM:UpdateKeywordList()
			else
				-- 切换到传统模式，使用保存的传统关键词
				KM:UpdateKeywordList(KeywordMonitorDB.Keywords)
			end
			
			print("|cff00FF00[ChatKeyword]|r 分组模式: " .. (isEnabled and "|cff00FF00已启用|r" or "|cffFF0000已禁用|r"))
		end)
		
		-- 分组列表滚动框
		local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
		scrollFrame:SetPoint("TOPLEFT", 20, -70)
		scrollFrame:SetPoint("BOTTOMRIGHT", -40, 50)
		
		local scrollChild = CreateFrame("Frame", nil, scrollFrame)
		scrollChild:SetSize(540, 1)
		scrollChild.groups = {}  -- 初始化groups表
		scrollFrame:SetScrollChild(scrollChild)
		frame.scrollChild = scrollChild
		
		-- 添加新分组按钮
		local addBtn = CreateButton(frame, 100, 25, "添加分组")
		addBtn:SetPoint("BOTTOMLEFT", 20, 15)
		addBtn:SetScript("OnClick", function()
			KM:AddKeywordGroup("新分组", "")
			KM:RefreshGroupsList()
		end)
		
		-- 预设方案按钮
		local presetBtn = CreateButton(frame, 100, 25, "预设方案")
		presetBtn:SetPoint("LEFT", addBtn, "RIGHT", 10, 0)
		presetBtn:SetScript("OnClick", function()
			KM:ShowPresetsUI()
		end)
		
		-- 导出配置按钮
		local exportBtn = CreateButton(frame, 100, 25, "导出配置")
		exportBtn:SetPoint("LEFT", presetBtn, "RIGHT", 10, 0)
		exportBtn:SetScript("OnClick", function()
			KM:ShowExportUI()
		end)
		
		-- 导入配置按钮
		local importBtn = CreateButton(frame, 100, 25, "导入配置")
		importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 10, 0)
		importBtn:SetScript("OnClick", function()
			KM:ShowImportUI()
		end)
		
		-- 刷新列表函数
		function KM:RefreshGroupsList()
			print("|cffFFFF00[Debug]|r RefreshGroupsList 被调用")
			
			-- 使用保存在frame上的scrollChild
			local scrollChild = self.groupsFrame and self.groupsFrame.scrollChild
			if not scrollChild then
				print("|cffFF0000[ChatKeyword]|r 刷新失败: scrollChild不存在")
				print("|cffFF0000[Debug]|r self.groupsFrame = " .. tostring(self.groupsFrame))
				return
			end
			
			print("|cffFFFF00[Debug]|r scrollChild 存在，开始清理")
			
			-- 确保groups表存在
			if not scrollChild.groups then
				scrollChild.groups = {}
			end
			
			print("|cffFFFF00[Debug]|r 清理前 groups 数量: " .. #scrollChild.groups)
			
			-- 清除旧的UI元素（使用通用清理函数）
			CleanupUIElements(scrollChild.groups)
			scrollChild.groups = {}
			
			print("|cffFFFF00[Debug]|r 清理后，准备重建，分组数量: " .. #KeywordMonitorDB.KeywordGroups)
			
			local yOffset = -10
			for i, group in ipairs(KeywordMonitorDB.KeywordGroups) do
				local groupFrame = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
				groupFrame:SetSize(520, 80)
				groupFrame:SetPoint("TOPLEFT", 10, yOffset)
				
				if KeywordMonitorDB.UseNDuiStyle then
					groupFrame:SetBackdrop({
						bgFile = "Interface\\Buttons\\WHITE8X8",
						edgeFile = "Interface\\Buttons\\WHITE8X8",
						edgeSize = 1,
					})
					groupFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
					groupFrame:SetBackdropBorderColor(0, 0, 0, 1)
				else
					groupFrame:SetBackdrop({
						bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
						edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
						tile = true,
						tileSize = 16,
						edgeSize = 12,
						insets = { left = 2, right = 2, top = 2, bottom = 2 }
					})
					groupFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
				end
				
				-- 使用局部变量保存当前索引，避免闭包问题
				local currentIndex = i
				
				-- 启用复选框
				local enableCheck = CreateCheckBox(groupFrame)
				enableCheck:SetPoint("TOPLEFT", 5, -5)
				enableCheck:SetChecked(group.enabled)
				enableCheck:SetScript("OnClick", function(self)
					KM:UpdateKeywordGroup(currentIndex, nil, nil, self:GetChecked())
					KM:UpdateKeywordList()
				end)
				groupFrame.enableCheck = enableCheck
				
				-- 分组名称
				local nameBox = CreateEditBox(groupFrame, 150, 25)
				nameBox:SetPoint("LEFT", enableCheck, "RIGHT", 5, 0)
				nameBox:SetText(group.name)
				
				-- 只在回车或失去焦点时保存
				nameBox:SetScript("OnEnterPressed", function(self)
					KM:UpdateKeywordGroup(currentIndex, self:GetText())
					self:ClearFocus()
				end)
				
				nameBox:SetScript("OnEditFocusLost", function(self)
					KM:UpdateKeywordGroup(currentIndex, self:GetText())
				end)
				
				groupFrame.nameBox = nameBox
				
				-- 删除按钮
				local delBtn = CreateButton(groupFrame, 50, 20, "删除")
				delBtn:SetPoint("TOPRIGHT", -10, -10)
				delBtn:SetScript("OnClick", function()
					print("|cffFFFF00[Debug]|r 删除按钮被点击，索引: " .. currentIndex)
					print("|cffFFFF00[Debug]|r 删除前分组数量: " .. #KeywordMonitorDB.KeywordGroups)
					KM:RemoveKeywordGroup(currentIndex)
					print("|cffFFFF00[Debug]|r 删除后分组数量: " .. #KeywordMonitorDB.KeywordGroups)
					print("|cffFFFF00[Debug]|r 准备调用 RefreshGroupsList")
					KM:RefreshGroupsList()
					print("|cffFFFF00[Debug]|r RefreshGroupsList 调用完成")
				end)
				groupFrame.delBtn = delBtn
				
				-- 关键词输入框
				local kwLabel = CreateFS(groupFrame, 11, "关键词:", false, "LEFT")
				kwLabel:SetPoint("TOPLEFT", 10, -35)
				
				local kwBox = CreateEditBox(groupFrame, 490, 25)
				kwBox:SetPoint("TOPLEFT", 10, -50)
				kwBox:SetText(group.keywords)
				
				-- 只在回车或失去焦点时保存
				kwBox:SetScript("OnEnterPressed", function(self)
					KM:UpdateKeywordGroup(currentIndex, nil, self:GetText())
					KM:UpdateKeywordList()
					self:ClearFocus()
				end)
				
				kwBox:SetScript("OnEditFocusLost", function(self)
					KM:UpdateKeywordGroup(currentIndex, nil, self:GetText())
					KM:UpdateKeywordList()
				end)
				
				groupFrame.kwBox = kwBox
				
				tinsert(scrollChild.groups, groupFrame)
				yOffset = yOffset - 90
			end
			
			scrollChild:SetHeight(math.max(1, -yOffset))
		end
		
		frame:SetScript("OnShow", function()
			KM:RefreshGroupsList()
		end)
		
		self.groupsFrame = frame
	end
	
	if self.groupsFrame:IsShown() then
		self.groupsFrame:Hide()
	else
		self.groupsFrame:Show()
	end
end

-- 显示历史记录界面
function KM:ShowHistoryUI()
	EnsureConfig()
	
	if not self.historyFrame then
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
				KM:RefreshHistoryList()
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
			KM:ClearHistory()
			KM:RefreshHistoryList()
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
		
		-- 刷新历史记录列表
		function KM:RefreshHistoryList(searchText)
			-- 更新标题显示条数
			local currentCount = #KeywordMonitorDB.History
			local maxCount = KeywordMonitorDB.HistoryMaxCount
			if frame.title then
				frame.title:SetText(string.format("历史记录 (%d/%d)", currentCount, maxCount))
			end
			
			-- 使用保存在frame上的scrollChild
			local scrollChild = self.historyFrame and self.historyFrame.scrollChild
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
			local history = searchText and KM:SearchHistory(searchText) or KM:GetHistory()
			
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
							KM:ShowEditCopyDialog(record)
							lastClickTime = 0  -- 重置
						else
							-- 单击：记录时间，等待可能的第二次点击
							lastClickTime = currentTime
						end
					elseif button == "RightButton" then
						-- 右键：显示快速回复菜单
						KM:ShowQuickReplyForPlayer(record.author or record.name)
					end
				end)
				
				tinsert(scrollChild.records, recordFrame)
				yOffset = yOffset - 65
			end
			
			scrollChild:SetHeight(math.max(1, -yOffset))
		end
		
		searchBtn:SetScript("OnClick", function()
			KM:RefreshHistoryList(searchBox:GetText())
		end)
		
		searchBox:SetScript("OnEnterPressed", function(self)
			KM:RefreshHistoryList(self:GetText())
		end)
		
		frame:SetScript("OnShow", function()
			KM:RefreshHistoryList()
		end)
		
		self.historyFrame = frame
	end
	
	if self.historyFrame:IsShown() then
		self.historyFrame:Hide()
	else
		self.historyFrame:Show()
	end
end

-- 显示快速回复界面
function KM:ShowQuickReplyUI()
	EnsureConfig()
	
	if not self.quickReplyFrame then
		local frame = CreateFrame("Frame", "KeywordMonitor_QuickReplyUI", UIParent, "BackdropTemplate")
		frame:SetSize(400, 350)
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
		
		local title = CreateFS(frame, 16, "快速回复管理", true)
		title:SetPoint("TOP", 0, -10)
		
		local closeBtn = CreateCloseButton(frame)
		closeBtn:SetPoint("TOPRIGHT", -10, -10)
		closeBtn:SetScript("OnClick", function() frame:Hide() end)
		
		-- 添加新回复
		local addLabel = CreateFS(frame, 12, "新回复:", false, "LEFT")
		addLabel:SetPoint("TOPLEFT", 20, -40)
		
		local addBox = CreateEditBox(frame, 250, 25)
		addBox:SetPoint("LEFT", addLabel, "RIGHT", 5, 0)
		
		local addBtn = CreateButton(frame, 60, 25, "添加")
		addBtn:SetPoint("LEFT", addBox, "RIGHT", 5, 0)
		addBtn:SetScript("OnClick", function()
			local text = addBox:GetText()
			if text and text ~= "" then
				KM:AddQuickReply(text)
				addBox:SetText("")
				KM:RefreshQuickReplyList()
			end
		end)
		
		-- 回复列表
		local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
		scrollFrame:SetPoint("TOPLEFT", 20, -75)
		scrollFrame:SetPoint("BOTTOMRIGHT", -40, 20)
		
		local scrollChild = CreateFrame("Frame", nil, scrollFrame)
		scrollChild:SetSize(340, 1)
		scrollFrame:SetScrollChild(scrollChild)
		frame.scrollChild = scrollChild
		
		-- 刷新回复列表
		function KM:RefreshQuickReplyList()
			CleanupUIElements(scrollChild.replies)
			scrollChild.replies = {}
			
			local yOffset = -5
			for i, replyText in ipairs(KeywordMonitorDB.QuickReplies) do
				local replyFrame = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
				replyFrame:SetSize(320, 30)
				replyFrame:SetPoint("TOPLEFT", 5, yOffset)
				
				if KeywordMonitorDB.UseNDuiStyle then
					replyFrame:SetBackdrop({
						bgFile = "Interface\\Buttons\\WHITE8X8",
						edgeFile = "Interface\\Buttons\\WHITE8X8",
						edgeSize = 1,
					})
					replyFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
					replyFrame:SetBackdropBorderColor(0, 0, 0, 1)
				else
					replyFrame:SetBackdrop({
						bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
						edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
						tile = true,
						tileSize = 16,
						edgeSize = 12,
						insets = { left = 2, right = 2, top = 2, bottom = 2 }
					})
					replyFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
				end
				
				local text = CreateFS(replyFrame, 11, replyText, false, "LEFT")
				text:SetPoint("LEFT", 5, 0)
				text:SetPoint("RIGHT", -60, 0)
				
				local delBtn = CreateButton(replyFrame, 50, 20, "删除")
				delBtn:SetPoint("RIGHT", -5, 0)
				delBtn:SetScript("OnClick", function()
					KM:RemoveQuickReply(i)
					KM:RefreshQuickReplyList()
				end)
				
				tinsert(scrollChild.replies, replyFrame)
				yOffset = yOffset - 35
			end
			
			scrollChild:SetHeight(math.max(1, -yOffset))
		end
		
		frame:SetScript("OnShow", function()
			KM:RefreshQuickReplyList()
		end)
		
		self.quickReplyFrame = frame
	end
	
	if self.quickReplyFrame:IsShown() then
		self.quickReplyFrame:Hide()
	else
		self.quickReplyFrame:Show()
	end
end

-- 显示编辑复制对话框
function KM:ShowEditCopyDialog(record)
	-- 创建或复用对话框
	if not self.editCopyDialog then
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
		
		self.editCopyDialog = dialog
	end
	
	-- 更新对话框内容
	local dialog = self.editCopyDialog
	dialog.nameText:SetText(record.name)
	dialog.nameText:SetTextColor(record.r or 1, record.g or 1, record.b or 1)
	dialog.infoLabel:SetText(record.timeStr .. " " .. record.channelName)
	dialog.editBox:SetText(record.msg)
	dialog.editBox:SetCursorPosition(0)
	
	dialog:Show()
end

-- 为特定玩家显示快速回复选择（修复内存泄漏 - 复用Frame）
local quickReplyMenu = nil
function KM:ShowQuickReplyForPlayer(playerName)
	EnsureConfig()
	
	if #KeywordMonitorDB.QuickReplies == 0 then
		print("|cff00FF00[ChatKeyword]|r 请先在快速回复管理中添加回复模板")
		return
	end
	
	-- 如果已存在menu，先清理
	if quickReplyMenu then
		quickReplyMenu:Hide()
		-- 清理所有按钮
		if quickReplyMenu.buttons then
			CleanupUIElements(quickReplyMenu.buttons)
		end
	else
		-- 创建简单的选择菜单（只创建一次）
		quickReplyMenu = CreateFrame("Frame", "KeywordMonitor_QuickReplyMenu", UIParent, "BackdropTemplate")
		quickReplyMenu:SetFrameStrata("TOOLTIP")
		quickReplyMenu:SetFrameLevel(200)
		
		if KeywordMonitorDB.UseNDuiStyle then
			quickReplyMenu:SetBackdrop({
				bgFile = "Interface\\Buttons\\WHITE8X8",
				edgeFile = "Interface\\Buttons\\WHITE8X8",
				edgeSize = 1,
			})
			quickReplyMenu:SetBackdropColor(0, 0, 0, 0.95)
			quickReplyMenu:SetBackdropBorderColor(0, 0, 0, 1)
		else
			quickReplyMenu:SetBackdrop({
				bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
				edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
				tile = true,
				tileSize = 16,
				edgeSize = 12,
				insets = { left = 2, right = 2, top = 2, bottom = 2 }
			})
		end
		
		-- 点击外部关闭
		quickReplyMenu:SetScript("OnHide", function(self)
			-- 取消自动关闭定时器
			if self.autoCloseTimer then
				self.autoCloseTimer:Cancel()
				self.autoCloseTimer = nil
			end
		end)
	end
	
	-- 设置大小和位置
	quickReplyMenu:SetSize(250, 30 * #KeywordMonitorDB.QuickReplies + 10)
	quickReplyMenu:SetPoint("CENTER")
	
	-- 创建按钮
	quickReplyMenu.buttons = {}
	local yOffset = -5
	for i, replyText in ipairs(KeywordMonitorDB.QuickReplies) do
		local btn = CreateButton(quickReplyMenu, 230, 25, replyText)
		btn:SetPoint("TOP", 0, yOffset)
		btn:SetScript("OnClick", function()
			quickReplyMenu:Hide()
			-- 显示二次确认对话框
			KM:ShowQuickReplyConfirmation(playerName, replyText)
		end)
		table.insert(quickReplyMenu.buttons, btn)
		yOffset = yOffset - 30
	end
	
	quickReplyMenu:Show()
	
	-- 3秒后自动关闭
	if quickReplyMenu.autoCloseTimer then
		quickReplyMenu.autoCloseTimer:Cancel()
	end
	quickReplyMenu.autoCloseTimer = C_Timer.NewTimer(3, function()
		if quickReplyMenu and quickReplyMenu:IsShown() then
			quickReplyMenu:Hide()
		end
	end)
end

-- 显示快速回复确认对话框（修复内存泄漏 - 复用Frame）
local quickReplyConfirmFrame = nil
function KM:ShowQuickReplyConfirmation(playerName, replyText)
	if not quickReplyConfirmFrame then
		-- 只创建一次
		quickReplyConfirmFrame = CreateFrame("Frame", "KeywordMonitor_QuickReplyConfirm", UIParent, "BackdropTemplate")
		quickReplyConfirmFrame:SetSize(350, 120)
		quickReplyConfirmFrame:SetFrameStrata("DIALOG")
		quickReplyConfirmFrame:SetFrameLevel(250)
		
		if KeywordMonitorDB.UseNDuiStyle then
			quickReplyConfirmFrame:SetBackdrop({
				bgFile = "Interface\\Buttons\\WHITE8X8",
				edgeFile = "Interface\\Buttons\\WHITE8X8",
				edgeSize = 1,
			})
			quickReplyConfirmFrame:SetBackdropColor(0, 0, 0, 0.95)
			quickReplyConfirmFrame:SetBackdropBorderColor(0, 0, 0, 1)
		else
			quickReplyConfirmFrame:SetBackdrop({
				bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
				edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
				tile = true,
				tileSize = 32,
				edgeSize = 32,
				insets = { left = 11, right = 12, top = 12, bottom = 11 }
			})
		end
		
		quickReplyConfirmFrame.title = CreateFS(quickReplyConfirmFrame, 14, "确认发送", true)
		quickReplyConfirmFrame.title:SetPoint("TOP", 0, -15)
		quickReplyConfirmFrame.title:SetTextColor(1, 0.8, 0)
		
		quickReplyConfirmFrame.message = CreateFS(quickReplyConfirmFrame, 12, "", false, "CENTER")
		quickReplyConfirmFrame.message:SetPoint("TOP", 0, -40)
		
		quickReplyConfirmFrame.replyPreview = CreateFS(quickReplyConfirmFrame, 11, "", false, "CENTER")
		quickReplyConfirmFrame.replyPreview:SetPoint("TOP", 0, -60)
		
		quickReplyConfirmFrame.confirmBtn = CreateButton(quickReplyConfirmFrame, 80, 25, "确定")
		quickReplyConfirmFrame.confirmBtn:SetPoint("BOTTOM", -45, 15)
		
		quickReplyConfirmFrame.cancelBtn = CreateButton(quickReplyConfirmFrame, 80, 25, "取消")
		quickReplyConfirmFrame.cancelBtn:SetPoint("BOTTOM", 45, 15)
		quickReplyConfirmFrame.cancelBtn:SetScript("OnClick", function()
			quickReplyConfirmFrame:Hide()
		end)
	end
	
	-- 更新内容
	quickReplyConfirmFrame.message:SetText(string.format("确定要向 |cffFFFF00%s|r 发送:", playerName))
	quickReplyConfirmFrame.replyPreview:SetText(string.format("|cff00FF00\"%s\"|r", replyText))
	
	-- 更新确定按钮的点击事件
	quickReplyConfirmFrame.confirmBtn:SetScript("OnClick", function()
		KM:SendQuickReply(playerName, replyText)
		quickReplyConfirmFrame:Hide()
		print("|cff00FF00[ChatKeyword]|r 已向 " .. playerName .. " 发送: " .. replyText)
	end)
	
	quickReplyConfirmFrame:SetPoint("CENTER")
	quickReplyConfirmFrame:Show()
end

-- 更新统计数据（优化版 - 避免创建临时表）
function KM:UpdateStatistics(matchedKeywords, timestamp)
	EnsureConfig()
	
	-- 增加今日匹配次数
	KeywordMonitorDB.Statistics.TodayMatches = KeywordMonitorDB.Statistics.TodayMatches + 1
	
	-- 增加总匹配次数
	KeywordMonitorDB.Statistics.TotalMatches = KeywordMonitorDB.Statistics.TotalMatches + 1
	
	-- 记录关键词匹配次数（限制最多50个关键词）
	local keywordCounts = KeywordMonitorDB.Statistics.KeywordCounts
	
	-- 处理单个关键词
	if type(matchedKeywords) == "string" then
		if not keywordCounts[matchedKeywords] then
			-- 检查是否已经有50个关键词
			local count = 0
			for _ in pairs(keywordCounts) do
				count = count + 1
				if count >= 50 then 
					break 
				end
			end
			
			-- 如果已满，删除最少使用的
			if count >= 50 then
				local minKw, minCount = nil, math_huge
				for k, c in pairs(keywordCounts) do
					if c < minCount then
						minKw, minCount = k, c
					end
				end
				if minKw then
					keywordCounts[minKw] = nil
				end
			end
			
			keywordCounts[matchedKeywords] = 0
		end
		keywordCounts[matchedKeywords] = keywordCounts[matchedKeywords] + 1
	end
	
	-- 处理组合关键词
	if type(matchedKeywords) == "table" then
		for i = 1, #matchedKeywords do
			local subKey = matchedKeywords[i]
			if sub(subKey, 1, 1) ~= "&" then
				if not keywordCounts[subKey] then
					local count = 0
					for _ in pairs(keywordCounts) do
						count = count + 1
						if count >= 50 then 
							break 
						end
					end
					
					if count >= 50 then
						local minKw, minCount = nil, math_huge
						for k, c in pairs(keywordCounts) do
							if c < minCount then
								minKw, minCount = k, c
							end
						end
						if minKw then
							keywordCounts[minKw] = nil
						end
					end
					
					keywordCounts[subKey] = 0
				end
				keywordCounts[subKey] = keywordCounts[subKey] + 1
			end
		end
	end
	
	-- 记录小时统计
	local hour = tonumber(date("%H", timestamp))
	local hourCounts = KeywordMonitorDB.Statistics.HourCounts
	if not hourCounts[hour] then
		hourCounts[hour] = 0
	end
	hourCounts[hour] = hourCounts[hour] + 1
	
	-- 更新关联分析数据（轻量级版本）
	if type(matchedKeywords) == "table" then
		KM:UpdateKeywordCorrelation(matchedKeywords)
	end
end

-- 更新趋势数据（优化版 - 减少频繁操作）
local lastTrendCleanup = 0
function KM:UpdateTrendData(keywords, timestamp)
	EnsureConfig()
	
	local dateStr = date("%Y-%m-%d", timestamp)
	local hourStr = date("%Y-%m-%d-%H", timestamp)
	
	-- 更新每日数据
	if not KeywordMonitorDB.TrendData.Daily[dateStr] then
		KeywordMonitorDB.TrendData.Daily[dateStr] = {
			total = 0,
			keywords = {},
		}
	end
	
	KeywordMonitorDB.TrendData.Daily[dateStr].total = KeywordMonitorDB.TrendData.Daily[dateStr].total + 1
	
	-- 限制每日数据的关键词数量（最多保留前20个）
	local dailyKeywords = KeywordMonitorDB.TrendData.Daily[dateStr].keywords
	for _, kw in ipairs(keywords) do
		if not dailyKeywords[kw] then
			-- 检查是否已经有20个关键词
			local count = 0
			for _ in pairs(dailyKeywords) do
				count = count + 1
			end
			
			if count >= 20 then
				-- 找出最少的关键词并删除
				local minKw, minCount = nil, math.huge
				for k, c in pairs(dailyKeywords) do
					if c < minCount then
						minKw, minCount = k, c
					end
				end
				if minKw then
					dailyKeywords[minKw] = nil
				end
			end
			
			dailyKeywords[kw] = 0
		end
		dailyKeywords[kw] = dailyKeywords[kw] + 1
	end
	
	-- 更新每小时数据
	if not KeywordMonitorDB.TrendData.Hourly[hourStr] then
		KeywordMonitorDB.TrendData.Hourly[hourStr] = {
			total = 0,
			keywords = {},
		}
	end
	
	KeywordMonitorDB.TrendData.Hourly[hourStr].total = KeywordMonitorDB.TrendData.Hourly[hourStr].total + 1
	
	-- 限制每小时数据的关键词数量（最多保留前10个）
	local hourlyKeywords = KeywordMonitorDB.TrendData.Hourly[hourStr].keywords
	for _, kw in ipairs(keywords) do
		if not hourlyKeywords[kw] then
			local count = 0
			for _ in pairs(hourlyKeywords) do
				count = count + 1
			end
			
			if count >= 10 then
				local minKw, minCount = nil, math.huge
				for k, c in pairs(hourlyKeywords) do
					if c < minCount then
						minKw, minCount = k, c
					end
				end
				if minKw then
					hourlyKeywords[minKw] = nil
				end
			end
			
			hourlyKeywords[kw] = 0
		end
		hourlyKeywords[kw] = hourlyKeywords[kw] + 1
	end
	
	-- 只在每小时清理一次旧数据，而不是每条消息都清理
	local currentTime = GetTime()
	if currentTime - lastTrendCleanup > 3600 then
		lastTrendCleanup = currentTime
		
		local serverTime = GetServerTime()
		-- 清理旧的小时数据（保留最近48小时）
		for hourKey, _ in pairs(KeywordMonitorDB.TrendData.Hourly) do
			local year, month, day, hour = hourKey:match("(%d+)-(%d+)-(%d+)-(%d+)")
			if year and month and day and hour then
				local dataTime = time({year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = tonumber(hour), min = 0, sec = 0})
				if serverTime - dataTime > 48 * 3600 then
					KeywordMonitorDB.TrendData.Hourly[hourKey] = nil
				end
			end
		end
		
		-- 清理超过30天的每日数据
		for dateKey, _ in pairs(KeywordMonitorDB.TrendData.Daily) do
			local year, month, day = dateKey:match("(%d+)-(%d+)-(%d+)")
			if year and month and day then
				local dataTime = time({year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = 0, min = 0, sec = 0})
				if serverTime - dataTime > 30 * 86400 then
					KeywordMonitorDB.TrendData.Daily[dateKey] = nil
				end
			end
		end
		
		-- 对于7-30天的数据，只保留总数，删除关键词明细
		for dateKey, data in pairs(KeywordMonitorDB.TrendData.Daily) do
			local year, month, day = dateKey:match("(%d+)-(%d+)-(%d+)")
			if year and month and day then
				local dataTime = time({year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = 0, min = 0, sec = 0})
				if serverTime - dataTime > 7 * 86400 and serverTime - dataTime <= 30 * 86400 then
					-- 只保留总数
					data.keywords = {}
				end
			end
		end
	end
end

-- 更新关键词关联（优化版 - 减少频繁检查）
local lastCorrelationCleanup = 0
local correlationUpdateCount = 0
function KM:UpdateKeywordCorrelation(keywords)
	EnsureConfig()
	
	-- 如果只有一个关键词，无需记录关联
	if #keywords < 2 then return end
	
	correlationUpdateCount = correlationUpdateCount + 1
	
	-- 只在每100次更新后检查一次大小，而不是每次都检查
	if correlationUpdateCount >= 100 then
		correlationUpdateCount = 0
		
		-- 限制关联表大小 - 更激进的限制
		local totalCorrelations = 0
		for kw1, correlations in pairs(KeywordMonitorDB.KeywordCorrelation) do
			totalCorrelations = totalCorrelations + KM:GetTableSize(correlations)
		end
		
		-- 如果总关联数超过100，清理低频数据
		if totalCorrelations > 100 then
			for kw1, correlations in pairs(KeywordMonitorDB.KeywordCorrelation) do
				for kw2, count in pairs(correlations) do
					-- 清理关联次数<5的数据（更严格）
					if count < 5 then
						correlations[kw2] = nil
					end
				end
				-- 如果该关键词没有关联了，删除整个条目
				if KM:GetTableSize(correlations) == 0 then
					KeywordMonitorDB.KeywordCorrelation[kw1] = nil
				end
			end
		end
	end
	
	-- 记录每对关键词的关联
	for i = 1, #keywords do
		local kw1 = keywords[i]
		
		if not KeywordMonitorDB.KeywordCorrelation[kw1] then
			KeywordMonitorDB.KeywordCorrelation[kw1] = {}
		end
		
		-- 限制每个关键词最多10个关联
		local correlations = KeywordMonitorDB.KeywordCorrelation[kw1]
		local correlationCount = KM:GetTableSize(correlations)
		
		for j = 1, #keywords do
			if i ~= j then
				local kw2 = keywords[j]
				
				if not correlations[kw2] then
					-- 如果已经有10个关联，删除最少的
					if correlationCount >= 10 then
						local minKw, minCount = nil, math.huge
						for k, c in pairs(correlations) do
							if c < minCount then
								minKw, minCount = k, c
							end
						end
						if minKw then
							correlations[minKw] = nil
						end
					else
						correlationCount = correlationCount + 1
					end
					
					correlations[kw2] = 0
				end
				
				correlations[kw2] = correlations[kw2] + 1
			end
		end
	end
end

-- 获取关键词趋势（最近N天）
function KM:GetKeywordTrend(keyword, days)
	EnsureConfig()
	days = days or 7
	
	local trend = {}
	local currentTime = GetServerTime()
	
	for i = days - 1, 0, -1 do
		local targetTime = currentTime - i * 86400
		local dateStr = date("%Y-%m-%d", targetTime)
		
		local count = 0
		if KeywordMonitorDB.TrendData.Daily[dateStr] and KeywordMonitorDB.TrendData.Daily[dateStr].keywords[keyword] then
			count = KeywordMonitorDB.TrendData.Daily[dateStr].keywords[keyword]
		end
		
		tinsert(trend, {
			date = dateStr,
			count = count,
		})
	end
	
	return trend
end

-- 获取关键词关联（Top N）
function KM:GetKeywordCorrelations(keyword, topN)
	EnsureConfig()
	topN = topN or 5
	
	if not KeywordMonitorDB.KeywordCorrelation[keyword] then
		return {}
	end
	
	local correlations = {}
	for relatedKw, count in pairs(KeywordMonitorDB.KeywordCorrelation[keyword]) do
		tinsert(correlations, {
			keyword = relatedKw,
			count = count,
		})
	end
	
	-- 按关联次数排序
	table.sort(correlations, function(a, b) return a.count > b.count end)
	
	-- 返回前N个
	local result = {}
	for i = 1, math.min(topN, #correlations) do
		tinsert(result, correlations[i])
	end
	
	return result
end

-- 获取热度变化趋势（最近N天的总体趋势）
function KM:GetOverallTrend(days)
	EnsureConfig()
	days = days or 7
	
	local trend = {}
	local currentTime = GetServerTime()
	
	for i = days - 1, 0, -1 do
		local targetTime = currentTime - i * 86400
		local dateStr = date("%Y-%m-%d", targetTime)
		
		local count = 0
		if KeywordMonitorDB.TrendData.Daily[dateStr] then
			count = KeywordMonitorDB.TrendData.Daily[dateStr].total
		end
		
		tinsert(trend, {
			date = dateStr,
			count = count,
		})
	end
	
	return trend
end

-- 获取统计数据
function KM:GetStatistics()
	EnsureConfig()
	return KeywordMonitorDB.Statistics
end

-- 重置统计数据
function KM:ResetStatistics()
	EnsureConfig()
	KeywordMonitorDB.Statistics = {
		TodayMatches = 0,
		LastResetDate = date("%Y-%m-%d", GetServerTime()),
		KeywordCounts = {},
		HourCounts = {},
		TotalMatches = 0,
	}
	for i = 0, 23 do
		KeywordMonitorDB.Statistics.HourCounts[i] = 0
	end
	print("|cff00FF00[ChatKeyword]|r 统计数据已重置")
end

-- 获取表大小
function KM:GetTableSize(t)
	local count = 0
	for _ in pairs(t) do
		count = count + 1
	end
	return count
end

-- 诊断内存占用
function KM:DiagnoseMemory()
	EnsureConfig()
	
	print("|cff00FF00[ChatKeyword 内存诊断]|r")
	print("----------------------------------------")
	
	-- 历史记录
	local historyCount = #KeywordMonitorDB.History
	print(string.format("历史记录: %d 条", historyCount))
	
	-- 趋势数据
	local dailyCount = KM:GetTableSize(KeywordMonitorDB.TrendData.Daily)
	local hourlyCount = KM:GetTableSize(KeywordMonitorDB.TrendData.Hourly)
	print(string.format("趋势数据: 每日 %d 天, 每小时 %d 条", dailyCount, hourlyCount))
	
	-- 关键词关联
	local correlationCount = 0
	for kw1, correlations in pairs(KeywordMonitorDB.KeywordCorrelation) do
		correlationCount = correlationCount + KM:GetTableSize(correlations)
	end
	print(string.format("关键词关联: %d 条关联", correlationCount))
	
	-- 统计数据
	local keywordStatsCount = KM:GetTableSize(KeywordMonitorDB.Statistics.KeywordCounts)
	print(string.format("统计数据: %d 个关键词", keywordStatsCount))
	
	-- 重复消息缓存
	local cacheCount = KM:GetTableSize(repeatMessageCache)
	print(string.format("重复消息缓存: %d 条", cacheCount))
	
	print("----------------------------------------")
	print("|cffFFFF00建议：|r")
	if historyCount > 50 then
		print("  • 历史记录较多，可减少保留数量")
	end
	if correlationCount > 200 then
		print("  • 关键词关联数据过多，建议清理")
	end
	print("  • 点击'优化内存'按钮进行清理")
end

-- 获取最常匹配的关键词（前N个）
function KM:GetTopKeywords(count)
	EnsureConfig()
	count = count or 10
	
	local list = {}
	for keyword, matchCount in pairs(KeywordMonitorDB.Statistics.KeywordCounts) do
		tinsert(list, {keyword = keyword, count = matchCount})
	end
	
	-- 按匹配次数排序
	table.sort(list, function(a, b) return a.count > b.count end)
	
	-- 返回前N个
	local result = {}
	for i = 1, math.min(count, #list) do
		tinsert(result, list[i])
	end
	
	return result
end

-- 获取最活跃的时间段（前N个）
function KM:GetTopHours(count)
	EnsureConfig()
	count = count or 5
	
	local list = {}
	for hour = 0, 23 do
		local matchCount = KeywordMonitorDB.Statistics.HourCounts[hour] or 0
		tinsert(list, {hour = hour, count = matchCount})
	end
	
	-- 按匹配次数排序
	table.sort(list, function(a, b) return a.count > b.count end)
	
	-- 返回前N个
	local result = {}
	for i = 1, math.min(count, #list) do
		tinsert(result, list[i])
	end
	
	return result
end

-- 显示统计界面
function KM:ShowStatisticsUI()
	EnsureConfig()
	
	if not self.statisticsFrame then
		local frame = CreateFrame("Frame", "KeywordMonitor_StatisticsUI", UIParent, "BackdropTemplate")
		frame:SetSize(600, 500)
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
		
		local title = CreateFS(frame, 16, "统计数据", true)
		title:SetPoint("TOP", 0, -10)
		
		local closeBtn = CreateCloseButton(frame)
		closeBtn:SetPoint("TOPRIGHT", -10, -10)
		closeBtn:SetScript("OnClick", function() frame:Hide() end)
		
		-- 今日匹配次数
		local todayLabel = CreateFS(frame, 14, "今日匹配次数:", false, "LEFT")
		todayLabel:SetPoint("TOPLEFT", 20, -50)
		todayLabel:SetTextColor(1, 0.8, 0)
		
		local todayValue = CreateFS(frame, 20, "0", true, "LEFT")
		todayValue:SetPoint("LEFT", todayLabel, "RIGHT", 10, 0)
		todayValue:SetTextColor(0, 1, 0)
		frame.todayValue = todayValue
		
		-- 总匹配次数
		local totalLabel = CreateFS(frame, 12, "总匹配次数:", false, "LEFT")
		totalLabel:SetPoint("TOPLEFT", 20, -80)
		totalLabel:SetTextColor(0.7, 0.7, 0.7)
		
		local totalValue = CreateFS(frame, 14, "0", false, "LEFT")
		totalValue:SetPoint("LEFT", totalLabel, "RIGHT", 10, 0)
		totalValue:SetTextColor(0.5, 0.8, 1)
		frame.totalValue = totalValue
		
		-- 最常匹配的关键词
		local topKeywordsLabel = CreateFS(frame, 14, "最常匹配的关键词 (Top 10):", false, "LEFT")
		topKeywordsLabel:SetPoint("TOPLEFT", 20, -110)
		topKeywordsLabel:SetTextColor(1, 0.8, 0)
		
		local keywordsScrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
		keywordsScrollFrame:SetPoint("TOPLEFT", 20, -135)
		keywordsScrollFrame:SetSize(260, 180)
		
		local keywordsScrollChild = CreateFrame("Frame", nil, keywordsScrollFrame)
		keywordsScrollChild:SetSize(240, 1)
		keywordsScrollFrame:SetScrollChild(keywordsScrollChild)
		frame.keywordsScrollChild = keywordsScrollChild
		
		-- 最活跃的时间段
		local topHoursLabel = CreateFS(frame, 14, "最活跃的时间段 (Top 10):", false, "LEFT")
		topHoursLabel:SetPoint("TOPLEFT", 310, -110)
		topHoursLabel:SetTextColor(1, 0.8, 0)
		
		local hoursScrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
		hoursScrollFrame:SetPoint("TOPLEFT", 310, -135)
		hoursScrollFrame:SetSize(260, 180)
		
		local hoursScrollChild = CreateFrame("Frame", nil, hoursScrollFrame)
		hoursScrollChild:SetSize(240, 1)
		hoursScrollFrame:SetScrollChild(hoursScrollChild)
		frame.hoursScrollChild = hoursScrollChild
		
		-- 时间段分布图（简单的文本条形图）
		local chartLabel = CreateFS(frame, 14, "24小时分布图:", false, "LEFT")
		chartLabel:SetPoint("TOPLEFT", 20, -330)
		chartLabel:SetTextColor(1, 0.8, 0)
		
		local chartFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
		chartFrame:SetPoint("TOPLEFT", 20, -355)
		chartFrame:SetSize(560, 100)
		
		if KeywordMonitorDB.UseNDuiStyle then
			chartFrame:SetBackdrop({
				bgFile = "Interface\\Buttons\\WHITE8X8",
				edgeFile = "Interface\\Buttons\\WHITE8X8",
				edgeSize = 1,
			})
			chartFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
			chartFrame:SetBackdropBorderColor(0, 0, 0, 1)
		else
			chartFrame:SetBackdrop({
				bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
				edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
				tile = true,
				tileSize = 16,
				edgeSize = 12,
				insets = { left = 2, right = 2, top = 2, bottom = 2 }
			})
			chartFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
		end
		
		frame.chartFrame = chartFrame
		frame.chartBars = {}
		
		-- 创建24个柱状图
		for i = 0, 23 do
			local bar = CreateFrame("Frame", nil, chartFrame, "BackdropTemplate")
			bar:SetSize(20, 1)
			bar:SetPoint("BOTTOMLEFT", 10 + i * 23, 5)
			bar:SetBackdrop({
				bgFile = "Interface\\Buttons\\WHITE8X8",
			})
			bar:SetBackdropColor(0, 0.8, 0, 0.8)
			
			local hourLabel = CreateFS(bar, 9, tostring(i), false, "CENTER")
			hourLabel:SetPoint("BOTTOM", bar, "TOP", 0, 2)
			hourLabel:SetTextColor(0.7, 0.7, 0.7)
			
			bar.hourLabel = hourLabel
			frame.chartBars[i] = bar
		end
		
		-- 重置按钮
		local resetBtn = CreateButton(frame, 100, 25, "重置统计")
		resetBtn:SetPoint("BOTTOMLEFT", 20, 15)
		resetBtn:SetScript("OnClick", function()
			KM:ResetStatistics()
			KM:RefreshStatistics()
		end)
		
		-- 趋势分析按钮
		local trendBtn = CreateButton(frame, 100, 25, "趋势分析")
		trendBtn:SetPoint("BOTTOM", -55, 15)
		trendBtn:SetScript("OnClick", function()
			KM:ShowTrendAnalysisUI()
		end)
		
		-- 关联分析按钮
		local correlationBtn = CreateButton(frame, 100, 25, "关联分析")
		correlationBtn:SetPoint("BOTTOM", 55, 15)
		correlationBtn:SetScript("OnClick", function()
			KM:ShowCorrelationAnalysisUI()
		end)
		
		-- 刷新统计数据
		function KM:RefreshStatistics()
			local stats = KM:GetStatistics()
			
			-- 更新今日和总匹配次数
			frame.todayValue:SetText(tostring(stats.TodayMatches))
			frame.totalValue:SetText(tostring(stats.TotalMatches))
			
			-- 更新最常匹配的关键词
			CleanupUIElements(frame.keywordsScrollChild.items)
			frame.keywordsScrollChild.items = {}
			
			local topKeywords = KM:GetTopKeywords(10)
			local yOffset = -5
			for i, data in ipairs(topKeywords) do
				local item = CreateFS(frame.keywordsScrollChild, 11, 
					string.format("%d. %s (%d次)", i, data.keyword, data.count), 
					false, "LEFT")
				item:SetPoint("TOPLEFT", 5, yOffset)
				item:SetTextColor(0.9, 0.9, 0.9)
				tinsert(frame.keywordsScrollChild.items, item)
				yOffset = yOffset - 18
			end
			frame.keywordsScrollChild:SetHeight(math.max(1, -yOffset))
			
			-- 更新最活跃的时间段
			CleanupUIElements(frame.hoursScrollChild.items)
			frame.hoursScrollChild.items = {}
			
			local topHours = KM:GetTopHours(10)
			yOffset = -5
			for i, data in ipairs(topHours) do
				local item = CreateFS(frame.hoursScrollChild, 11, 
					string.format("%d. %02d:00-%02d:59 (%d次)", i, data.hour, data.hour, data.count), 
					false, "LEFT")
				item:SetPoint("TOPLEFT", 5, yOffset)
				item:SetTextColor(0.9, 0.9, 0.9)
				tinsert(frame.hoursScrollChild.items, item)
				yOffset = yOffset - 18
			end
			frame.hoursScrollChild:SetHeight(math.max(1, -yOffset))
			
			-- 更新24小时分布图
			local maxCount = 0
			for hour = 0, 23 do
				local count = stats.HourCounts[hour] or 0
				if count > maxCount then
					maxCount = count
				end
			end
			
			for hour = 0, 23 do
				local count = stats.HourCounts[hour] or 0
				local bar = frame.chartBars[hour]
				if bar then
					local height = maxCount > 0 and (count / maxCount * 70) or 1
					bar:SetHeight(math.max(1, height))
					
					-- 根据匹配次数设置颜色
					if count == 0 then
						bar:SetBackdropColor(0.2, 0.2, 0.2, 0.5)
					elseif count < maxCount * 0.3 then
						bar:SetBackdropColor(0, 0.5, 0, 0.8)
					elseif count < maxCount * 0.7 then
						bar:SetBackdropColor(0.8, 0.8, 0, 0.8)
					else
						bar:SetBackdropColor(0.8, 0, 0, 0.8)
					end
				end
			end
		end
		
		frame:SetScript("OnShow", function()
			KM:RefreshStatistics()
		end)
		
		self.statisticsFrame = frame
	end
	
	if self.statisticsFrame:IsShown() then
		self.statisticsFrame:Hide()
	else
		self.statisticsFrame:Show()
	end
end

-- 内置预设方案
local builtinPresets = {
	{
		name = "经典副本组队",
		description = "监控MC、BWL、TAQ等经典副本组队信息",
		groups = {
			{name = "熔火之心", keywords = "MC,熔火", enabled = true, color = {1, 0.3, 0}},
			{name = "黑翼之巢", keywords = "BWL,黑翼", enabled = true, color = {0.3, 0.3, 0.3}},
			{name = "安其拉", keywords = "TAQ,AQL,安其拉", enabled = true, color = {0.8, 0.8, 0}},
			{name = "纳克萨玛斯", keywords = "NAXX,纳克", enabled = true, color = {0, 1, 0}},
		},
		quickReplies = {"有位置吗？", "什么职业？", "还缺几个？"},
	},
	{
		name = "G团猎人",
		description = "专为猎人设计的G团关键词",
		groups = {
			{name = "猎人G团", keywords = "G团+LR,G团+猎人", enabled = true, color = {0, 1, 0}},
			{name = "猎人装备", keywords = "敏捷,命中,远程", enabled = true, color = {1, 0.5, 0}},
		},
		quickReplies = {"猎人来", "装备怎么分？", "多少金？"},
	},
	{
		name = "材料商人",
		description = "监控材料买卖信息",
		groups = {
			{name = "收购", keywords = "收,收购,WTB", enabled = true, color = {0, 0.8, 1}},
			{name = "出售", keywords = "出,出售,WTS", enabled = true, color = {1, 0.8, 0}},
			{name = "常见材料", keywords = "布,皮,矿,药", enabled = true, color = {0.5, 1, 0.5}},
		},
		quickReplies = {"什么价格？", "还有吗？", "在哪交易？"},
	},
	{
		name = "日常任务",
		description = "监控日常任务和声望相关",
		groups = {
			{name = "日常", keywords = "日常,任务", enabled = true, color = {1, 1, 0}},
			{name = "声望", keywords = "声望,崇拜,崇敬", enabled = true, color = {0.8, 0, 0.8}},
		},
		quickReplies = {"一起做吗？", "在哪？", "组我"},
	},
	{
		name = "PVP战场",
		description = "监控战场和PVP相关",
		groups = {
			{name = "战场", keywords = "战场,AV,AB,WSG", enabled = true, color = {1, 0, 0}},
			{name = "竞技场", keywords = "竞技场,JJC", enabled = true, color = {0.8, 0.4, 0}},
		},
		quickReplies = {"组我", "什么段位？", "来"},
	},
}

-- 应用预设方案
function KM:ApplyPreset(preset)
	EnsureConfig()
	
	if not preset then return end
	
	-- 清空现有分组
	KeywordMonitorDB.KeywordGroups = {}
	
	-- 应用预设的分组
	if preset.groups then
		for _, group in ipairs(preset.groups) do
			tinsert(KeywordMonitorDB.KeywordGroups, {
				name = group.name,
				keywords = group.keywords,
				enabled = group.enabled,
				color = group.color or {math.random(), math.random(), math.random()},
			})
		end
	end
	
	-- 应用快速回复
	if preset.quickReplies then
		KeywordMonitorDB.QuickReplies = {}
		for _, reply in ipairs(preset.quickReplies) do
			tinsert(KeywordMonitorDB.QuickReplies, reply)
		end
	end
	
	-- 启用分组模式
	KeywordMonitorDB.UseKeywordGroups = true
	
	-- 更新关键词列表
	KM:UpdateKeywordList()
	
	print("|cff00FF00[ChatKeyword]|r 已应用预设方案: " .. preset.name)
end

-- 保存当前配置为预设
function KM:SaveAsPreset(name, description)
	EnsureConfig()
	
	if not name or name == "" then
		print("|cff00FF00[ChatKeyword]|r 请输入预设方案名称")
		return
	end
	
	local preset = {
		name = name,
		description = description or "",
		groups = {},
		quickReplies = {},
	}
	
	-- 保存当前分组
	for _, group in ipairs(KeywordMonitorDB.KeywordGroups) do
		tinsert(preset.groups, {
			name = group.name,
			keywords = group.keywords,
			enabled = group.enabled,
			color = group.color,
		})
	end
	
	-- 保存快速回复
	for _, reply in ipairs(KeywordMonitorDB.QuickReplies) do
		tinsert(preset.quickReplies, reply)
	end
	
	-- 添加到用户预设
	tinsert(KeywordMonitorDB.Presets, preset)
	
	print("|cff00FF00[ChatKeyword]|r 已保存预设方案: " .. name)
end

-- 删除预设方案
function KM:DeletePreset(index)
	EnsureConfig()
	
	if index and KeywordMonitorDB.Presets[index] then
		local name = KeywordMonitorDB.Presets[index].name
		tremove(KeywordMonitorDB.Presets, index)
		print("|cff00FF00[ChatKeyword]|r 已删除预设方案: " .. name)
	end
end

-- 导出配置（Base64编码）
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

-- 导入配置
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
	KM:UpdateKeywordList()
	
	print("|cff00FF00[ChatKeyword]|r 配置导入成功")
	return true
end

-- 简单的序列化函数
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

-- 简单的反序列化函数
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

-- Base64编码表
local base64Chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

-- Base64编码
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

-- Base64解码
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

-- 设置时间触发
function KM:SetTimeTrigger(groupIndex, startHour, endHour)
	EnsureConfig()
	
	if not groupIndex or not startHour or not endHour then return end
	
	KeywordMonitorDB.TimeTriggers[groupIndex] = {
		startHour = startHour,
		endHour = endHour,
	}
	
	print("|cff00FF00[ChatKeyword]|r 已设置时间触发: " .. startHour .. ":00 - " .. endHour .. ":59")
end

-- 移除时间触发
function KM:RemoveTimeTrigger(groupIndex)
	EnsureConfig()
	
	if KeywordMonitorDB.TimeTriggers[groupIndex] then
		KeywordMonitorDB.TimeTriggers[groupIndex] = nil
		print("|cff00FF00[ChatKeyword]|r 已移除时间触发")
	end
end

-- 检查并应用时间触发
function KM:CheckTimeTriggers()
	EnsureConfig()
	
	local currentHour = tonumber(date("%H", GetServerTime()))
	
	for groupIndex, trigger in pairs(KeywordMonitorDB.TimeTriggers) do
		if KeywordMonitorDB.KeywordGroups[groupIndex] then
			local group = KeywordMonitorDB.KeywordGroups[groupIndex]
			local shouldEnable = false
			
			if trigger.startHour <= trigger.endHour then
				-- 正常时间段，如 8:00 - 22:00
				shouldEnable = currentHour >= trigger.startHour and currentHour <= trigger.endHour
			else
				-- 跨天时间段，如 22:00 - 2:00
				shouldEnable = currentHour >= trigger.startHour or currentHour <= trigger.endHour
			end
			
			if group.enabled ~= shouldEnable then
				group.enabled = shouldEnable
				KM:UpdateKeywordList()
			end
		end
	end
end

-- 显示预设方案界面
function KM:ShowPresetsUI()
	EnsureConfig()
	
	if not self.presetsFrame then
		local frame = CreateFrame("Frame", "KeywordMonitor_PresetsUI", UIParent, "BackdropTemplate")
		frame:SetSize(600, 500)
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
		
		local title = CreateFS(frame, 16, "预设方案", true)
		title:SetPoint("TOP", 0, -10)
		
		local closeBtn = CreateCloseButton(frame)
		closeBtn:SetPoint("TOPRIGHT", -10, -10)
		closeBtn:SetScript("OnClick", function() frame:Hide() end)
		
		-- 说明
		local desc = CreateFS(frame, 11, "选择预设方案快速配置关键词组合", false, "LEFT")
		desc:SetPoint("TOPLEFT", 20, -40)
		desc:SetTextColor(0.7, 0.7, 0.7)
		
		-- 内置预设
		local builtinLabel = CreateFS(frame, 14, "内置预设方案:", false, "LEFT")
		builtinLabel:SetPoint("TOPLEFT", 20, -65)
		builtinLabel:SetTextColor(1, 0.8, 0)
		
		local builtinScroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
		builtinScroll:SetPoint("TOPLEFT", 20, -90)
		builtinScroll:SetSize(560, 180)
		
		local builtinChild = CreateFrame("Frame", nil, builtinScroll)
		builtinChild:SetSize(540, 1)
		builtinScroll:SetScrollChild(builtinChild)
		frame.builtinChild = builtinChild
		
		-- 用户预设
		local userLabel = CreateFS(frame, 14, "我的预设方案:", false, "LEFT")
		userLabel:SetPoint("TOPLEFT", 20, -280)
		userLabel:SetTextColor(1, 0.8, 0)
		
		local userScroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
		userScroll:SetPoint("TOPLEFT", 20, -305)
		userScroll:SetSize(560, 140)
		
		local userChild = CreateFrame("Frame", nil, userScroll)
		userChild:SetSize(540, 1)
		userScroll:SetScrollChild(userChild)
		frame.userChild = userChild
		
		-- 保存当前配置为预设
		local saveLabel = CreateFS(frame, 12, "保存当前配置:", false, "LEFT")
		saveLabel:SetPoint("BOTTOMLEFT", 20, 45)
		
		local saveNameBox = CreateEditBox(frame, 200, 25)
		saveNameBox:SetPoint("LEFT", saveLabel, "RIGHT", 5, 0)
		
		-- 支持回车键保存
		saveNameBox:SetScript("OnEnterPressed", function(self)
			local name = self:GetText()
			if name and name ~= "" then
				KM:SaveAsPreset(name, "")
				self:SetText("")
				KM:RefreshPresetsList()
				self:ClearFocus()
			end
		end)
		
		local saveBtn = CreateButton(frame, 60, 25, "保存")
		saveBtn:SetPoint("LEFT", saveNameBox, "RIGHT", 5, 0)
		saveBtn:SetScript("OnClick", function()
			local name = saveNameBox:GetText()
			if name and name ~= "" then
				KM:SaveAsPreset(name, "")
				saveNameBox:SetText("")
				KM:RefreshPresetsList()
			end
		end)
		
		-- 刷新预设列表
		function KM:RefreshPresetsList()
			-- 使用保存在frame上的child
			local builtinChild = self.presetsFrame.builtinChild
			local userChild = self.presetsFrame.userChild
			
			if not builtinChild or not userChild then
				print("|cffFF0000[ChatKeyword]|r 刷新失败: child不存在")
				return
			end
			
			-- 初始化items表（如果不存在）
			if not builtinChild.items then
				builtinChild.items = {}
			end
			if not userChild.items then
				userChild.items = {}
			end
			
			-- 清空内置预设
			CleanupUIElements(builtinChild.items)
			builtinChild.items = {}
			
			local yOffset = -5
			for i, preset in ipairs(builtinPresets) do
				local itemFrame = CreateFrame("Frame", nil, builtinChild, "BackdropTemplate")
				itemFrame:SetSize(520, 60)
				itemFrame:SetPoint("TOPLEFT", 10, yOffset)
				
				if KeywordMonitorDB.UseNDuiStyle then
					itemFrame:SetBackdrop({
						bgFile = "Interface\\Buttons\\WHITE8X8",
						edgeFile = "Interface\\Buttons\\WHITE8X8",
						edgeSize = 1,
					})
					itemFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.7)
					itemFrame:SetBackdropBorderColor(0, 0, 0, 1)
				else
					itemFrame:SetBackdrop({
						bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
						edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
						tile = true,
						tileSize = 16,
						edgeSize = 12,
						insets = { left = 2, right = 2, top = 2, bottom = 2 }
					})
					itemFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.7)
				end
				
				local nameText = CreateFS(itemFrame, 13, preset.name, true, "LEFT")
				nameText:SetPoint("TOPLEFT", 10, -8)
				nameText:SetTextColor(1, 0.8, 0)
				
				local descText = CreateFS(itemFrame, 10, preset.description, false, "LEFT")
				descText:SetPoint("TOPLEFT", 10, -25)
				descText:SetPoint("RIGHT", -80, 0)
				descText:SetTextColor(0.7, 0.7, 0.7)
				
				local applyBtn = CreateButton(itemFrame, 60, 25, "应用")
				applyBtn:SetPoint("TOPRIGHT", -10, -10)
				applyBtn:SetScript("OnClick", function()
					KM:ApplyPreset(preset)
					self.presetsFrame:Hide()
					if self.groupsFrame then
						self.groupsFrame:Hide()
						C_Timer.After(0.1, function()
							self.groupsFrame:Show()
						end)
					end
				end)
				
				tinsert(builtinChild.items, itemFrame)
				yOffset = yOffset - 65
			end
			builtinChild:SetHeight(math.max(1, -yOffset))
			
			-- 清空用户预设
			CleanupUIElements(userChild.items)
			userChild.items = {}
			
			if #KeywordMonitorDB.Presets == 0 then
				local noData = CreateFS(userChild, 11, "暂无自定义预设，保存当前配置创建预设", false, "CENTER")
				noData:SetPoint("TOP", 0, -30)
				noData:SetTextColor(0.5, 0.5, 0.5)
				tinsert(userChild.items, noData)
				userChild:SetHeight(1)
			else
				yOffset = -5
				for i, preset in ipairs(KeywordMonitorDB.Presets) do
					local itemFrame = CreateFrame("Frame", nil, userChild, "BackdropTemplate")
					itemFrame:SetSize(520, 50)
					itemFrame:SetPoint("TOPLEFT", 10, yOffset)
					
					if KeywordMonitorDB.UseNDuiStyle then
						itemFrame:SetBackdrop({
							bgFile = "Interface\\Buttons\\WHITE8X8",
							edgeFile = "Interface\\Buttons\\WHITE8X8",
							edgeSize = 1,
						})
						itemFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.7)
						itemFrame:SetBackdropBorderColor(0, 0, 0, 1)
					else
						itemFrame:SetBackdrop({
							bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
							edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
							tile = true,
							tileSize = 16,
							edgeSize = 12,
							insets = { left = 2, right = 2, top = 2, bottom = 2 }
						})
						itemFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.7)
					end
					
					local nameText = CreateFS(itemFrame, 12, preset.name, true, "LEFT")
					nameText:SetPoint("LEFT", 10, 0)
					nameText:SetTextColor(0, 1, 0)
					
					-- 使用局部变量保存当前索引，避免闭包问题
					local currentIndex = i
					
					local applyBtn = CreateButton(itemFrame, 60, 25, "应用")
					applyBtn:SetPoint("RIGHT", -75, 0)
					applyBtn:SetScript("OnClick", function()
						KM:ApplyPreset(preset)
						self.presetsFrame:Hide()
						if self.groupsFrame then
							self.groupsFrame:Hide()
							C_Timer.After(0.1, function()
								self.groupsFrame:Show()
							end)
						end
					end)
					
					local delBtn = CreateButton(itemFrame, 60, 25, "删除")
					delBtn:SetPoint("RIGHT", -10, 0)
					delBtn:SetScript("OnClick", function()
						KM:DeletePreset(currentIndex)
						KM:RefreshPresetsList()
					end)
					
					tinsert(userChild.items, itemFrame)
					yOffset = yOffset - 55
				end
				userChild:SetHeight(math.max(1, -yOffset))
			end
		end
		
		frame:SetScript("OnShow", function()
			KM:RefreshPresetsList()
		end)
		
		self.presetsFrame = frame
	end
	
	if self.presetsFrame:IsShown() then
		self.presetsFrame:Hide()
	else
		self.presetsFrame:Show()
	end
end

-- 显示导出界面
function KM:ShowExportUI()
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

-- 显示导入界面
function KM:ShowImportUI()
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

-- 显示趋势分析界面
function KM:ShowTrendAnalysisUI()
	EnsureConfig()
	
	if not self.trendFrame then
		local frame = CreateFrame("Frame", "KeywordMonitor_TrendUI", UIParent, "BackdropTemplate")
		frame:SetSize(700, 550)
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
		
		local title = CreateFS(frame, 16, "趋势分析 - 关键词热度变化", true)
		title:SetPoint("TOP", 0, -10)
		
		local closeBtn = CreateCloseButton(frame)
		closeBtn:SetPoint("TOPRIGHT", -10, -10)
		closeBtn:SetScript("OnClick", function() frame:Hide() end)
		
		-- 说明
		local desc = CreateFS(frame, 11, "查看关键词在最近7天的热度变化趋势", false, "LEFT")
		desc:SetPoint("TOPLEFT", 20, -40)
		desc:SetTextColor(0.7, 0.7, 0.7)
		
		-- 总体趋势
		local overallLabel = CreateFS(frame, 14, "总体匹配趋势（最近7天）:", false, "LEFT")
		overallLabel:SetPoint("TOPLEFT", 20, -65)
		overallLabel:SetTextColor(1, 0.8, 0)
		
		local overallChart = CreateFrame("Frame", nil, frame, "BackdropTemplate")
		overallChart:SetPoint("TOPLEFT", 20, -90)
		overallChart:SetSize(660, 120)
		
		if KeywordMonitorDB.UseNDuiStyle then
			overallChart:SetBackdrop({
				bgFile = "Interface\\Buttons\\WHITE8X8",
				edgeFile = "Interface\\Buttons\\WHITE8X8",
				edgeSize = 1,
			})
			overallChart:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
			overallChart:SetBackdropBorderColor(0, 0, 0, 1)
		else
			overallChart:SetBackdrop({
				bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
				edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
				tile = true,
				tileSize = 16,
				edgeSize = 12,
				insets = { left = 2, right = 2, top = 2, bottom = 2 }
			})
			overallChart:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
		end
		
		frame.overallChart = overallChart
		frame.overallBars = {}
		
		-- 创建7个柱状图
		for i = 1, 7 do
			local bar = CreateFrame("Frame", nil, overallChart, "BackdropTemplate")
			bar:SetSize(80, 1)
			bar:SetPoint("BOTTOMLEFT", 20 + (i-1) * 90, 10)
			bar:SetBackdrop({
				bgFile = "Interface\\Buttons\\WHITE8X8",
			})
			bar:SetBackdropColor(0, 0.8, 0, 0.8)
			
			local dateLabel = CreateFS(bar, 9, "", false, "CENTER")
			dateLabel:SetPoint("BOTTOM", bar, "TOP", 0, 2)
			dateLabel:SetTextColor(0.7, 0.7, 0.7)
			
			local countLabel = CreateFS(bar, 10, "", false, "CENTER")
			countLabel:SetPoint("TOP", bar, "BOTTOM", 0, -2)
			countLabel:SetTextColor(1, 1, 1)
			
			bar.dateLabel = dateLabel
			bar.countLabel = countLabel
			frame.overallBars[i] = bar
		end
		
		-- 关键词选择
		local kwLabel = CreateFS(frame, 14, "选择关键词查看趋势:", false, "LEFT")
		kwLabel:SetPoint("TOPLEFT", 20, -225)
		kwLabel:SetTextColor(1, 0.8, 0)
		
		-- 关键词列表
		local kwScroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
		kwScroll:SetPoint("TOPLEFT", 20, -250)
		kwScroll:SetSize(200, 250)
		
		local kwChild = CreateFrame("Frame", nil, kwScroll)
		kwChild:SetSize(180, 1)
		kwScroll:SetScrollChild(kwChild)
		frame.kwChild = kwChild
		
		-- 选中关键词的趋势图
		local selectedChart = CreateFrame("Frame", nil, frame, "BackdropTemplate")
		selectedChart:SetPoint("TOPLEFT", 240, -250)
		selectedChart:SetSize(440, 250)
		
		if KeywordMonitorDB.UseNDuiStyle then
			selectedChart:SetBackdrop({
				bgFile = "Interface\\Buttons\\WHITE8X8",
				edgeFile = "Interface\\Buttons\\WHITE8X8",
				edgeSize = 1,
			})
			selectedChart:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
			selectedChart:SetBackdropBorderColor(0, 0, 0, 1)
		else
			selectedChart:SetBackdrop({
				bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
				edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
				tile = true,
				tileSize = 16,
				edgeSize = 12,
				insets = { left = 2, right = 2, top = 2, bottom = 2 }
			})
			selectedChart:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
		end
		
		frame.selectedChart = selectedChart
		frame.selectedBars = {}
		
		local selectedTitle = CreateFS(selectedChart, 13, "请选择关键词", true, "CENTER")
		selectedTitle:SetPoint("TOP", 0, -10)
		selectedTitle:SetTextColor(0.7, 0.7, 0.7)
		frame.selectedTitle = selectedTitle
		
		-- 创建7个柱状图
		for i = 1, 7 do
			local bar = CreateFrame("Frame", nil, selectedChart, "BackdropTemplate")
			bar:SetSize(50, 1)
			bar:SetPoint("BOTTOMLEFT", 20 + (i-1) * 60, 20)
			bar:SetBackdrop({
				bgFile = "Interface\\Buttons\\WHITE8X8",
			})
			bar:SetBackdropColor(1, 0.5, 0, 0.8)
			bar:Hide()
			
			local dateLabel = CreateFS(bar, 8, "", false, "CENTER")
			dateLabel:SetPoint("BOTTOM", bar, "TOP", 0, 2)
			dateLabel:SetTextColor(0.7, 0.7, 0.7)
			
			local countLabel = CreateFS(bar, 9, "", false, "CENTER")
			countLabel:SetPoint("TOP", bar, "BOTTOM", 0, -2)
			countLabel:SetTextColor(1, 1, 1)
			
			bar.dateLabel = dateLabel
			bar.countLabel = countLabel
			frame.selectedBars[i] = bar
		end
		
		-- 刷新趋势数据
		function KM:RefreshTrendAnalysis(selectedKeyword)
			-- 刷新总体趋势
			local overallTrend = KM:GetOverallTrend(7)
			local maxCount = 0
			for _, data in ipairs(overallTrend) do
				if data.count > maxCount then
					maxCount = data.count
				end
			end
			
			for i, data in ipairs(overallTrend) do
				local bar = frame.overallBars[i]
				if bar then
					local height = maxCount > 0 and (data.count / maxCount * 90) or 1
					bar:SetHeight(math.max(1, height))
					
					-- 日期格式：02-20
					local month, day = data.date:match("-%d+%-(%d+)-(%d+)")
					bar.dateLabel:SetText(month .. "-" .. day)
					bar.countLabel:SetText(tostring(data.count))
					
					-- 根据数量设置颜色
					if data.count == 0 then
						bar:SetBackdropColor(0.2, 0.2, 0.2, 0.5)
					elseif data.count < maxCount * 0.3 then
						bar:SetBackdropColor(0, 0.5, 0, 0.8)
					elseif data.count < maxCount * 0.7 then
						bar:SetBackdropColor(0.8, 0.8, 0, 0.8)
					else
						bar:SetBackdropColor(0.8, 0, 0, 0.8)
					end
				end
			end
			
			-- 刷新关键词列表
			CleanupUIElements(frame.kwChild.items)
			frame.kwChild.items = {}
			
			local topKeywords = KM:GetTopKeywords(20)
			local yOffset = -5
			for i, data in ipairs(topKeywords) do
				local btn = CreateButton(frame.kwChild, 170, 25, data.keyword .. " (" .. data.count .. ")")
				btn:SetPoint("TOPLEFT", 5, yOffset)
				btn:SetScript("OnClick", function()
					KM:RefreshTrendAnalysis(data.keyword)
				end)
				
				tinsert(frame.kwChild.items, btn)
				yOffset = yOffset - 30
			end
			frame.kwChild:SetHeight(math.max(1, -yOffset))
			
			-- 刷新选中关键词的趋势
			if selectedKeyword then
				frame.selectedTitle:SetText(selectedKeyword .. " 的趋势")
				
				local kwTrend = KM:GetKeywordTrend(selectedKeyword, 7)
				local kwMaxCount = 0
				for _, data in ipairs(kwTrend) do
					if data.count > kwMaxCount then
						kwMaxCount = data.count
					end
				end
				
				for i, data in ipairs(kwTrend) do
					local bar = frame.selectedBars[i]
					if bar then
						bar:Show()
						local height = kwMaxCount > 0 and (data.count / kwMaxCount * 180) or 1
						bar:SetHeight(math.max(1, height))
						
						local month, day = data.date:match("-%d+%-(%d+)-(%d+)")
						bar.dateLabel:SetText(month .. "-" .. day)
						bar.countLabel:SetText(tostring(data.count))
					end
				end
			else
				for _, bar in ipairs(frame.selectedBars) do
					bar:Hide()
				end
			end
		end
		
		frame:SetScript("OnShow", function()
			KM:RefreshTrendAnalysis()
		end)
		
		self.trendFrame = frame
	end
	
	if self.trendFrame:IsShown() then
		self.trendFrame:Hide()
	else
		self.trendFrame:Show()
	end
end

-- 智能分析历史记录，提取高频词组
function KM:AnalyzeHistoryForCombinations()
	EnsureConfig()
	
	-- 词频统计
	local wordFreq = {}
	-- 词组共现统计
	local pairFreq = {}
	
	-- 常见的无意义词（停用词）
	local stopWords = {
		["的"] = true, ["了"] = true, ["在"] = true, ["是"] = true, ["我"] = true,
		["有"] = true, ["和"] = true, ["就"] = true, ["不"] = true, ["人"] = true,
		["都"] = true, ["一"] = true, ["个"] = true, ["上"] = true, ["也"] = true,
		["很"] = true, ["到"] = true, ["说"] = true, ["要"] = true, ["去"] = true,
		["你"] = true, ["会"] = true, ["着"] = true, ["没"] = true, ["看"] = true,
		["好"] = true, ["自己"] = true, ["这"] = true, ["来"] = true, ["吗"] = true,
		["啊"] = true, ["呢"] = true, ["吧"] = true, ["哦"] = true, ["嗯"] = true,
		["哈"] = true, ["呀"] = true, ["呵"] = true, ["嘿"] = true, ["哟"] = true,
	}
	
	-- 添加标点符号到停用词
	local punctuations = {
		",", "，", ".", "。", "!", "！", "?", "？", ":", "：",
		";", "；", "、", " ", "　", "(", ")", "（", "）",
		"【", "】", "{", "}", "《", "》", "<", ">", "-",
		"—", "_", "+", "=", "/", "|", "~", "`"
	}
	for _, p in ipairs(punctuations) do
		stopWords[p] = true
	end
	
	-- 添加用户自定义停用词
	for _, word in ipairs(KeywordMonitorDB.CustomStopWords) do
		stopWords[word] = true
	end
	
	-- 扫描历史记录
	for _, record in ipairs(KeywordMonitorDB.History) do
		local msg = record.msg
		-- 清理消息，提取词汇
		local cleanMsg = gsub(msg, "|c%x%x%x%x%x%x%x%x", "")  -- 移除颜色代码
		cleanMsg = gsub(cleanMsg, "|r", "")
		cleanMsg = gsub(cleanMsg, "|H.-|h", "")  -- 移除链接
		cleanMsg = gsub(cleanMsg, "|h", "")
		
		-- 提取2-4个字符的词汇
		local words = {}
		for word in gmatch(cleanMsg, "[%z\1-\127\194-\244][\128-\191]*[%z\1-\127\194-\244][\128-\191]*[%z\1-\127\194-\244][\128-\191]*[%z\1-\127\194-\244]?[\128-\191]*") do
			word = gsub(word, "^%s*(.-)%s*$", "%1")  -- 去除首尾空格
			if #word >= 4 and #word <= 12 and not stopWords[word] then  -- 2-4个汉字
				-- 应用词汇替换映射
				local mappedWord = KeywordMonitorDB.WordReplacements[word] or word
				
				-- 统计词频
				wordFreq[mappedWord] = (wordFreq[mappedWord] or 0) + 1
				tinsert(words, mappedWord)
			end
		end
		
		-- 统计词组共现
		for i = 1, #words do
			for j = i + 1, #words do
				local word1, word2 = words[i], words[j]
				if word1 ~= word2 then
					local pair = word1 < word2 and (word1 .. "|" .. word2) or (word2 .. "|" .. word1)
					pairFreq[pair] = (pairFreq[pair] or 0) + 1
				end
			end
		end
	end
	
	-- 转换为列表并排序
	local wordList = {}
	for word, count in pairs(wordFreq) do
		if count >= 3 then  -- 至少出现3次
			tinsert(wordList, {word = word, count = count})
		end
	end
	sort(wordList, function(a, b) return a.count > b.count end)
	
	local pairList = {}
	for pair, count in pairs(pairFreq) do
		if count >= 2 then  -- 至少共现2次
			local word1, word2 = pair:match("([^|]+)|([^|]+)")
			tinsert(pairList, {word1 = word1, word2 = word2, count = count})
		end
	end
	sort(pairList, function(a, b) return a.count > b.count end)
	
	return wordList, pairList
end

-- 显示关联分析界面
function KM:ShowCorrelationAnalysisUI()
	EnsureConfig()
	
	if not self.correlationFrame then
		local frame = CreateFrame("Frame", "KeywordMonitor_CorrelationUI", UIParent, "BackdropTemplate")
		frame:SetSize(600, 500)
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
		
		local title = CreateFS(frame, 16, "智能分析 - 高频词组推荐", true)
		title:SetPoint("TOP", 0, -10)
		
		local closeBtn = CreateCloseButton(frame)
		closeBtn:SetPoint("TOPRIGHT", -10, -10)
		closeBtn:SetScript("OnClick", function() frame:Hide() end)
		
		-- 说明文字
		local desc = CreateFS(frame, 11, "从历史记录中分析出现频率最高的词组，点击添加为关键词组合", false, "LEFT")
		desc:SetPoint("TOPLEFT", 20, -40)
		desc:SetTextColor(0.7, 0.7, 0.7)
		
		-- 分析按钮
		local analyzeBtn = CreateButton(frame, 100, 25, "重新分析")
		analyzeBtn:SetPoint("TOPRIGHT", -130, -35)
		analyzeBtn:SetScript("OnClick", function()
			KM:RefreshCorrelationAnalysis()
		end)
		
		-- 停用词管理按钮
		local stopWordsBtn = CreateButton(frame, 120, 25, "管理停用词")
		stopWordsBtn:SetPoint("TOPRIGHT", -20, -35)
		stopWordsBtn:SetScript("OnClick", function()
			KM:ShowStopWordsUI()
		end)
		
		-- 高频词汇标签
		local kwLabel = CreateFS(frame, 14, "高频词汇:", false, "LEFT")
		kwLabel:SetPoint("TOPLEFT", 20, -70)
		kwLabel:SetTextColor(1, 0.8, 0)
		frame.kwLabel = kwLabel
		
		-- 关键词列表
		local kwScroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
		kwScroll:SetPoint("TOPLEFT", 20, -95)
		kwScroll:SetSize(250, 360)
		
		local kwChild = CreateFrame("Frame", nil, kwScroll)
		kwChild:SetSize(230, 1)
		kwChild.items = {}
		kwScroll:SetScrollChild(kwChild)
		frame.kwChild = kwChild
		
		-- 推荐词组标签
		local correlationLabel = CreateFS(frame, 14, "推荐词组组合:", false, "LEFT")
		correlationLabel:SetPoint("TOPLEFT", 290, -70)
		correlationLabel:SetTextColor(1, 0.8, 0)
		frame.correlationLabel = correlationLabel
		
		-- 关联关键词列表
		local correlationScroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
		correlationScroll:SetPoint("TOPLEFT", 290, -95)
		correlationScroll:SetSize(290, 360)
		
		local correlationChild = CreateFrame("Frame", nil, correlationScroll)
		correlationChild:SetSize(270, 1)
		correlationChild.items = {}
		correlationScroll:SetScrollChild(correlationChild)
		frame.correlationChild = correlationChild
		
		-- 刷新关联分析（使用智能分析）
		function KM:RefreshCorrelationAnalysis()
			-- 执行智能分析
			local wordList, pairList = KM:AnalyzeHistoryForCombinations()
			
			-- 清空旧内容
			CleanupUIElements(frame.kwChild.items)
			frame.kwChild.items = {}
			CleanupUIElements(frame.correlationChild.items)
			frame.correlationChild.items = {}
			
			-- 显示高频单词（左侧）
			frame.kwLabel:SetText(string.format("高频词汇 (Top %d):", math.min(20, #wordList)))
			
			if #wordList == 0 then
				local noData = CreateFS(frame.kwChild, 12, "暂无数据\n请先提取一些消息", false, "CENTER")
				noData:SetPoint("CENTER", 0, 0)
				noData:SetTextColor(0.5, 0.5, 0.5)
				tinsert(frame.kwChild.items, noData)
				frame.kwChild:SetHeight(1)
			else
				local yOffset = -5
				for i = 1, math.min(20, #wordList) do
					local data = wordList[i]
					local btn = CreateFrame("Button", nil, frame.kwChild, "UIPanelButtonTemplate")
					btn:SetSize(220, 25)
					btn:SetPoint("TOPLEFT", 5, yOffset)
					btn:SetText(data.word .. " (" .. data.count .. ")")
					
					-- 注册左键和右键点击
					btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
					btn:SetScript("OnClick", function(self, button)
						if button == "LeftButton" then
							-- 左键：编辑词汇
							KM:ShowEditWordDialog(data.word)
						elseif button == "RightButton" then
							-- 右键：添加到停用词
							tinsert(KeywordMonitorDB.CustomStopWords, data.word)
							print("|cffFFFF00[ChatKeyword]|r 已将 \"" .. data.word .. "\" 添加到停用词列表")
							-- 重新分析
							KM:RefreshCorrelationAnalysis()
						end
					end)
					
					-- 鼠标提示
					btn:SetScript("OnEnter", function(self)
						GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
						GameTooltip:AddLine("左键点击可编辑词汇", 1, 1, 1)
						GameTooltip:AddLine("右键点击可添加到停用词", 0.7, 0.7, 0.7)
						GameTooltip:Show()
					end)
					btn:SetScript("OnLeave", function(self)
						GameTooltip:Hide()
					end)
					
					tinsert(frame.kwChild.items, btn)
					yOffset = yOffset - 30
				end
				frame.kwChild:SetHeight(math.max(1, -yOffset))
			end
			
			-- 显示高频词组（右侧）
			frame.correlationLabel:SetText(string.format("推荐词组组合 (Top %d):", math.min(15, #pairList)))
			
			if #pairList == 0 then
				local noData = CreateFS(frame.correlationChild, 12, "暂无词组数据\n需要更多历史记录", false, "CENTER")
				noData:SetPoint("CENTER", 0, 0)
				noData:SetTextColor(0.5, 0.5, 0.5)
				tinsert(frame.correlationChild.items, noData)
				frame.correlationChild:SetHeight(1)
			else
				local yOffset = -5
				for i = 1, math.min(15, #pairList) do
					local data = pairList[i]
					local itemFrame = CreateFrame("Frame", nil, frame.correlationChild, "BackdropTemplate")
					itemFrame:SetSize(260, 50)
					itemFrame:SetPoint("TOPLEFT", 5, yOffset)
					
					if KeywordMonitorDB.UseNDuiStyle then
						itemFrame:SetBackdrop({
							bgFile = "Interface\\Buttons\\WHITE8X8",
							edgeFile = "Interface\\Buttons\\WHITE8X8",
							edgeSize = 1,
						})
						itemFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.7)
						itemFrame:SetBackdropBorderColor(0, 0, 0, 1)
					else
						itemFrame:SetBackdrop({
							bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
							edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
							tile = true,
							tileSize = 16,
							edgeSize = 12,
							insets = { left = 2, right = 2, top = 2, bottom = 2 }
						})
						itemFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.7)
					end
					
					-- 词组显示
					local comboText = CreateFS(itemFrame, 13, data.word1 .. " + " .. data.word2, true, "LEFT")
					comboText:SetPoint("TOPLEFT", 10, -8)
					comboText:SetTextColor(1, 0.8, 0)
					
					local countText = CreateFS(itemFrame, 11, string.format("共同出现 %d 次", data.count), false, "LEFT")
					countText:SetPoint("TOPLEFT", 10, -25)
					countText:SetTextColor(0.7, 0.7, 0.7)
					
					-- 添加按钮
					local addBtn = CreateButton(itemFrame, 80, 20, "添加组合")
					addBtn:SetPoint("RIGHT", -5, 0)
					addBtn:SetScript("OnClick", function()
						local combo = data.word1 .. "+" .. data.word2
						
						-- 检查是否启用分组模式
						if KeywordMonitorDB.UseKeywordGroups then
							-- 添加为新的关键词分组
							local groupName = data.word1 .. "+" .. data.word2
							KM:AddKeywordGroup(groupName, combo)
							print("|cff00FF00[ChatKeyword]|r 已创建关键词分组: " .. groupName)
							
							-- 刷新分组列表（如果分组界面已打开）
							if self.groupsFrame and self.groupsFrame:IsShown() then
								KM:RefreshGroupsList()
							end
						else
							-- 添加到传统关键词字符串
							local currentKeywords = KeywordMonitorDB.Keywords or ""
							if currentKeywords == "" then
								KeywordMonitorDB.Keywords = combo
							else
								KeywordMonitorDB.Keywords = currentKeywords .. "," .. combo
							end
							KM:UpdateKeywordList(KeywordMonitorDB.Keywords)
							print("|cff00FF00[ChatKeyword]|r 已添加组合关键词: " .. combo)
						end
						
						-- 关闭关联分析界面
						frame:Hide()
					end)
					
					tinsert(frame.correlationChild.items, itemFrame)
					yOffset = yOffset - 55
				end
				frame.correlationChild:SetHeight(math.max(1, -yOffset))
			end
		end
		
		frame:SetScript("OnShow", function()
			KM:RefreshCorrelationAnalysis()
		end)
		
		self.correlationFrame = frame
	end
	
	if self.correlationFrame:IsShown() then
		self.correlationFrame:Hide()
	else
		self.correlationFrame:Show()
	end
end

-- 显示编辑词汇对话框
function KM:ShowEditWordDialog(originalWord)
	-- 创建或复用对话框
	if not self.editWordDialog then
		local dialog = CreateFrame("Frame", "KeywordMonitor_EditWordDialog", UIParent, "BackdropTemplate")
		dialog:SetSize(400, 180)
		dialog:SetPoint("CENTER")
		dialog:SetFrameStrata("FULLSCREEN_DIALOG")
		dialog:SetFrameLevel(130)
		
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
		
		local title = CreateFS(dialog, 16, "编辑词汇", true)
		title:SetPoint("TOP", 0, -10)
		
		local closeBtn = CreateCloseButton(dialog)
		closeBtn:SetPoint("TOPRIGHT", -10, -10)
		closeBtn:SetScript("OnClick", function() dialog:Hide() end)
		
		-- 原词汇显示
		local originalLabel = CreateFS(dialog, 12, "原词汇:", false, "LEFT")
		originalLabel:SetPoint("TOPLEFT", 20, -45)
		
		local originalText = CreateFS(dialog, 13, "", true, "LEFT")
		originalText:SetPoint("LEFT", originalLabel, "RIGHT", 10, 0)
		originalText:SetTextColor(1, 0.8, 0)
		dialog.originalText = originalText
		
		-- 新词汇输入
		local newLabel = CreateFS(dialog, 12, "新词汇:", false, "LEFT")
		newLabel:SetPoint("TOPLEFT", 20, -75)
		
		local newBox = CreateEditBox(dialog, 250, 30)
		newBox:SetPoint("LEFT", newLabel, "RIGHT", 10, 0)
		dialog.newBox = newBox
		
		-- 按钮
		local applyBtn = CreateButton(dialog, 80, 30, "应用")
		applyBtn:SetPoint("BOTTOM", -45, 20)
		applyBtn:SetScript("OnClick", function()
			local newWord = newBox:GetText()
			if newWord and newWord ~= "" and newWord ~= dialog.currentWord then
				-- 添加词汇替换映射：原词汇 -> 新词汇
				KeywordMonitorDB.WordReplacements[dialog.currentWord] = newWord
				
				print("|cff00FF00[ChatKeyword]|r 已将 \"" .. dialog.currentWord .. "\" 映射为 \"" .. newWord .. "\"")
				print("|cffFFFF00[ChatKeyword]|r 下次分析时会自动合并统计")
				
				-- 重新分析
				if KM.correlationFrame and KM.correlationFrame:IsShown() then
					KM:RefreshCorrelationAnalysis()
				end
				
				dialog:Hide()
			end
		end)
		
		local cancelBtn = CreateButton(dialog, 80, 30, "取消")
		cancelBtn:SetPoint("BOTTOM", 45, 20)
		cancelBtn:SetScript("OnClick", function()
			dialog:Hide()
		end)
		
		-- 回车应用
		newBox:SetScript("OnEnterPressed", function()
			applyBtn:Click()
		end)
		
		-- ESC取消
		newBox:SetScript("OnEscapePressed", function()
			dialog:Hide()
		end)
		
		self.editWordDialog = dialog
	end
	
	-- 设置内容
	self.editWordDialog.currentWord = originalWord
	self.editWordDialog.originalText:SetText(originalWord)
	self.editWordDialog.newBox:SetText(originalWord)
	self.editWordDialog.newBox:SetFocus()
	self.editWordDialog.newBox:HighlightText()
	self.editWordDialog:Show()
end

-- 显示停用词管理界面
function KM:ShowStopWordsUI()
	EnsureConfig()
	
	if not self.stopWordsFrame then
		local frame = CreateFrame("Frame", "KeywordMonitor_StopWordsUI", UIParent, "BackdropTemplate")
		frame:SetSize(450, 400)
		frame:SetPoint("CENTER")
		frame:SetFrameStrata("FULLSCREEN_DIALOG")
		frame:SetFrameLevel(120)
		
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
		
		local title = CreateFS(frame, 16, "停用词管理", true)
		title:SetPoint("TOP", 0, -10)
		
		local closeBtn = CreateCloseButton(frame)
		closeBtn:SetPoint("TOPRIGHT", -10, -10)
		closeBtn:SetScript("OnClick", function() frame:Hide() end)
		
		-- 说明文字
		local desc = CreateFS(frame, 11, "停用词不会出现在智能分析的高频词汇中", false, "LEFT")
		desc:SetPoint("TOPLEFT", 20, -40)
		desc:SetTextColor(0.7, 0.7, 0.7)
		
		-- 添加停用词
		local addLabel = CreateFS(frame, 12, "添加停用词:", false, "LEFT")
		addLabel:SetPoint("TOPLEFT", 20, -65)
		
		local addBox = CreateEditBox(frame, 200, 25)
		addBox:SetPoint("LEFT", addLabel, "RIGHT", 5, 0)
		
		local addBtn = CreateButton(frame, 60, 25, "添加")
		addBtn:SetPoint("LEFT", addBox, "RIGHT", 5, 0)
		addBtn:SetScript("OnClick", function()
			local text = addBox:GetText()
			if text and text ~= "" then
				-- 检查是否已存在
				local exists = false
				for _, word in ipairs(KeywordMonitorDB.CustomStopWords) do
					if word == text then
						exists = true
						break
					end
				end
				
				if not exists then
					tinsert(KeywordMonitorDB.CustomStopWords, text)
					addBox:SetText("")
					KM:RefreshStopWordsList()
					print("|cff00FF00[ChatKeyword]|r 已添加停用词: " .. text)
				else
					print("|cffFFFF00[ChatKeyword]|r 停用词已存在: " .. text)
				end
			end
		end)
		
		addBox:SetScript("OnEnterPressed", function(self)
			addBtn:Click()
		end)
		
		-- 清空按钮
		local clearBtn = CreateButton(frame, 100, 25, "清空全部")
		clearBtn:SetPoint("TOPRIGHT", -20, -65)
		clearBtn:SetScript("OnClick", function()
			KeywordMonitorDB.CustomStopWords = {}
			KM:RefreshStopWordsList()
			print("|cff00FF00[ChatKeyword]|r 已清空所有自定义停用词")
		end)
		
		-- 停用词列表
		local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
		scrollFrame:SetPoint("TOPLEFT", 20, -100)
		scrollFrame:SetPoint("BOTTOMRIGHT", -40, 20)
		
		local scrollChild = CreateFrame("Frame", nil, scrollFrame)
		scrollChild:SetSize(390, 1)
		scrollFrame:SetScrollChild(scrollChild)
		frame.scrollChild = scrollChild
		
		-- 刷新停用词列表
		function KM:RefreshStopWordsList()
			CleanupUIElements(scrollChild.words)
			scrollChild.words = {}
			
			local yOffset = -5
			for i, word in ipairs(KeywordMonitorDB.CustomStopWords) do
				local wordFrame = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
				wordFrame:SetSize(370, 30)
				wordFrame:SetPoint("TOPLEFT", 5, yOffset)
				
				if KeywordMonitorDB.UseNDuiStyle then
					wordFrame:SetBackdrop({
						bgFile = "Interface\\Buttons\\WHITE8X8",
						edgeFile = "Interface\\Buttons\\WHITE8X8",
						edgeSize = 1,
					})
					wordFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
					wordFrame:SetBackdropBorderColor(0, 0, 0, 1)
				else
					wordFrame:SetBackdrop({
						bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
						edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
						tile = true,
						tileSize = 16,
						edgeSize = 12,
						insets = { left = 2, right = 2, top = 2, bottom = 2 }
					})
					wordFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
				end
				
				local text = CreateFS(wordFrame, 12, word, false, "LEFT")
				text:SetPoint("LEFT", 10, 0)
				text:SetPoint("RIGHT", -60, 0)
				
				-- 使用局部变量保存索引
				local currentIndex = i
				
				local delBtn = CreateButton(wordFrame, 50, 20, "删除")
				delBtn:SetPoint("RIGHT", -5, 0)
				delBtn:SetScript("OnClick", function()
					tremove(KeywordMonitorDB.CustomStopWords, currentIndex)
					KM:RefreshStopWordsList()
					print("|cff00FF00[ChatKeyword]|r 已删除停用词: " .. word)
				end)
				
				tinsert(scrollChild.words, wordFrame)
				yOffset = yOffset - 35
			end
			
			scrollChild:SetHeight(math.max(1, -yOffset))
		end
		
		frame:SetScript("OnShow", function()
			KM:RefreshStopWordsList()
		end)
		
		self.stopWordsFrame = frame
	end
	
	if self.stopWordsFrame:IsShown() then
		self.stopWordsFrame:Hide()
	else
		self.stopWordsFrame:Show()
	end
end

-- 显示性能监控界面
function KM:ShowPerformanceUI()
	EnsureConfig()
	
	if not self.performanceFrame then
		local frame = CreateFrame("Frame", "KeywordMonitor_PerformanceUI", UIParent, "BackdropTemplate")
		frame:SetSize(450, 350)
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
		
		local title = CreateFS(frame, 16, "性能监控", true)
		title:SetPoint("TOP", 0, -10)
		
		local closeBtn = CreateCloseButton(frame)
		closeBtn:SetPoint("TOPRIGHT", -10, -10)
		closeBtn:SetScript("OnClick", function() frame:Hide() end)
		
		-- 内存使用
		local memLabel = CreateFS(frame, 14, "内存使用:", false, "LEFT")
		memLabel:SetPoint("TOPLEFT", 20, -50)
		memLabel:SetTextColor(1, 0.8, 0)
		
		local memValue = CreateFS(frame, 20, "0 KB", true, "LEFT")
		memValue:SetPoint("LEFT", memLabel, "RIGHT", 10, 0)
		memValue:SetTextColor(0, 1, 0)
		frame.memValue = memValue
		
		-- 处理速度
		local speedLabel = CreateFS(frame, 14, "处理速度:", false, "LEFT")
		speedLabel:SetPoint("TOPLEFT", 20, -85)
		speedLabel:SetTextColor(1, 0.8, 0)
		
		local speedValue = CreateFS(frame, 20, "0 条/秒", true, "LEFT")
		speedValue:SetPoint("LEFT", speedLabel, "RIGHT", 10, 0)
		speedValue:SetTextColor(0, 1, 0)
		frame.speedValue = speedValue
		
		-- 总处理消息数
		local totalLabel = CreateFS(frame, 14, "总处理消息:", false, "LEFT")
		totalLabel:SetPoint("TOPLEFT", 20, -120)
		totalLabel:SetTextColor(1, 0.8, 0)
		
		local totalValue = CreateFS(frame, 20, "0 条", true, "LEFT")
		totalValue:SetPoint("LEFT", totalLabel, "RIGHT", 10, 0)
		totalValue:SetTextColor(0, 1, 0)
		frame.totalValue = totalValue
		
		-- 数据清理设置
		local cleanLabel = CreateFS(frame, 14, "数据清理设置:", false, "LEFT")
		cleanLabel:SetPoint("TOPLEFT", 20, -165)
		cleanLabel:SetTextColor(1, 0.8, 0)
		
		local autoCleanCheck = CreateCheckBox(frame)
		autoCleanCheck:SetPoint("TOPLEFT", 20, -190)
		autoCleanCheck:SetChecked(KeywordMonitorDB.AutoCleanOldData)
		local autoCleanLabel = CreateFS(frame, 12, "自动清理旧数据", false, "LEFT")
		autoCleanLabel:SetPoint("LEFT", autoCleanCheck, "RIGHT", 5, 0)
		
		autoCleanCheck:SetScript("OnClick", function(self)
			KeywordMonitorDB.AutoCleanOldData = self:GetChecked()
		end)
		
		local retentionLabel = CreateFS(frame, 12, "数据保留天数:", false, "LEFT")
		retentionLabel:SetPoint("TOPLEFT", 20, -220)
		
		local retentionBox = CreateEditBox(frame, 60, 25)
		retentionBox:SetPoint("LEFT", retentionLabel, "RIGHT", 10, 0)
		retentionBox:SetText(tostring(KeywordMonitorDB.DataRetentionDays))
		retentionBox:SetNumeric(true)
		retentionBox:SetScript("OnTextChanged", function(self)
			local value = tonumber(self:GetText())
			if value and value >= 1 and value <= 30 then
				KeywordMonitorDB.DataRetentionDays = value
			end
		end)
		
		local retentionHint = CreateFS(frame, 10, "(1-30天)", false, "LEFT")
		retentionHint:SetPoint("LEFT", retentionBox, "RIGHT", 5, 0)
		retentionHint:SetTextColor(0.7, 0.7, 0.7)
		
		-- 立即清理按钮
		local cleanNowBtn = CreateButton(frame, 120, 25, "立即清理旧数据")
		cleanNowBtn:SetPoint("TOPLEFT", 20, -255)
		cleanNowBtn:SetScript("OnClick", function()
			KM:CleanOldData()
			KM:RefreshPerformance()
		end)
		
		-- 优化内存按钮
		local optimizeBtn = CreateButton(frame, 120, 25, "优化内存")
		optimizeBtn:SetPoint("LEFT", cleanNowBtn, "RIGHT", 10, 0)
		optimizeBtn:SetScript("OnClick", function()
			KM:OptimizeMemory()
			C_Timer.After(0.5, function()
				KM:RefreshPerformance()
				print("|cff00FF00[ChatKeyword]|r 内存优化完成")
			end)
		end)
		
		-- 诊断按钮
		local diagnoseBtn = CreateButton(frame, 120, 25, "内存诊断")
		diagnoseBtn:SetPoint("TOPLEFT", 20, -290)
		diagnoseBtn:SetScript("OnClick", function()
			KM:DiagnoseMemory()
		end)
		
		-- 内存优化说明
		local optimizeHint = CreateFS(frame, 10, "清理低频数据、强制垃圾回收", false, "LEFT")
		optimizeHint:SetPoint("TOPLEFT", 20, -320)
		optimizeHint:SetTextColor(0.7, 0.7, 0.7)
		
		-- 刷新按钮
		local refreshBtn = CreateButton(frame, 80, 25, "刷新")
		refreshBtn:SetPoint("BOTTOM", 0, 15)
		refreshBtn:SetScript("OnClick", function()
			KM:RefreshPerformance()
		end)
		
		-- 刷新性能数据
		function KM:RefreshPerformance()
			local stats = KM:GetPerformanceStats()
			
			frame.memValue:SetText(string.format("%.2f KB", stats.memory))
			frame.speedValue:SetText(string.format("%.2f 条/秒", stats.messagesPerSecond))
			frame.totalValue:SetText(string.format("%d 条", stats.totalMessages))
			
			-- 根据内存使用设置颜色
			if stats.memory < 500 then
				frame.memValue:SetTextColor(0, 1, 0)
			elseif stats.memory < 1000 then
				frame.memValue:SetTextColor(1, 1, 0)
			else
				frame.memValue:SetTextColor(1, 0, 0)
			end
		end
		
		-- 自动刷新
		frame:SetScript("OnShow", function()
			KM:RefreshPerformance()
			-- 每5秒刷新一次（从2秒改为5秒，减少刷新频率）
			if not frame.ticker then
				frame.ticker = C_Timer.NewTicker(5, function()
					if frame:IsShown() then
						KM:RefreshPerformance()
					end
				end)
			end
		end)
		
		frame:SetScript("OnHide", function()
			if frame.ticker then
				frame.ticker:Cancel()
				frame.ticker = nil
			end
		end)
		
		self.performanceFrame = frame
	end
	
	if self.performanceFrame:IsShown() then
		self.performanceFrame:Hide()
	else
		self.performanceFrame:Show()
	end
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
		
		-- 启动时间触发检查
		KM:CheckTimeTriggers()
		
		-- 每分钟检查一次时间触发
		C_Timer.NewTicker(60, function()
			KM:CheckTimeTriggers()
		end)
		
		-- 检查版本更新
		KM:CheckVersionUpdate()
		
		-- 清理旧数据
		KM:CleanOldData()
		
		-- 每天清理一次旧数据
		C_Timer.NewTicker(86400, function()
			KM:CleanOldData()
		end)
		
		-- 每小时优化一次内存
		C_Timer.NewTicker(3600, function()
			KM:OptimizeMemory()
		end)
		
		-- 每5分钟清理一次重复消息缓存
		C_Timer.NewTicker(300, function()
			CleanRepeatMessageCache()
		end)
		
		-- 每60秒执行一次轻量级垃圾回收（而不是30秒）
		C_Timer.NewTicker(60, function()
			collectgarbage("step", 100)  -- 增量式GC，不会造成卡顿
		end)
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
		elseif cmd == "memory" or cmd == "内存" then
			KM:DiagnoseMemory()
		elseif cmd == "optimize" or cmd == "优化" then
			print("|cff00FF00[ChatKeyword]|r 正在优化内存...")
			KM:OptimizeMemory()
			C_Timer.After(0.5, function()
				print("|cff00FF00[ChatKeyword]|r 内存优化完成")
				local memory = KM:GetMemoryUsage()
				print(string.format("|cff00FF00[ChatKeyword]|r 当前内存: %.2f KB", memory))
			end)
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
			print("  /keyword memory - 内存诊断")
			print("  /keyword optimize - 优化内存")
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
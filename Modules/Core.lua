--[[
    KeywordMonitor - Core Module
    核心功能模块
    
    职责：
    - 提供关键词匹配和消息过滤核心功能
    - 管理关键词列表和缓存
    - 处理聊天消息过滤和高亮
    - 管理监控窗口的创建和显示
    - 处理好友检测和重复消息过滤
    - 控制监控的启用/禁用状态
    
    依赖：Utils 模块、Config 模块
    
    公共接口：
    - UpdateKeywordList() - 更新关键词列表
    - MatchKeywords(text) - 匹配关键词
    - ShowKeywordMessage(chatFrame, event, message, sender, ...) - 消息过滤器
    - ToggleKeywordMonitor(enabled) - 启用/禁用监控
    - IsFriend(sender) - 检查是否为好友
    - IsRepeatMessage(text) - 检测重复消息
    - CleanRepeatMessageCache() - 清理重复消息缓存
    - HighlightKeyword(text, keyword, color) - 高亮关键词
    - CreateKeywordFrame() - 创建独立监控窗口
    - HandleCombatVisibility() - 处理战斗隐藏
--]]

local addonName, addon = ...

-- 确保全局命名空间存在
if not _G.KeywordMonitor then
	_G.KeywordMonitor = {}
end

-- 获取全局命名空间（不使用 local 变量）
local KM = _G.KeywordMonitor

-- 创建 Core 模块命名空间
KM.Core = {}
local Core = KM.Core

-- 引用依赖模块（延迟加载）
local Utils, Config

local function LoadDependencies()
	if not Utils then
		Utils = KM.Utils
		Config = KM.Config
		
		-- 依赖检查
		if not Utils then
			error("KeywordMonitor Core 模块需要 Utils 模块先加载")
		end
		if not Config then
			error("KeywordMonitor Core 模块需要 Config 模块先加载")
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

-- 聊天框架函数
local ChatFrame_ReplaceIconAndGroupExpressions = C_ChatInfo and C_ChatInfo.ReplaceIconAndGroupExpressions or ChatFrame_ReplaceIconAndGroupExpressions
local ChatFrame_AddMessageEventFilter = ChatFrame_AddMessageEventFilter
local ChatFrame_RemoveMessageEventFilter = ChatFrame_RemoveMessageEventFilter
local FCF_StartAlertFlash = FCF_StartAlertFlash
local GeneralDockManager = GeneralDockManager
local GetChatWindowInfo = GetChatWindowInfo
local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS
local ChatFrame1 = ChatFrame1

-- 常量
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local STANDARD_TEXT_FONT = STANDARD_TEXT_FONT
local ChatTypeInfo = ChatTypeInfo

--[[============================================
    模块变量
============================================]]--

-- 关键词列表和缓存
local keywords = {}  -- 关键词列表，用于快速匹配
local keywordFrame = nil  -- 独立监控窗口引用

-- 重复消息缓存（优化版 - 使用固定大小的循环缓存）
local repeatMessageCache = {}  -- 已废弃，保留用于兼容性
local repeatMessageIndex = {}  -- 用于快速查找消息时间戳 {[text] = timestamp}
local repeatMessageQueue = {}  -- 用于维护消息顺序，存储消息文本
local repeatMessageCount = 0  -- 当前缓存中的消息数量
local MAX_CACHE_SIZE = 50  -- 最大缓存大小

-- 好友缓存（60秒刷新）
local friendCache = {}  -- 好友名称缓存 {[name] = true}
local friendCacheTime = 0  -- 上次刷新时间

-- 其他 UI 元素引用
local keywordButton = nil  -- 控制按钮引用
local configFrame = nil  -- 配置界面引用

--[[============================================
    核心功能函数（占位符 - 待后续任务实现）
============================================]]--

-- 更新关键词列表
-- @param keywordStr string 关键词字符串（可选，传统模式使用）
-- @return void
function Core.UpdateKeywordList(keywordStr)
	LoadDependencies()
	keywords = {}
	
	Config.EnsureConfig()
	
	-- 如果启用了分组模式，使用分组关键词
	if KeywordMonitorDB.UseKeywordGroups then
		for _, group in ipairs(KeywordMonitorDB.KeywordGroups) do
			if group.enabled and group.keywords and group.keywords ~= "" then
				local groupKeywordStr = group.keywords
				groupKeywordStr = gsub(groupKeywordStr, "，", ",")
				groupKeywordStr = gsub(groupKeywordStr, "＋", "+")
				
				local list = Utils.SplitString(groupKeywordStr, ",")
				
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
	
	local list = Utils.SplitString(keywordStr, ",")
	
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

-- 匹配关键词
-- @param text string 要匹配的文本
-- @return boolean, string|table|nil 是否匹配，匹配到的关键词（字符串或表）
function Core.MatchKeywords(text)
	if #keywords == 0 then return false end
	
	local cleanText = Utils.CleanText(text)
	
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

-- 高亮关键词（支持多关键词高亮）
-- @param msg string 原始消息文本
-- @param matchedKeyword string|table 匹配到的关键词（字符串或表）
-- @return string 高亮后的文本
function Core.HighlightKeyword(msg, matchedKeyword)
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

-- 检查是否为好友
-- @param name string 玩家名称
-- @return boolean 是否为好友
function Core.IsFriend(name)
	if not name then return false end
	
	-- 检查缓存是否过期（60秒刷新）
	local currentTime = GetTime()
	if currentTime - friendCacheTime > 60 then
		-- 刷新好友缓存
		wipe(friendCache)
		
		-- 获取 WoW 好友列表
		local numOnline = C_FriendList.GetNumOnlineFriends()
		for i = 1, numOnline do
			local info = C_FriendList.GetFriendInfoByIndex(i)
			if info and info.name then
				friendCache[info.name] = true
			end
		end
		
		-- 获取战网好友列表
		local _, numBNetOnline = BNGetNumFriends()
		for i = 1, numBNetOnline do
			local numGameAccounts = C_BattleNet.GetFriendNumGameAccounts(i)
			for j = 1, numGameAccounts do
				local gameAccountInfo = C_BattleNet.GetFriendGameAccountInfo(i, j)
				if gameAccountInfo and gameAccountInfo.clientProgram == BNET_CLIENT_WOW then
					if gameAccountInfo.characterName then
						friendCache[gameAccountInfo.characterName] = true
					end
				end
			end
		end
		
		-- 更新缓存时间
		friendCacheTime = currentTime
	end
	
	-- 从缓存中查找
	return friendCache[name] == true
end

-- 检测重复消息
-- @param text string 消息文本
-- @return boolean 是否为重复消息（true 表示是重复消息，应该过滤）
function Core.IsRepeatMessage(text)
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
-- @return number 清理的消息数量
function Core.CleanRepeatMessageCache()
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

-- 获取重复消息缓存大小
-- @return number 缓存中的消息数量
function Core.GetRepeatMessageCacheSize()
	return repeatMessageCount
end

-- 消息过滤器
-- @param chatFrame Frame 聊天框架
-- @param event string 事件名称
-- @param message string 消息内容
-- @param sender string 发送者名称
-- @param ... 其他参数
-- @return boolean 是否过滤该消息（false 表示不过滤，显示消息）
function Core.ShowKeywordMessage(chatFrame, event, message, sender, ...)
	LoadDependencies()
	Config.EnsureConfig()
	if not KeywordMonitorDB.Enabled then return false end
	
	local name = Ambiguate(sender, "none")
	
	-- 过滤自己的消息
	if name == UnitName("player") then
		return false
	end
	
	-- 过滤好友消息
	if Core.IsFriend(name) then
		return false
	end
	
	-- 检查黑名单
	if KM.Blacklist and KM.Blacklist.IsBlacklisted(name, message) then
		return false
	end
	
	-- 检查关键词匹配
	local matched, keyword = Core.MatchKeywords(message)
	if not matched then return false end
	
	local cleanMsg = Utils.CleanText(message)
	
	-- 过滤重复消息
	if Core.IsRepeatMessage(cleanMsg) then
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
	local coloredName = GetColoredName(event, message, sender, ...)
	local playerLink
	local r, g, b = 1, 1, 1
	
	-- 根据配置决定是否使用职业染色
	if KeywordMonitorDB.ClassColorEnabled then
		-- 使用职业染色
		playerLink = GetPlayerLink(sender, "["..coloredName.."]")
		local colorCode = coloredName:match("|cff(%x%x%x%x%x%x)")
		if colorCode then
			r = tonumber(colorCode:sub(1, 2), 16) / 255
			g = tonumber(colorCode:sub(3, 4), 16) / 255
			b = tonumber(colorCode:sub(5, 6), 16) / 255
		end
	else
		-- 不使用职业染色，使用频道默认颜色
		playerLink = GetPlayerLink(sender, "["..name.."]")
		
		-- 从事件类型获取频道颜色
		local chatType = event:gsub("CHAT_MSG_", "")
		local info = ChatTypeInfo[chatType]
		if info then
			r, g, b = info.r, info.g, info.b
		else
			r, g, b = 1, 1, 1  -- 默认白色
		end
	end
	
	-- 简化消息处理 - 不进行复杂的表达式替换
	local outMsg = Core.HighlightKeyword(message, keyword)
	
	-- 构建输出消息
	local output
	if KeywordMonitorDB.OutputMode == 1 then
		output = format("|cff808080%s|r |cffFFD700%s|r [|cff00FF00关注|r] %s: %s", timeStr, channelName, playerLink, outMsg)
	else
		output = format("|cff808080%s|r |cffFFD700%s|r %s: %s", timeStr, channelName, playerLink, outMsg)
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
	
	-- 保存到历史记录
	if KM.History and KM.History.AddToHistory then
		KM.History.AddToHistory({
			time = timestamp,
			timeStr = timeStr,
			name = name,
			msg = message,
			channelName = channelName,
			r = r,  -- 保存职业颜色
			g = g,
			b = b,
		})
	end
	
	-- 更新统计数据
	if KM.Statistics and KM.Statistics.UpdateStatistics then
		KM.Statistics.UpdateStatistics(keyword, timestamp)
	end
	
	-- 更新性能统计
	if KM.Statistics and KM.Statistics.UpdatePerformance then
		KM.Statistics.UpdatePerformance()
	end
	
	-- 播放提示音
	if KeywordMonitorDB.AudioEnabled then
		PlaySoundFile("Interface\\AddOns\\KeywordMonitor\\Audio\\FollowMsg_1.ogg", "Master")
	end
	
	return false
end

-- 启用/禁用关键词监控
-- @param enabled boolean 是否启用
-- @return void
function Core.ToggleKeywordMonitor(enabled)
	LoadDependencies()
	Config.EnsureConfig()
	KeywordMonitorDB.Enabled = enabled
	
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
		ChatFrame_RemoveMessageEventFilter(eventName, Core.ShowKeywordMessage)
	end
	
	if enabled then
		if KeywordMonitorDB.OutputMode == 2 then
			if not keywordFrame then
				Core.CreateKeywordFrame()
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
				ChatFrame_AddMessageEventFilter(eventName, Core.ShowKeywordMessage)
			end
		end
	else
		if keywordFrame then
			keywordFrame:Hide()
		end
	end
	
	-- 更新按钮状态
	if KM.UI and KM.UI.UpdateButtonStatus then
		KM.UI.UpdateButtonStatus()
	end
end

-- 处理战斗隐藏
-- @return void
function Core.HandleCombatVisibility()
	Config.EnsureConfig()
	if not KeywordMonitorDB.Enabled or KeywordMonitorDB.OutputMode ~= 2 or not KeywordMonitorDB.CombatHide then return end
	if not keywordFrame then return end
	
	if InCombatLockdown() then
		keywordFrame:Hide()
	else
		keywordFrame:Show()
	end
end

-- 创建独立监控窗口
-- @return Frame 创建的监控窗口
function Core.CreateKeywordFrame()
	LoadDependencies()
	-- 如果窗口已存在，直接返回
	if keywordFrame then 
		return keywordFrame 
	end
	
	-- 确保配置已初始化
	Config.EnsureConfig()
	
	-- 创建滚动消息框架
	local frame = CreateFrame("ScrollingMessageFrame", "KeywordMonitor_Frame", UIParent, "BackdropTemplate")
	frame:SetSize(ChatFrame1:GetWidth(), KeywordMonitorDB.KeywordFrameHeight)
	frame:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", 0, 30)
	frame:SetFrameStrata("MEDIUM")
	frame:SetFading(false)
	frame:SetMaxLines(100)
	frame:SetHyperlinksEnabled(true)
	frame:EnableMouse(true)
	frame:EnableMouseWheel(true)
	
	-- 设置字体（继承聊天框架的字体）
	local fontPath, fontSize = ChatFrame1:GetFont()
	frame:SetFont(fontPath, fontSize, "OUTLINE")
	frame:SetShadowColor(0, 0, 0, 0)
	frame:SetJustifyH("LEFT")
	
	-- 创建背景（使用 Utils 模块的函数）
	Utils.CreateBD(frame)
	
	-- 创建滚动到底部按钮
	local scrollBtn = CreateFrame("Button", nil, frame)
	scrollBtn:SetSize(20, 20)
	scrollBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 5)
	scrollBtn:SetAlpha(0.5)
	
	-- 设置按钮图标
	local icon = scrollBtn:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollEnd-Up")
	scrollBtn.icon = icon
	
	-- 按钮交互
	scrollBtn:Hide()
	scrollBtn:SetScript("OnEnter", function(self) 
		self:SetAlpha(1) 
	end)
	scrollBtn:SetScript("OnLeave", function(self) 
		self:SetAlpha(0.5) 
	end)
	scrollBtn:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_CHAT_BOTTOM)
		frame:ScrollToBottom()
		scrollBtn:Hide()
	end)
	frame.ScrollToBottomButton = scrollBtn
	
	-- 鼠标滚轮滚动
	frame:SetScript("OnMouseWheel", function(self, delta)
		if self:GetNumMessages() == 0 then 
			return 
		end
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
	
	-- 初始隐藏窗口
	frame:Hide()
	
	-- 保存到模块变量
	keywordFrame = frame
	
	return frame
end

--[[============================================
    模块初始化
============================================]]--

-- 模块加载完成标记
KM.Core.Loaded = true

-- 调试信息
if KM.Debug then
    print("|cff00ff00KeywordMonitor:|r Core 模块已加载")
end

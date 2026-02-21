--[[
    KeywordMonitor - Statistics Module
    统计分析模块
    
    职责：
    - 提供统计数据的更新和查询功能
    - 管理关键词匹配统计、时段统计
    - 提供趋势分析功能（每日、每小时）
    - 提供关键词关联分析功能
    - 提供性能监控功能（内存、消息处理速度）
    - 提供内存优化和数据清理功能
    - 提供统计和性能监控界面
    
    依赖：Utils 模块、Config 模块
    
    公共接口：
    - UpdateStatistics(matchedKeywords, timestamp) - 更新统计数据
    - GetStatistics() - 获取统计数据
    - ResetStatistics() - 重置统计数据
    - GetTopKeywords(topN) - 获取热门关键词
    - GetTopHours(topN) - 获取活跃时段
    - UpdateTrendData(keywords, timestamp) - 更新趋势数据
    - GetKeywordTrend(keyword, days) - 获取关键词趋势
    - UpdateKeywordCorrelation(keywords) - 更新关键词关联
    - GetKeywordCorrelations(keyword, topN) - 获取关键词关联
    - GetOverallTrend(days) - 获取总体趋势
    - GetTableSize(tbl) - 获取表大小
    - UpdatePerformance() - 更新性能统计
    - GetMemoryUsage() - 获取内存使用
    - GetPerformanceStats() - 获取性能统计
    - OptimizeMemory() - 优化内存
    - CleanOldData() - 清理旧数据
    - DiagnoseMemory() - 诊断内存占用
    - ShowStatisticsUI() - 显示统计界面
    - RefreshStatistics() - 刷新统计数据
    - ShowPerformanceUI() - 显示性能监控界面
    - RefreshPerformance() - 刷新性能数据
--]]

local addonName, addon = ...

-- 确保全局命名空间存在
if not _G.KeywordMonitor then
	_G.KeywordMonitor = {}
end

-- 获取全局命名空间
local KM = _G.KeywordMonitor

-- 创建 Statistics 模块命名空间
KM.Statistics = {}
local Statistics = KM.Statistics

--[[============================================
    本地化全局函数引用
============================================]]--

local pairs, ipairs, type = pairs, ipairs, type
local tinsert, tremove, sort, wipe = table.insert, table.remove, table.sort, wipe or table.wipe
local date = date
local tonumber, tostring = tonumber, tostring
local math_floor, math_max, math_min, math_huge = math.floor, math.max, math.min, math.huge
local sub, format = string.sub, string.format
local print = print
local CreateFrame = CreateFrame
local UIParent = UIParent
local GetServerTime = GetServerTime
local GetTime = GetTime
local time = time
local collectgarbage = collectgarbage
local UpdateAddOnMemoryUsage = UpdateAddOnMemoryUsage
local GetAddOnMemoryUsage = GetAddOnMemoryUsage
local C_Timer = C_Timer
local GameTooltip = GameTooltip
local gsub, gmatch, find = string.gsub, string.gmatch, string.find

--[[============================================
    依赖模块引用
============================================]]--

-- Utils 模块函数
local CreateFS, CreateButton, CreateBD, CreateCloseButton, CleanupUIElements, CreateCheckBox, CreateEditBox

-- Config 模块函数
local EnsureConfig

-- 初始化依赖（在模块加载后）
local function InitDependencies()
	if KM.Utils then
		CreateFS = KM.Utils.CreateFS
		CreateButton = KM.Utils.CreateButton
		CreateBD = KM.Utils.CreateBD
		CreateCloseButton = KM.Utils.CreateCloseButton
		CleanupUIElements = KM.Utils.CleanupUIElements
		CreateCheckBox = KM.Utils.CreateCheckBox
		CreateEditBox = KM.Utils.CreateEditBox
	end
	
	if KM.Config then
		EnsureConfig = KM.Config.EnsureConfig
	end
end

--[[============================================
    本地变量
============================================]]--

-- 性能监控缓存
local lastMemoryCheck = 0
local cachedMemory = 0

-- 趋势数据清理
local lastTrendCleanup = 0

-- 关联分析清理
local lastCorrelationCleanup = 0
local correlationUpdateCount = 0

--[[============================================
    统计数据管理函数
    
    这些函数将在后续任务中从 Core.lua.backup 迁移
============================================]]--

-- 更新统计数据
-- @param matchedKeywords table|string 匹配的关键词列表或单个关键词
-- @param timestamp number 时间戳（可选）
function Statistics.UpdateStatistics(matchedKeywords, timestamp)
	if not EnsureConfig then
		return
	end
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
		Statistics.UpdateKeywordCorrelation(matchedKeywords)
	end
end

-- 获取统计数据
-- @return table 统计数据
function Statistics.GetStatistics()
	if not EnsureConfig then
		return nil
	end
	EnsureConfig()
	return KeywordMonitorDB.Statistics
end

-- 重置统计数据
function Statistics.ResetStatistics()
	if not EnsureConfig then
		return
	end
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

-- 获取热门关键词
-- @param topN number 返回前N个关键词（可选，默认10）
-- @return table 热门关键词列表
function Statistics.GetTopKeywords(topN)
	if not EnsureConfig then
		return {}
	end
	EnsureConfig()
	topN = topN or 10
	
	local list = {}
	for keyword, matchCount in pairs(KeywordMonitorDB.Statistics.KeywordCounts) do
		tinsert(list, {keyword = keyword, count = matchCount})
	end
	
	-- 按匹配次数排序
	sort(list, function(a, b) return a.count > b.count end)
	
	-- 返回前N个
	local result = {}
	for i = 1, math_min(topN, #list) do
		tinsert(result, list[i])
	end
	
	return result
end

-- 获取活跃时段
-- @param topN number 返回前N个时段（可选，默认5）
-- @return table 活跃时段列表
function Statistics.GetTopHours(topN)
	if not EnsureConfig then
		return {}
	end
	EnsureConfig()
	topN = topN or 5
	
	local list = {}
	for hour = 0, 23 do
		local matchCount = KeywordMonitorDB.Statistics.HourCounts[hour] or 0
		tinsert(list, {hour = hour, count = matchCount})
	end
	
	-- 按匹配次数排序
	sort(list, function(a, b) return a.count > b.count end)
	
	-- 返回前N个
	local result = {}
	for i = 1, math_min(topN, #list) do
		tinsert(result, list[i])
	end
	
	return result
end

--[[============================================
    趋势分析函数
============================================]]--

-- 更新趋势数据（优化版 - 减少频繁操作）
-- @param keywords table 关键词列表
-- @param timestamp number 时间戳（可选）
function Statistics.UpdateTrendData(keywords, timestamp)
	if not EnsureConfig then
		return
	end
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
				local minKw, minCount = nil, math_huge
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
				local minKw, minCount = nil, math_huge
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

-- 获取关键词趋势
-- @param keyword string 关键词
-- @param days number 天数（可选，默认7）
-- @return table 趋势数据
function Statistics.GetKeywordTrend(keyword, days)
	if not EnsureConfig then
		return {}
	end
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

-- 获取总体趋势
-- @param days number 天数（可选，默认7）
-- @return table 总体趋势数据
function Statistics.GetOverallTrend(days)
	if not EnsureConfig then
		return {}
	end
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

--[[============================================
    关联分析函数
============================================]]--

-- 更新关键词关联
-- @param keywords table 关键词列表
function Statistics.UpdateKeywordCorrelation(keywords)
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
			totalCorrelations = totalCorrelations + Statistics.GetTableSize(correlations)
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
				if Statistics.GetTableSize(correlations) == 0 then
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
		local correlationCount = Statistics.GetTableSize(correlations)
		
		for j = 1, #keywords do
			if i ~= j then
				local kw2 = keywords[j]
				
				if not correlations[kw2] then
					-- 如果已经有10个关联，删除最少的
					if correlationCount >= 10 then
						local minKw, minCount = nil, math_huge
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

-- 获取关键词关联
-- @param keyword string 关键词
-- @param topN number 返回前N个关联（可选，默认5）
-- @return table 关联关键词列表
function Statistics.GetKeywordCorrelations(keyword, topN)
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
	sort(correlations, function(a, b) return a.count > b.count end)
	
	-- 返回前N个
	local result = {}
	for i = 1, math_min(topN, #correlations) do
		tinsert(result, correlations[i])
	end
	
	return result
end

--[[============================================
    工具函数
============================================]]--

-- 获取表大小
-- @param tbl table 要计算大小的表
-- @return number 表中元素数量
function Statistics.GetTableSize(tbl)
	local count = 0
	for _ in pairs(tbl) do
		count = count + 1
	end
	return count
end

--[[============================================
    性能监控函数
============================================]]--

-- 更新性能统计
function Statistics.UpdatePerformance()
	if not EnsureConfig then
		return
	end
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

-- 获取内存使用（KB）- 使用缓存避免频繁调用
-- @return number 内存使用量（KB）
function Statistics.GetMemoryUsage()
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
-- @return table 性能统计数据
function Statistics.GetPerformanceStats()
	if not EnsureConfig then
		return nil
	end
	EnsureConfig()
	
	return {
		memory = Statistics.GetMemoryUsage(),
		messagesPerSecond = KeywordMonitorDB.Performance.MessagesPerSecond,
		totalMessages = KeywordMonitorDB.Statistics.TotalMatches or 0,
	}
end

--[[============================================
    内存优化函数
============================================]]--

-- 优化内存（优化版 - 使用更高效的清理方式）
-- @return number 清理的数据项数量
function Statistics.OptimizeMemory()
	if not EnsureConfig then
		return 0
	end
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
	
	-- 3. 清理重复消息缓存（通过 Core 模块）
	if KM.Core and KM.Core.CleanRepeatMessageCache then
		local cacheCleared = KM.Core.CleanRepeatMessageCache()
		cleaned = cleaned + cacheCleared
	end
	
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

-- 清理旧数据
function Statistics.CleanOldData()
	if not EnsureConfig then
		return
	end
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
	Statistics.OptimizeMemory()
end

-- 诊断内存占用
function Statistics.DiagnoseMemory()
	if not EnsureConfig then
		return
	end
	EnsureConfig()
	
	print("|cff00FF00[ChatKeyword 内存诊断]|r")
	print("----------------------------------------")
	
	-- 历史记录
	local historyCount = #KeywordMonitorDB.History
	print(string.format("历史记录: %d 条", historyCount))
	
	-- 趋势数据
	local dailyCount = Statistics.GetTableSize(KeywordMonitorDB.TrendData.Daily)
	local hourlyCount = Statistics.GetTableSize(KeywordMonitorDB.TrendData.Hourly)
	print(string.format("趋势数据: 每日 %d 天, 每小时 %d 条", dailyCount, hourlyCount))
	
	-- 关键词关联
	local correlationCount = 0
	for kw1, correlations in pairs(KeywordMonitorDB.KeywordCorrelation) do
		correlationCount = correlationCount + Statistics.GetTableSize(correlations)
	end
	print(string.format("关键词关联: %d 条关联", correlationCount))
	
	-- 统计数据
	local keywordStatsCount = Statistics.GetTableSize(KeywordMonitorDB.Statistics.KeywordCounts)
	print(string.format("统计数据: %d 个关键词", keywordStatsCount))
	
	-- 重复消息缓存（通过 Core 模块获取）
	local cacheCount = 0
	if KM.Core and KM.Core.GetRepeatMessageCacheSize then
		cacheCount = KM.Core.GetRepeatMessageCacheSize()
	end
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

--[[============================================
    统计界面函数
============================================]]--

-- 显示统计界面
function Statistics.ShowStatisticsUI()
	EnsureConfig()
	
	if not KM.statisticsFrame then
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
			Statistics.ResetStatistics()
			Statistics.RefreshStatistics()
		end)
		
		-- 趋势分析按钮
		local trendBtn = CreateButton(frame, 100, 25, "趋势分析")
		trendBtn:SetPoint("BOTTOM", -55, 15)
		trendBtn:SetScript("OnClick", function()
			if KM.ShowTrendAnalysisUI then
				KM:ShowTrendAnalysisUI()
			end
		end)
		
		-- 关联分析按钮
		local correlationBtn = CreateButton(frame, 100, 25, "关联分析")
		correlationBtn:SetPoint("BOTTOM", 55, 15)
		correlationBtn:SetScript("OnClick", function()
			if KM.ShowCorrelationAnalysisUI then
				KM:ShowCorrelationAnalysisUI()
			end
		end)
		
		frame:SetScript("OnShow", function()
			Statistics.RefreshStatistics()
		end)
		
		KM.statisticsFrame = frame
	end
	
	if KM.statisticsFrame:IsShown() then
		KM.statisticsFrame:Hide()
	else
		KM.statisticsFrame:Show()
	end
end

-- 刷新统计数据
function Statistics.RefreshStatistics()
	if not KM.statisticsFrame then
		return
	end
	
	local frame = KM.statisticsFrame
	local stats = Statistics.GetStatistics()
	
	-- 更新今日和总匹配次数
	frame.todayValue:SetText(tostring(stats.TodayMatches))
	frame.totalValue:SetText(tostring(stats.TotalMatches))
	
	-- 更新最常匹配的关键词
	CleanupUIElements(frame.keywordsScrollChild.items)
	frame.keywordsScrollChild.items = {}
	
	local topKeywords = Statistics.GetTopKeywords(10)
	local yOffset = -5
	for i, data in ipairs(topKeywords) do
		local item = CreateFS(frame.keywordsScrollChild, 11, 
			format("%d. %s (%d次)", i, data.keyword, data.count), 
			false, "LEFT")
		item:SetPoint("TOPLEFT", 5, yOffset)
		item:SetTextColor(0.9, 0.9, 0.9)
		tinsert(frame.keywordsScrollChild.items, item)
		yOffset = yOffset - 18
	end
	frame.keywordsScrollChild:SetHeight(math_max(1, -yOffset))
	
	-- 更新最活跃的时间段
	CleanupUIElements(frame.hoursScrollChild.items)
	frame.hoursScrollChild.items = {}
	
	local topHours = Statistics.GetTopHours(10)
	yOffset = -5
	for i, data in ipairs(topHours) do
		local item = CreateFS(frame.hoursScrollChild, 11, 
			format("%d. %02d:00-%02d:59 (%d次)", i, data.hour, data.hour, data.count), 
			false, "LEFT")
		item:SetPoint("TOPLEFT", 5, yOffset)
		item:SetTextColor(0.9, 0.9, 0.9)
		tinsert(frame.hoursScrollChild.items, item)
		yOffset = yOffset - 18
	end
	frame.hoursScrollChild:SetHeight(math_max(1, -yOffset))
	
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
			bar:SetHeight(math_max(1, height))
			
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

--[[============================================
    性能监控界面函数
============================================]]--

-- 显示性能监控界面
function Statistics.ShowPerformanceUI()
	EnsureConfig()
	
	if not KM.performanceFrame then
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
			Statistics.CleanOldData()
			Statistics.RefreshPerformance()
		end)
		
		-- 优化内存按钮
		local optimizeBtn = CreateButton(frame, 120, 25, "优化内存")
		optimizeBtn:SetPoint("LEFT", cleanNowBtn, "RIGHT", 10, 0)
		optimizeBtn:SetScript("OnClick", function()
			Statistics.OptimizeMemory()
			C_Timer.After(0.5, function()
				Statistics.RefreshPerformance()
				print("|cff00FF00[ChatKeyword]|r 内存优化完成")
			end)
		end)
		
		-- 诊断按钮
		local diagnoseBtn = CreateButton(frame, 120, 25, "内存诊断")
		diagnoseBtn:SetPoint("TOPLEFT", 20, -290)
		diagnoseBtn:SetScript("OnClick", function()
			Statistics.DiagnoseMemory()
		end)
		
		-- 内存优化说明
		local optimizeHint = CreateFS(frame, 10, "清理低频数据、强制垃圾回收", false, "LEFT")
		optimizeHint:SetPoint("TOPLEFT", 20, -320)
		optimizeHint:SetTextColor(0.7, 0.7, 0.7)
		
		-- 刷新按钮
		local refreshBtn = CreateButton(frame, 80, 25, "刷新")
		refreshBtn:SetPoint("BOTTOM", 0, 15)
		refreshBtn:SetScript("OnClick", function()
			Statistics.RefreshPerformance()
		end)
		
		-- 自动刷新
		frame:SetScript("OnShow", function()
			Statistics.RefreshPerformance()
			-- 每5秒刷新一次（从2秒改为5秒，减少刷新频率）
			if not frame.ticker then
				frame.ticker = C_Timer.NewTicker(5, function()
					if frame:IsShown() then
						Statistics.RefreshPerformance()
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
		
		KM.performanceFrame = frame
	end
	
	if KM.performanceFrame:IsShown() then
		KM.performanceFrame:Hide()
	else
		KM.performanceFrame:Show()
	end
end

-- 刷新性能数据
function Statistics.RefreshPerformance()
	if not KM.performanceFrame then
		return
	end
	
	local frame = KM.performanceFrame
	local stats = Statistics.GetPerformanceStats()
	
	frame.memValue:SetText(format("%.2f KB", stats.memory))
	frame.speedValue:SetText(format("%.2f 条/秒", stats.messagesPerSecond))
	frame.totalValue:SetText(format("%d 条", stats.totalMessages))
	
	-- 根据内存使用设置颜色
	if stats.memory < 500 then
		frame.memValue:SetTextColor(0, 1, 0)
	elseif stats.memory < 1000 then
		frame.memValue:SetTextColor(1, 1, 0)
	else
		frame.memValue:SetTextColor(1, 0, 0)
	end
end

--[[============================================
    趋势分析和关联分析界面函数
============================================]]--

-- 显示趋势分析界面
function Statistics.ShowTrendAnalysisUI()
	EnsureConfig()
	
	if not KM.trendFrame then
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
		
		frame:SetScript("OnShow", function()
			Statistics.RefreshTrendAnalysis()
		end)
		
		KM.trendFrame = frame
	end
	
	if KM.trendFrame:IsShown() then
		KM.trendFrame:Hide()
	else
		KM.trendFrame:Show()
	end
end

-- 刷新趋势数据
function Statistics.RefreshTrendAnalysis(selectedKeyword)
	if not KM.trendFrame then
		return
	end
	
	local frame = KM.trendFrame
	
	-- 刷新总体趋势
	local overallTrend = Statistics.GetOverallTrend(7)
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
			bar:SetHeight(math_max(1, height))
			
			-- 日期格式：02-20 (从 "2026-02-15" 提取月-日)
			local year, month, day = data.date:match("(%d+)-(%d+)-(%d+)")
			if month and day then
				bar.dateLabel:SetText(month .. "-" .. day)
			else
				bar.dateLabel:SetText(data.date)
			end
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
	
	local topKeywords = Statistics.GetTopKeywords(20)
	local yOffset = -5
	for i, data in ipairs(topKeywords) do
		local btn = CreateButton(frame.kwChild, 170, 25, data.keyword .. " (" .. data.count .. ")")
		btn:SetPoint("TOPLEFT", 5, yOffset)
		btn:SetScript("OnClick", function()
			Statistics.RefreshTrendAnalysis(data.keyword)
		end)
		
		tinsert(frame.kwChild.items, btn)
		yOffset = yOffset - 30
	end
	frame.kwChild:SetHeight(math_max(1, -yOffset))
	
	-- 刷新选中关键词的趋势
	if selectedKeyword then
		frame.selectedTitle:SetText(selectedKeyword .. " 的趋势")
		
		local kwTrend = Statistics.GetKeywordTrend(selectedKeyword, 7)
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
				bar:SetHeight(math_max(1, height))
				
				-- 日期格式：02-20 (从 "2026-02-15" 提取月-日)
				local year, month, day = data.date:match("(%d+)-(%d+)-(%d+)")
				if month and day then
					bar.dateLabel:SetText(month .. "-" .. day)
				else
					bar.dateLabel:SetText(data.date)
				end
				bar.countLabel:SetText(tostring(data.count))
			end
		end
	else
		for _, bar in ipairs(frame.selectedBars) do
			bar:Hide()
		end
	end
end

-- 显示关联分析界面（简化版 - 不包含复杂的智能分析功能）
function Statistics.ShowCorrelationAnalysisUI()
	EnsureConfig()
	
	if not KM.correlationFrame then
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
		
		local title = CreateFS(frame, 16, "关联分析 - 关键词关联", true)
		title:SetPoint("TOP", 0, -10)
		
		local closeBtn = CreateCloseButton(frame)
		closeBtn:SetPoint("TOPRIGHT", -10, -10)
		closeBtn:SetScript("OnClick", function() frame:Hide() end)
		
		-- 说明文字
		local desc = CreateFS(frame, 11, "查看经常一起出现的关键词组合", false, "LEFT")
		desc:SetPoint("TOPLEFT", 20, -40)
		desc:SetTextColor(0.7, 0.7, 0.7)
		
		-- 关键词列表标签
		local kwLabel = CreateFS(frame, 14, "选择关键词:", false, "LEFT")
		kwLabel:SetPoint("TOPLEFT", 20, -70)
		kwLabel:SetTextColor(1, 0.8, 0)
		
		-- 关键词列表
		local kwScroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
		kwScroll:SetPoint("TOPLEFT", 20, -95)
		kwScroll:SetSize(250, 360)
		
		local kwChild = CreateFrame("Frame", nil, kwScroll)
		kwChild:SetSize(230, 1)
		kwChild.items = {}
		kwScroll:SetScrollChild(kwChild)
		frame.kwChild = kwChild
		
		-- 关联关键词标签
		local correlationLabel = CreateFS(frame, 14, "关联关键词:", false, "LEFT")
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
		
		frame:SetScript("OnShow", function()
			Statistics.RefreshCorrelationAnalysis()
		end)
		
		KM.correlationFrame = frame
	end
	
	if KM.correlationFrame:IsShown() then
		KM.correlationFrame:Hide()
	else
		KM.correlationFrame:Show()
	end
end

-- 刷新关联分析
function Statistics.RefreshCorrelationAnalysis(selectedKeyword)
	if not KM.correlationFrame then
		return
	end
	
	local frame = KM.correlationFrame
	
	-- 清空旧内容
	CleanupUIElements(frame.kwChild.items)
	frame.kwChild.items = {}
	CleanupUIElements(frame.correlationChild.items)
	frame.correlationChild.items = {}
	
	-- 显示关键词列表（左侧）
	local topKeywords = Statistics.GetTopKeywords(20)
	
	if #topKeywords == 0 then
		local noData = CreateFS(frame.kwChild, 12, "暂无数据", false, "CENTER")
		noData:SetPoint("CENTER", 0, 0)
		noData:SetTextColor(0.5, 0.5, 0.5)
		tinsert(frame.kwChild.items, noData)
		frame.kwChild:SetHeight(1)
	else
		local yOffset = -5
		for i, data in ipairs(topKeywords) do
			local btn = CreateButton(frame.kwChild, 220, 25, data.keyword .. " (" .. data.count .. ")")
			btn:SetPoint("TOPLEFT", 5, yOffset)
			btn:SetScript("OnClick", function()
				Statistics.RefreshCorrelationAnalysis(data.keyword)
			end)
			
			tinsert(frame.kwChild.items, btn)
			yOffset = yOffset - 30
		end
		frame.kwChild:SetHeight(math_max(1, -yOffset))
	end
	
	-- 显示关联关键词（右侧）
	if selectedKeyword then
		frame.correlationLabel:SetText("\"" .. selectedKeyword .. "\" 的关联关键词:")
		
		local correlations = Statistics.GetKeywordCorrelations(selectedKeyword, 10)
		
		if #correlations == 0 then
			local noData = CreateFS(frame.correlationChild, 12, "暂无关联数据", false, "CENTER")
			noData:SetPoint("CENTER", 0, 0)
			noData:SetTextColor(0.5, 0.5, 0.5)
			tinsert(frame.correlationChild.items, noData)
			frame.correlationChild:SetHeight(1)
		else
			local yOffset = -5
			for i, data in ipairs(correlations) do
				local item = CreateFS(frame.correlationChild, 12, 
					format("%d. %s (共现 %d 次)", i, data.keyword, data.count), 
					false, "LEFT")
				item:SetPoint("TOPLEFT", 10, yOffset)
				item:SetTextColor(0.9, 0.9, 0.9)
				tinsert(frame.correlationChild.items, item)
				yOffset = yOffset - 25
			end
			frame.correlationChild:SetHeight(math_max(1, -yOffset))
		end
	else
		frame.correlationLabel:SetText("关联关键词:")
		local hint = CreateFS(frame.correlationChild, 12, "请选择一个关键词", false, "CENTER")
		hint:SetPoint("CENTER", 0, 0)
		hint:SetTextColor(0.5, 0.5, 0.5)
		tinsert(frame.correlationChild.items, hint)
		frame.correlationChild:SetHeight(1)
	end
end

--[[============================================
    向后兼容性接口
============================================]]--

-- 为 KM 命名空间添加向后兼容的方法
function KM:UpdateStatistics(matchedKeywords, timestamp)
	return Statistics.UpdateStatistics(matchedKeywords, timestamp)
end

function KM:GetStatistics()
	return Statistics.GetStatistics()
end

function KM:ResetStatistics()
	return Statistics.ResetStatistics()
end

function KM:GetTopKeywords(topN)
	return Statistics.GetTopKeywords(topN)
end

function KM:GetTopHours(topN)
	return Statistics.GetTopHours(topN)
end

function KM:UpdateTrendData(keywords, timestamp)
	return Statistics.UpdateTrendData(keywords, timestamp)
end

function KM:GetKeywordTrend(keyword, days)
	return Statistics.GetKeywordTrend(keyword, days)
end

function KM:UpdateKeywordCorrelation(keywords)
	return Statistics.UpdateKeywordCorrelation(keywords)
end

function KM:GetKeywordCorrelations(keyword, topN)
	return Statistics.GetKeywordCorrelations(keyword, topN)
end

function KM:GetOverallTrend(days)
	return Statistics.GetOverallTrend(days)
end

function KM:GetTableSize(tbl)
	return Statistics.GetTableSize(tbl)
end

function KM:UpdatePerformance()
	return Statistics.UpdatePerformance()
end

function KM:GetMemoryUsage()
	return Statistics.GetMemoryUsage()
end

function KM:GetPerformanceStats()
	return Statistics.GetPerformanceStats()
end

function KM:OptimizeMemory()
	return Statistics.OptimizeMemory()
end

function KM:CleanOldData()
	return Statistics.CleanOldData()
end

function KM:DiagnoseMemory()
	return Statistics.DiagnoseMemory()
end

function KM:ShowStatisticsUI()
	return Statistics.ShowStatisticsUI()
end

function KM:RefreshStatistics()
	return Statistics.RefreshStatistics()
end

function KM:ShowPerformanceUI()
	return Statistics.ShowPerformanceUI()
end

function KM:RefreshPerformance()
	return Statistics.RefreshPerformance()
end

function KM:ShowTrendAnalysisUI()
	return Statistics.ShowTrendAnalysisUI()
end

function KM:RefreshTrendAnalysis(selectedKeyword)
	return Statistics.RefreshTrendAnalysis(selectedKeyword)
end

function KM:ShowCorrelationAnalysisUI()
	return Statistics.ShowCorrelationAnalysisUI()
end

function KM:RefreshCorrelationAnalysis(selectedKeyword)
	return Statistics.RefreshCorrelationAnalysis(selectedKeyword)
end

--[[============================================
    模块初始化
============================================]]--

-- 初始化依赖
InitDependencies()

-- 模块加载完成标记
KM.Statistics.Loaded = true

-- 调试信息
if KM.Debug then
    print("|cff00ff00KeywordMonitor:|r Statistics 模块已加载")
end

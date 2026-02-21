--[[
    KeywordMonitor - Config Module
    配置管理模块
    
    职责：
    - 提供配置初始化和验证功能
    - 管理默认配置定义
    - 确保配置数据结构完整性
    - 保持与 KeywordMonitorDB SavedVariables 的兼容性
    
    依赖：Utils 模块
    
    公共接口：
    - EnsureConfig() - 初始化和验证配置
    - GetDefaultConfig() - 获取默认配置的副本
--]]

local addonName, addon = ...

-- 确保全局命名空间存在
if not _G.KeywordMonitor then
	_G.KeywordMonitor = {}
end

-- 获取全局命名空间（不使用 local 变量）
local KM = _G.KeywordMonitor

-- 创建 Config 模块命名空间
KM.Config = {}
local Config = KM.Config

--[[============================================
    本地化全局函数引用
============================================]]--

local pairs, ipairs, type = pairs, ipairs, type
local date = date
local GetServerTime = GetServerTime
local GetTime = GetTime

--[[============================================
    默认配置定义
============================================]]--

-- 默认配置
local defaultConfig = {
	Enabled = false,
	Keywords = "",
	AudioEnabled = true,
	ClassColorEnabled = true,  -- 是否启用职业染色（默认开启）
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

--[[============================================
    配置管理函数
============================================]]--

-- 获取默认配置的副本
-- @return table 默认配置的深拷贝
function Config.GetDefaultConfig()
	local copy = {}
	for k, v in pairs(defaultConfig) do
		if type(v) == "table" then
			copy[k] = {}
			for sk, sv in pairs(v) do
				if type(sv) == "table" then
					-- 处理嵌套表（如 KeywordGroups）
					copy[k][sk] = {}
					for ssk, ssv in pairs(sv) do
						copy[k][sk][ssk] = ssv
					end
				else
					copy[k][sk] = sv
				end
			end
		else
			copy[k] = v
		end
	end
	return copy
end

-- 初始化配置
-- 确保所有必需的配置项存在，合并用户配置和默认配置
function Config.EnsureConfig()
	if not KeywordMonitorDB then
		KeywordMonitorDB = {}
	end
	
	-- 合并默认配置到用户配置
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

--[[============================================
    模块初始化
============================================]]--

-- 模块加载完成标记
KM.Config.Loaded = true

-- 调试信息
if KM.Debug then
    print("|cff00ff00KeywordMonitor:|r Config 模块已加载")
end

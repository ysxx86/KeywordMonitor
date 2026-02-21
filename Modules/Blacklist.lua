--[[
    KeywordMonitor - Blacklist Module
    黑名单管理模块
    
    职责：
    - 提供黑名单检查功能
    - 管理玩家黑名单和关键词黑名单
    - 支持黑名单的查询和过滤
    
    依赖：Utils 模块、Config 模块
    
    公共接口：
    - IsBlacklisted(name, text) - 检查玩家或消息是否在黑名单中
    - GetBlacklistPlayers() - 获取玩家黑名单列表
    - GetBlacklistKeywords() - 获取关键词黑名单列表
--]]

local addonName, addon = ...

-- 确保全局命名空间存在
if not _G.KeywordMonitor then
	_G.KeywordMonitor = {}
end

-- 获取全局命名空间
local KM = _G.KeywordMonitor

-- 创建 Blacklist 模块命名空间
KM.Blacklist = {}
local Blacklist = KM.Blacklist

--[[============================================
    本地化全局函数引用
============================================]]--

local pairs = pairs
local tinsert = table.insert
local upper, find = string.upper, string.find

--[[============================================
    依赖模块引用
============================================]]--

-- Utils 模块函数
local CleanText

-- 初始化依赖（在模块加载后）
local function InitDependencies()
	if KM.Utils then
		CleanText = KM.Utils.CleanText
	end
end

--[[============================================
    黑名单检查函数
============================================]]--

-- 检查是否在黑名单中
-- @param name string 玩家名称（可选）
-- @param text string 消息文本（可选）
-- @return boolean 如果在黑名单中返回 true，否则返回 false
function Blacklist.IsBlacklisted(name, text)
	if not KeywordMonitorDB or not KeywordMonitorDB.Blacklist then
		return false
	end
	
	-- 检查玩家黑名单
	if name and KeywordMonitorDB.Blacklist.Players[name] then
		return true
	end
	
	-- 检查关键词黑名单
	if text and CleanText then
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

-- 获取玩家黑名单列表
-- @return table 玩家名称数组（已排序）
function Blacklist.GetBlacklistPlayers()
	if not KeywordMonitorDB or not KeywordMonitorDB.Blacklist then
		return {}
	end
	
	local list = {}
	for name, _ in pairs(KeywordMonitorDB.Blacklist.Players) do
		tinsert(list, name)
	end
	table.sort(list)
	return list
end

-- 获取关键词黑名单列表
-- @return table 关键词数组（已排序）
function Blacklist.GetBlacklistKeywords()
	if not KeywordMonitorDB or not KeywordMonitorDB.Blacklist then
		return {}
	end
	
	local list = {}
	for keyword, _ in pairs(KeywordMonitorDB.Blacklist.Keywords) do
		tinsert(list, keyword)
	end
	table.sort(list)
	return list
end

--[[============================================
    向后兼容性接口
============================================]]--

-- 为 KM 命名空间添加向后兼容的方法
function KM:GetBlacklistPlayers()
	return Blacklist.GetBlacklistPlayers()
end

function KM:GetBlacklistKeywords()
	return Blacklist.GetBlacklistKeywords()
end

--[[============================================
    模块初始化
============================================]]--

-- 初始化依赖
InitDependencies()

-- 模块加载完成标记
KM.Blacklist.Loaded = true

-- 调试信息
if KM.Debug then
    print("|cff00ff00KeywordMonitor:|r Blacklist 模块已加载")
end

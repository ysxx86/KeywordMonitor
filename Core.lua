-- 聊天关键词提取过滤插件 (ChatKeyword)
-- 作者：专业打地鼠
-- 版本：1.8.0
-- 支持 NDui 美化和原生 UI

-- ============================================
-- 插件基本信息和全局命名空间初始化
-- ============================================

local addonName = "KeywordMonitor"
local addonVersion = "2.0.0"
local addonAuthor = "专业打地鼠"

-- 使用已存在的全局命名空间（不要创建新的空表）
local KM = _G.KeywordMonitor or {}
_G[addonName] = KM
_G["KeywordMonitor"] = KM

-- 本地化全局函数（性能优化）
local _G = _G
local type, pairs, ipairs = type, pairs, ipairs
local date, GetServerTime, GetTime = date, GetServerTime, GetTime
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local strsplit, strlower = strsplit, string.lower
local print = print

-- ============================================
-- NDui 检测
-- ============================================

local hasNDui = IsAddOnLoaded("NDui")
local B, C, L, DB
if hasNDui then
	local ns = select(2, ...)
	B, C, L, DB = unpack(ns)
end

-- ============================================
-- 版本检查和更新日志
-- ============================================

-- 检查是否需要显示更新日志
function KM:CheckVersionUpdate()
	if not KeywordMonitorDB then return end
	
	local currentVersion = addonVersion
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
		print("|cff00FF00作者：|r " .. addonAuthor)
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
		print("|cffFFFF00v2.0.0 更新内容：|r")
		print("  • 完成代码模块化重构")
		print("  • 将 6000+ 行代码拆分为 11 个独立模块")
		print("  • 新增职业染色开关功能")
		print("  • 提高代码可维护性和可扩展性")
		print("  • 优化模块加载顺序和性能")
		print("  • 保持所有原有功能不变")
		print("  • 保持数据完全兼容")
		print("|cff00FF00===========================================|r")
	end
end

-- ============================================
-- 模块加载错误处理
-- ============================================

-- 检查模块是否已加载
local function CheckModule(moduleName)
	if not KM[moduleName] then
		print("|cffFF0000[ChatKeyword 错误]|r 模块 " .. moduleName .. " 未加载")
		return false
	end
	return true
end

-- 安全调用模块函数
local function SafeModuleCall(moduleName, funcName, ...)
	if not KM[moduleName] then
		print("|cffFF0000[ChatKeyword 错误]|r 模块 " .. moduleName .. " 不可用")
		return false, "模块未加载"
	end
	
	if not KM[moduleName][funcName] then
		print("|cffFF0000[ChatKeyword 错误]|r 函数 " .. moduleName .. "." .. funcName .. " 不存在")
		return false, "函数不存在"
	end
	
	local success, result = pcall(KM[moduleName][funcName], ...)
	if not success then
		print("|cffFF0000[ChatKeyword 错误]|r 调用 " .. moduleName .. "." .. funcName .. " 失败: " .. tostring(result))
		return false, result
	end
	
	return true, result
end

-- 验证关键模块
local function ValidateCriticalModules()
	local criticalModules = {"Config", "Core", "UI", "Utils"}
	local allLoaded = true
	
	for _, moduleName in ipairs(criticalModules) do
		local module = KM[moduleName]
		if not module then
			print("|cffFF0000[ChatKeyword 严重错误]|r 关键模块 " .. moduleName .. " 未加载，插件可能无法正常工作")
			allLoaded = false
		end
	end
	
	return allLoaded
end

-- ============================================
-- 插件初始化
-- ============================================

function KM:Init()
	-- 验证关键模块是否加载
	local criticalModulesLoaded = ValidateCriticalModules()
	if not criticalModulesLoaded then
		print("|cffFF0000[ChatKeyword]|r 插件初始化失败：关键模块缺失")
		return
	end
	
	-- 确保配置已初始化（由 Config 模块提供）
	local success, err = SafeModuleCall("Config", "EnsureConfig")
	if not success then
		print("|cffFF0000[ChatKeyword]|r 配置初始化失败: " .. tostring(err))
		return
	end
	
	C_Timer.After(2, function()
		-- 更新关键词列表（由 Core 模块提供）
		if KeywordMonitorDB.Keywords and KeywordMonitorDB.Keywords ~= "" then
			if CheckModule("Core") then
				local success, err = pcall(KM.Core.UpdateKeywordList, KeywordMonitorDB.Keywords)
				if not success then
					print("|cffFF0000[ChatKeyword]|r 更新关键词列表失败: " .. tostring(err))
				end
			end
		end
		
		-- 创建控制按钮（由 UI 模块提供）
		if CheckModule("UI") then
			local success, err = pcall(KM.UI.CreateKeywordButton)
			if not success then
				print("|cffFF0000[ChatKeyword]|r 创建控制按钮失败: " .. tostring(err))
			end
		end
		
		-- 启用监控（由 Core 模块提供）
		if KeywordMonitorDB.Enabled then
			if CheckModule("Core") then
				local success, err = pcall(KM.Core.ToggleKeywordMonitor, true)
				if not success then
					print("|cffFF0000[ChatKeyword]|r 启用监控失败: " .. tostring(err))
				end
			end
		end
		
		-- 启动时间触发检查（由 Groups 模块提供）
		if CheckModule("Groups") then
			local success, err = pcall(KM.Groups.CheckTimeTriggers)
			if not success then
				print("|cffFF0000[ChatKeyword]|r 时间触发检查失败: " .. tostring(err))
			else
				-- 每分钟检查一次时间触发
				C_Timer.NewTicker(60, function()
					pcall(KM.Groups.CheckTimeTriggers)
				end)
			end
		end
		
		-- 检查版本更新
		local success, err = pcall(KM.CheckVersionUpdate, KM)
		if not success then
			print("|cffFF0000[ChatKeyword]|r 版本检查失败: " .. tostring(err))
		end
		
		-- 清理旧数据（由 Statistics 模块提供）
		if CheckModule("Statistics") then
			local success, err = pcall(KM.Statistics.CleanOldData)
			if not success then
				print("|cffFF0000[ChatKeyword]|r 清理旧数据失败: " .. tostring(err))
			else
				-- 每天清理一次旧数据
				C_Timer.NewTicker(86400, function()
					pcall(KM.Statistics.CleanOldData)
				end)
			end
		end
		
		-- 每小时优化一次内存（由 Statistics 模块提供）
		if CheckModule("Statistics") then
			C_Timer.NewTicker(3600, function()
				pcall(KM.Statistics.OptimizeMemory)
			end)
		end
		
		-- 每5分钟清理一次重复消息缓存（由 Core 模块提供）
		if CheckModule("Core") then
			C_Timer.NewTicker(300, function()
				pcall(KM.Core.CleanRepeatMessageCache)
			end)
		end
		
		-- 每60秒执行一次轻量级垃圾回收
		C_Timer.NewTicker(60, function()
			collectgarbage("step", 100)  -- 增量式GC，不会造成卡顿
		end)
	end)
	
	-- 注册战斗事件（由 Core 模块提供）
	if CheckModule("Core") then
		local eventFrame = CreateFrame("Frame")
		eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
		eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		eventFrame:SetScript("OnEvent", function(self, event)
			pcall(KM.Core.HandleCombatVisibility)
		end)
	end
	
	-- 注册斜杠命令
	KM:RegisterSlashCommands()
end

-- ============================================
-- 斜杠命令注册
-- ============================================

function KM:RegisterSlashCommands()
	SlashCmdList["KEYWORDMONITOR"] = function(msg)
		local cmd, args = strsplit(" ", msg, 2)
		cmd = strlower(cmd or "")
		
		if cmd == "on" or cmd == "开启" then
			KeywordMonitorDB.Enabled = true
			if CheckModule("Core") then
				local success, err = pcall(KM.Core.ToggleKeywordMonitor, true)
				if success then
					print("|cff00FF00[ChatKeyword]|r 关键词提取已开启")
				else
					print("|cffFF0000[ChatKeyword]|r 开启失败: " .. tostring(err))
				end
			end
			
		elseif cmd == "off" or cmd == "关闭" then
			KeywordMonitorDB.Enabled = false
			if CheckModule("Core") then
				local success, err = pcall(KM.Core.ToggleKeywordMonitor, false)
				if success then
					print("|cff00FF00[ChatKeyword]|r 关键词提取已关闭")
				else
					print("|cffFF0000[ChatKeyword]|r 关闭失败: " .. tostring(err))
				end
			end
			
		elseif cmd == "set" or cmd == "设置" then
			if args and args ~= "" then
				KeywordMonitorDB.Keywords = args
				if CheckModule("Core") then
					local success, err = pcall(KM.Core.UpdateKeywordList, args)
					if success then
						print("|cff00FF00[ChatKeyword]|r 关键词已设置为: " .. args)
					else
						print("|cffFF0000[ChatKeyword]|r 设置失败: " .. tostring(err))
					end
				end
			else
				print("|cff00FF00[ChatKeyword]|r 用法: /keyword set 关键词1,关键词2")
			end
			
		elseif cmd == "debug" or cmd == "调试" then
			if CheckModule("Core") and KM.Core.DebugKeywords then
				local success, err = pcall(KM.Core.DebugKeywords)
				if not success then
					print("|cffFF0000[ChatKeyword]|r 调试失败: " .. tostring(err))
				end
			else
				print("|cff00FF00[ChatKeyword]|r 调试功能不可用")
			end
			
		elseif cmd == "memory" or cmd == "内存" then
			if CheckModule("Statistics") and KM.Statistics.DiagnoseMemory then
				local success, err = pcall(KM.Statistics.DiagnoseMemory)
				if not success then
					print("|cffFF0000[ChatKeyword]|r 内存诊断失败: " .. tostring(err))
				end
			else
				print("|cff00FF00[ChatKeyword]|r 内存诊断功能不可用")
			end
			
		elseif cmd == "optimize" or cmd == "优化" then
			print("|cff00FF00[ChatKeyword]|r 正在优化内存...")
			if CheckModule("Statistics") then
				local success, err = pcall(KM.Statistics.OptimizeMemory)
				if not success then
					print("|cffFF0000[ChatKeyword]|r 优化失败: " .. tostring(err))
				end
			end
			C_Timer.After(0.5, function()
				print("|cff00FF00[ChatKeyword]|r 内存优化完成")
				if CheckModule("Statistics") and KM.Statistics.GetMemoryUsage then
					local success, memory = pcall(KM.Statistics.GetMemoryUsage)
					if success then
						print(string.format("|cff00FF00[ChatKeyword]|r 当前内存: %.2f KB", memory))
					end
				end
			end)
			
		elseif cmd == "config" or cmd == "配置" or cmd == "" then
			if CheckModule("UI") and KM.UI.ShowConfigFrame then
				local success, err = pcall(KM.UI.ShowConfigFrame)
				if not success then
					print("|cffFF0000[ChatKeyword]|r 打开配置界面失败: " .. tostring(err))
				end
			else
				print("|cff00FF00[ChatKeyword]|r 配置界面不可用")
			end
			
		else
			print("|cff00FF00[ChatKeyword]|r 命令列表：")
			print("  /keyword - 打开配置界面")
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

-- ============================================
-- 插件加载事件
-- ============================================

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addon)
	if addon == addonName then
		local success, err = pcall(KM.Init, KM)
		if not success then
			print("|cffFF0000[ChatKeyword 严重错误]|r 插件初始化失败: " .. tostring(err))
			print("|cffFF0000[ChatKeyword]|r 请检查插件文件是否完整，或尝试重新安装")
		end
		self:UnregisterEvent("ADDON_LOADED")
	end
end)

--[[
    KeywordMonitor - Groups Module
    关键词分组管理模块
    
    职责：
    - 提供关键词分组的增删改查功能
    - 管理分组的启用/禁用状态
    - 支持分组颜色设置
    - 提供时间触发功能
    - 提供分组管理界面
    
    依赖：Utils 模块、Config 模块、Core 模块
    
    公共接口：
    - AddKeywordGroup(name, keywords, color) - 添加关键词组
    - RemoveKeywordGroup(index) - 删除关键词组
    - UpdateKeywordGroup(index, name, keywords, enabled, color) - 更新关键词组
    - GetEnabledKeywordGroups() - 获取所有启用的关键词组
    - ShowKeywordGroupsUI() - 显示分组管理界面
    - RefreshGroupsList() - 刷新分组列表
    - SetTimeTrigger(groupIndex, startHour, endHour) - 设置时间触发
    - RemoveTimeTrigger(groupIndex) - 移除时间触发
    - CheckTimeTriggers() - 检查并应用时间触发
--]]

local addonName, addon = ...

-- 确保全局命名空间存在
if not _G.KeywordMonitor then
	_G.KeywordMonitor = {}
end

-- 获取全局命名空间
local KM = _G.KeywordMonitor

-- 创建 Groups 模块命名空间
KM.Groups = {}
local Groups = KM.Groups

--[[============================================
    本地化全局函数引用
============================================]]--

local pairs, ipairs = pairs, ipairs
local tinsert, tremove = table.insert, table.remove
local math_random = math.random
local date = date
local tonumber = tonumber
local tostring = tostring
local print = print
local CreateFrame = CreateFrame
local UIParent = UIParent
local GetServerTime = GetServerTime

--[[============================================
    依赖模块引用
============================================]]--

-- Utils 模块函数
local CreateFS, CreateButton, CreateCheckBox, CreateEditBox, CreateCloseButton, CleanupUIElements

-- Config 模块函数
local EnsureConfig

-- 初始化依赖（在模块加载后）
local function InitDependencies()
	if KM.Utils then
		CreateFS = KM.Utils.CreateFS
		CreateButton = KM.Utils.CreateButton
		CreateCheckBox = KM.Utils.CreateCheckBox
		CreateEditBox = KM.Utils.CreateEditBox
		CreateCloseButton = KM.Utils.CreateCloseButton
		CleanupUIElements = KM.Utils.CleanupUIElements
	end
	
	if KM.Config then
		EnsureConfig = KM.Config.EnsureConfig
	end
end

--[[============================================
    分组管理函数
============================================]]--

-- 添加关键词组
-- @param name string 分组名称
-- @param keywords string 关键词列表（逗号分隔）
-- @param color table RGB颜色值 {r, g, b}
-- @return table 新创建的分组对象
function Groups.AddKeywordGroup(name, keywords, color)
	EnsureConfig()
	
	local group = {
		name = name or "新分组",
		keywords = keywords or "",
		enabled = true,
		color = color or {math_random(), math_random(), math_random()},
	}
	
	tinsert(KeywordMonitorDB.KeywordGroups, group)
	print("|cff00FF00[ChatKeyword]|r 已添加关键词组: " .. group.name)
	
	return group
end

-- 删除关键词组
-- @param index number 分组索引
function Groups.RemoveKeywordGroup(index)
	EnsureConfig()
	if index and KeywordMonitorDB.KeywordGroups[index] then
		local name = KeywordMonitorDB.KeywordGroups[index].name
		tremove(KeywordMonitorDB.KeywordGroups, index)
		print("|cff00FF00[ChatKeyword]|r 已删除关键词组: " .. name)
		-- 删除后更新关键词列表
		if KM.Core and KM.Core.UpdateKeywordList then
			KM.Core.UpdateKeywordList()
		end
	else
		print("|cffFF0000[ChatKeyword]|r 删除失败: 无效的索引 " .. tostring(index))
	end
end

-- 更新关键词组
-- @param index number 分组索引
-- @param name string 分组名称（可选）
-- @param keywords string 关键词列表（可选）
-- @param enabled boolean 启用状态（可选）
-- @param color table RGB颜色值（可选）
function Groups.UpdateKeywordGroup(index, name, keywords, enabled, color)
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
-- @return table 启用的分组数组
function Groups.GetEnabledKeywordGroups()
	EnsureConfig()
	local enabled = {}
	for _, group in ipairs(KeywordMonitorDB.KeywordGroups) do
		if group.enabled then
			tinsert(enabled, group)
		end
	end
	return enabled
end

--[[============================================
    时间触发函数
============================================]]--

-- 设置时间触发
-- @param groupIndex number 分组索引
-- @param startHour number 开始小时（0-23）
-- @param endHour number 结束小时（0-23）
function Groups.SetTimeTrigger(groupIndex, startHour, endHour)
	EnsureConfig()
	
	if not groupIndex or not startHour or not endHour then return end
	
	KeywordMonitorDB.TimeTriggers[groupIndex] = {
		startHour = startHour,
		endHour = endHour,
	}
	
	print("|cff00FF00[ChatKeyword]|r 已设置时间触发: " .. startHour .. ":00 - " .. endHour .. ":59")
end

-- 移除时间触发
-- @param groupIndex number 分组索引
function Groups.RemoveTimeTrigger(groupIndex)
	EnsureConfig()
	
	if KeywordMonitorDB.TimeTriggers[groupIndex] then
		KeywordMonitorDB.TimeTriggers[groupIndex] = nil
		print("|cff00FF00[ChatKeyword]|r 已移除时间触发")
	end
end

-- 检查并应用时间触发
function Groups.CheckTimeTriggers()
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
				if KM.Core and KM.Core.UpdateKeywordList then
					KM.Core.UpdateKeywordList()
				end
			end
		end
	end
end

--[[============================================
    分组管理界面
============================================]]--

-- 刷新分组列表
function Groups.RefreshGroupsList()
	print("|cffFFFF00[Debug]|r RefreshGroupsList 被调用")
	
	-- 使用保存在frame上的scrollChild
	local scrollChild = KM.groupsFrame and KM.groupsFrame.scrollChild
	if not scrollChild then
		print("|cffFF0000[ChatKeyword]|r 刷新失败: scrollChild不存在")
		print("|cffFF0000[Debug]|r KM.groupsFrame = " .. tostring(KM.groupsFrame))
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
			Groups.UpdateKeywordGroup(currentIndex, nil, nil, self:GetChecked())
			if KM.Core and KM.Core.UpdateKeywordList then
				KM.Core.UpdateKeywordList()
			end
		end)
		groupFrame.enableCheck = enableCheck
		
		-- 分组名称
		local nameBox = CreateEditBox(groupFrame, 150, 25)
		nameBox:SetPoint("LEFT", enableCheck, "RIGHT", 5, 0)
		nameBox:SetText(group.name)
		
		-- 只在回车或失去焦点时保存
		nameBox:SetScript("OnEnterPressed", function(self)
			Groups.UpdateKeywordGroup(currentIndex, self:GetText())
			self:ClearFocus()
		end)
		
		nameBox:SetScript("OnEditFocusLost", function(self)
			Groups.UpdateKeywordGroup(currentIndex, self:GetText())
		end)
		
		groupFrame.nameBox = nameBox
		
		-- 删除按钮
		local delBtn = CreateButton(groupFrame, 50, 20, "删除")
		delBtn:SetPoint("TOPRIGHT", -10, -10)
		delBtn:SetScript("OnClick", function()
			print("|cffFFFF00[Debug]|r 删除按钮被点击，索引: " .. currentIndex)
			print("|cffFFFF00[Debug]|r 删除前分组数量: " .. #KeywordMonitorDB.KeywordGroups)
			Groups.RemoveKeywordGroup(currentIndex)
			print("|cffFFFF00[Debug]|r 删除后分组数量: " .. #KeywordMonitorDB.KeywordGroups)
			print("|cffFFFF00[Debug]|r 准备调用 RefreshGroupsList")
			Groups.RefreshGroupsList()
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
			Groups.UpdateKeywordGroup(currentIndex, nil, self:GetText())
			if KM.Core and KM.Core.UpdateKeywordList then
				KM.Core.UpdateKeywordList()
			end
			self:ClearFocus()
		end)
		
		kwBox:SetScript("OnEditFocusLost", function(self)
			Groups.UpdateKeywordGroup(currentIndex, nil, self:GetText())
			if KM.Core and KM.Core.UpdateKeywordList then
				KM.Core.UpdateKeywordList()
			end
		end)
		
		groupFrame.kwBox = kwBox
		
		tinsert(scrollChild.groups, groupFrame)
		yOffset = yOffset - 90
	end
	
	scrollChild:SetHeight(math.max(1, -yOffset))
end

-- 显示关键词分组管理界面
function Groups.ShowKeywordGroupsUI()
	EnsureConfig()
	
	if not KM.groupsFrame then
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
			if KM.Core and KM.Core.UpdateKeywordList then
				if isEnabled then
					-- 切换到分组模式
					KM.Core.UpdateKeywordList()
				else
					-- 切换到传统模式，使用保存的传统关键词
					KM.Core.UpdateKeywordList(KeywordMonitorDB.Keywords)
				end
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
			Groups.AddKeywordGroup("新分组", "")
			Groups.RefreshGroupsList()
		end)
		
		-- 预设方案按钮
		local presetBtn = CreateButton(frame, 100, 25, "预设方案")
		presetBtn:SetPoint("LEFT", addBtn, "RIGHT", 10, 0)
		presetBtn:SetScript("OnClick", function()
			if KM.Presets and KM.Presets.ShowPresetsUI then
				KM.Presets.ShowPresetsUI()
			elseif KM.ShowPresetsUI then
				KM:ShowPresetsUI()
			end
		end)
		
		-- 导出配置按钮
		local exportBtn = CreateButton(frame, 100, 25, "导出配置")
		exportBtn:SetPoint("LEFT", presetBtn, "RIGHT", 10, 0)
		exportBtn:SetScript("OnClick", function()
			if KM.ImportExport and KM.ImportExport.ShowExportUI then
				KM.ImportExport.ShowExportUI()
			elseif KM.ShowExportUI then
				KM:ShowExportUI()
			end
		end)
		
		-- 导入配置按钮
		local importBtn = CreateButton(frame, 100, 25, "导入配置")
		importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 10, 0)
		importBtn:SetScript("OnClick", function()
			if KM.ImportExport and KM.ImportExport.ShowImportUI then
				KM.ImportExport.ShowImportUI()
			elseif KM.ShowImportUI then
				KM:ShowImportUI()
			end
		end)
		
		frame:SetScript("OnShow", function()
			Groups.RefreshGroupsList()
		end)
		
		KM.groupsFrame = frame
	end
	
	if KM.groupsFrame:IsShown() then
		KM.groupsFrame:Hide()
	else
		KM.groupsFrame:Show()
	end
end

--[[============================================
    向后兼容性接口
============================================]]--

-- 为 KM 命名空间添加向后兼容的方法
function KM:AddKeywordGroup(name, keywords, color)
	return Groups.AddKeywordGroup(name, keywords, color)
end

function KM:RemoveKeywordGroup(index)
	return Groups.RemoveKeywordGroup(index)
end

function KM:UpdateKeywordGroup(index, name, keywords, enabled, color)
	return Groups.UpdateKeywordGroup(index, name, keywords, enabled, color)
end

function KM:GetEnabledKeywordGroups()
	return Groups.GetEnabledKeywordGroups()
end

function KM:ShowKeywordGroupsUI()
	return Groups.ShowKeywordGroupsUI()
end

function KM:RefreshGroupsList()
	return Groups.RefreshGroupsList()
end

function KM:SetTimeTrigger(groupIndex, startHour, endHour)
	return Groups.SetTimeTrigger(groupIndex, startHour, endHour)
end

function KM:RemoveTimeTrigger(groupIndex)
	return Groups.RemoveTimeTrigger(groupIndex)
end

function KM:CheckTimeTriggers()
	return Groups.CheckTimeTriggers()
end

--[[============================================
    模块初始化
============================================]]--

-- 初始化依赖
InitDependencies()

-- 模块加载完成标记
KM.Groups.Loaded = true

-- 调试信息
if KM.Debug then
    print("|cff00ff00KeywordMonitor:|r Groups 模块已加载")
end

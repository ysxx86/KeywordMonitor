--[[
    KeywordMonitor - Presets Module
    预设方案管理模块
    
    职责：
    - 提供预设方案的应用、保存、删除功能
    - 管理内置预设方案和用户自定义预设
    - 提供预设方案界面显示和管理
    - 支持预设方案的导入导出
    
    依赖：Utils 模块、Config 模块
    
    公共接口：
    - ShowPresetsUI() - 显示预设方案界面
    - ApplyPreset(presetName) - 应用预设方案
    - SaveAsPreset(presetName) - 保存当前配置为预设
    - DeletePreset(index) - 删除预设方案
--]]

local addonName, addon = ...

-- 确保全局命名空间存在
if not _G.KeywordMonitor then
	_G.KeywordMonitor = {}
end

-- 获取全局命名空间
local KM = _G.KeywordMonitor

-- 创建 Presets 模块命名空间
KM.Presets = {}
local Presets = KM.Presets

--[[============================================
    本地化全局函数（性能优化）
============================================]]--

local tinsert = table.insert
local tremove = table.remove
local pairs = pairs
local ipairs = ipairs
local type = type
local math = math
local CreateFrame = CreateFrame
local UIParent = UIParent
local C_Timer = C_Timer

--[[============================================
    辅助函数
============================================]]--

-- 从 Config 模块获取配置
local function EnsureConfig()
    if KM.Config and KM.Config.EnsureConfig then
        KM.Config.EnsureConfig()
    end
end

-- 从 Utils 模块获取工具函数
local CreateFS, CreateButton, CreateCheckBox, CreateEditBox, CreateCloseButton, CleanupUIElements

local function LoadUtilFunctions()
    if KM.Utils then
        CreateFS = KM.Utils.CreateFS
        CreateButton = KM.Utils.CreateButton
        CreateCheckBox = KM.Utils.CreateCheckBox
        CreateEditBox = KM.Utils.CreateEditBox
        CreateCloseButton = KM.Utils.CreateCloseButton
        CleanupUIElements = KM.Utils.CleanupUIElements
    end
end

--[[============================================
    内置预设方案数据
============================================]]--

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

-- 导出内置预设方案供其他模块使用
Presets.builtinPresets = builtinPresets

--- 获取内置预设方案列表
-- @return table 内置预设方案数组
function Presets:GetBuiltinPresets()
    return builtinPresets
end

--- 根据名称获取内置预设方案
-- @param name string 预设方案名称
-- @return table|nil 预设方案数据，如果未找到则返回 nil
function Presets:GetBuiltinPresetByName(name)
    for _, preset in ipairs(builtinPresets) do
        if preset.name == name then
            return preset
        end
    end
    return nil
end

--[[============================================
    预设方案管理函数
============================================]]--

--- 显示预设方案界面
function KM:ShowPresetsUI()
	EnsureConfig()
	LoadUtilFunctions()
	
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

--- 应用预设方案
-- @param preset table 预设方案数据对象
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
	if KM.UpdateKeywordList then
		KM:UpdateKeywordList()
	end
	
	print("|cff00FF00[ChatKeyword]|r 已应用预设方案: " .. preset.name)
end

--- 保存当前配置为预设
-- @param name string 预设方案名称
-- @param description string 预设方案描述（可选）
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

--- 删除预设方案
-- @param index number 预设方案在数组中的索引
function KM:DeletePreset(index)
	EnsureConfig()
	
	if index and KeywordMonitorDB.Presets[index] then
		local name = KeywordMonitorDB.Presets[index].name
		tremove(KeywordMonitorDB.Presets, index)
		print("|cff00FF00[ChatKeyword]|r 已删除预设方案: " .. name)
	end
end

--[[============================================
    模块初始化
============================================]]--

-- 模块加载完成标记
KM.Presets.Loaded = true

-- 调试信息
if KM.Debug then
    print("|cff00ff00KeywordMonitor:|r Presets 模块已加载")
end

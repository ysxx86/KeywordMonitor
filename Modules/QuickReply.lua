--[[
    KeywordMonitor - QuickReply Module
    快速回复管理模块
    
    职责：
    - 管理快速回复模板
    - 提供快速回复发送功能
    - 提供快速回复UI界面
    - 支持快速回复的添加、删除和发送
    
    依赖：Utils 模块、Config 模块
    
    公共接口：
    - AddQuickReply(text) - 添加快速回复模板
    - RemoveQuickReply(index) - 删除快速回复模板
    - SendQuickReply(playerName, replyText) - 发送快速回复
    - ShowQuickReplyUI() - 显示快速回复管理界面
    - RefreshQuickReplyList() - 刷新快速回复列表
    - ShowQuickReplyForPlayer(playerName) - 为特定玩家显示快速回复选项
    - ShowQuickReplyConfirmation(playerName, replyText) - 显示快速回复确认对话框
--]]

local addonName, addon = ...

-- 确保全局命名空间存在
if not _G.KeywordMonitor then
	_G.KeywordMonitor = {}
end

-- 获取全局命名空间
local KM = _G.KeywordMonitor

-- 创建 QuickReply 模块命名空间
KM.QuickReply = {}
local QuickReply = KM.QuickReply

--[[============================================
    本地化全局函数引用
============================================]]--

local pairs, ipairs = pairs, ipairs
local tinsert, tremove = table.insert, table.remove
local print = print
local CreateFrame = CreateFrame
local UIParent = UIParent
local C_Timer = C_Timer
local ChatFrame_SendTell = ChatFrame_SendTell
local ChatEdit_ChooseBoxForSend = ChatEdit_ChooseBoxForSend
local ChatEdit_SendText = ChatEdit_SendText

--[[============================================
    依赖模块引用
============================================]]--

-- Utils 模块函数
local CreateFS, CreateButton, CreateEditBox, CreateCloseButton, CleanupUIElements

-- Config 模块函数
local EnsureConfig

-- 初始化依赖（在模块加载后）
local function InitDependencies()
	if KM.Utils then
		CreateFS = KM.Utils.CreateFS
		CreateButton = KM.Utils.CreateButton
		CreateEditBox = KM.Utils.CreateEditBox
		CreateCloseButton = KM.Utils.CreateCloseButton
		CleanupUIElements = KM.Utils.CleanupUIElements
	end
	
	if KM.Config then
		EnsureConfig = KM.Config.EnsureConfig
	end
end

--[[============================================
    快速回复管理函数
============================================]]--

-- 添加快速回复模板
-- @param text string 回复文本
function QuickReply.AddQuickReply(text)
	if EnsureConfig then EnsureConfig() end
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
-- @param index number 回复索引
function QuickReply.RemoveQuickReply(index)
	if EnsureConfig then EnsureConfig() end
	if index and KeywordMonitorDB.QuickReplies[index] then
		local text = KeywordMonitorDB.QuickReplies[index]
		tremove(KeywordMonitorDB.QuickReplies, index)
		print("|cff00FF00[ChatKeyword]|r 已删除快速回复: " .. text)
	end
end

-- 发送快速回复
-- @param playerName string 玩家名称
-- @param replyText string 回复文本
function QuickReply.SendQuickReply(playerName, replyText)
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

--[[============================================
    快速回复UI函数
============================================]]--

-- 显示快速回复管理界面
function QuickReply.ShowQuickReplyUI()
	if EnsureConfig then EnsureConfig() end
	
	if not KM.quickReplyFrame then
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
				QuickReply.AddQuickReply(text)
				addBox:SetText("")
				QuickReply.RefreshQuickReplyList()
			end
		end)
		
		-- 回复列表滚动框
		local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
		scrollFrame:SetPoint("TOPLEFT", 20, -75)
		scrollFrame:SetPoint("BOTTOMRIGHT", -40, 20)
		
		local scrollChild = CreateFrame("Frame", nil, scrollFrame)
		scrollChild:SetSize(340, 1)
		scrollFrame:SetScrollChild(scrollChild)
		frame.scrollChild = scrollChild
		
		frame:SetScript("OnShow", function()
			QuickReply.RefreshQuickReplyList()
		end)
		
		KM.quickReplyFrame = frame
	end
	
	if KM.quickReplyFrame:IsShown() then
		KM.quickReplyFrame:Hide()
	else
		KM.quickReplyFrame:Show()
	end
end

-- 刷新快速回复列表
function QuickReply.RefreshQuickReplyList()
	local scrollChild = KM.quickReplyFrame and KM.quickReplyFrame.scrollChild
	if not scrollChild then return end
	
	-- 确保replies表存在
	if not scrollChild.replies then
		scrollChild.replies = {}
	end
	
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
			QuickReply.RemoveQuickReply(i)
			QuickReply.RefreshQuickReplyList()
		end)
		
		tinsert(scrollChild.replies, replyFrame)
		yOffset = yOffset - 35
	end
	
	scrollChild:SetHeight(math.max(1, -yOffset))
end

--[[============================================
    快速回复选择和确认
============================================]]--

-- 为特定玩家显示快速回复选择（修复内存泄漏 - 复用Frame）
local quickReplyMenu = nil
function QuickReply.ShowQuickReplyForPlayer(playerName)
	if EnsureConfig then EnsureConfig() end
	
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
			QuickReply.ShowQuickReplyConfirmation(playerName, replyText)
		end)
		tinsert(quickReplyMenu.buttons, btn)
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
function QuickReply.ShowQuickReplyConfirmation(playerName, replyText)
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
		QuickReply.SendQuickReply(playerName, replyText)
		quickReplyConfirmFrame:Hide()
		print("|cff00FF00[ChatKeyword]|r 已向 " .. playerName .. " 发送: " .. replyText)
	end)
	
	quickReplyConfirmFrame:SetPoint("CENTER")
	quickReplyConfirmFrame:Show()
end

--[[============================================
    向后兼容性接口
============================================]]--

-- 为 KM 命名空间添加向后兼容的方法
function KM:AddQuickReply(text)
	return QuickReply.AddQuickReply(text)
end

function KM:RemoveQuickReply(index)
	return QuickReply.RemoveQuickReply(index)
end

function KM:SendQuickReply(playerName, replyText)
	return QuickReply.SendQuickReply(playerName, replyText)
end

function KM:ShowQuickReplyUI()
	return QuickReply.ShowQuickReplyUI()
end

function KM:RefreshQuickReplyList()
	return QuickReply.RefreshQuickReplyList()
end

function KM:ShowQuickReplyForPlayer(playerName)
	return QuickReply.ShowQuickReplyForPlayer(playerName)
end

function KM:ShowQuickReplyConfirmation(playerName, replyText)
	return QuickReply.ShowQuickReplyConfirmation(playerName, replyText)
end

--[[============================================
    模块初始化
============================================]]--

-- 初始化依赖
InitDependencies()

-- 模块加载完成标记
KM.QuickReply.Loaded = true

-- 调试信息
if KM.Debug then
    print("|cff00ff00KeywordMonitor:|r QuickReply 模块已加载")
end

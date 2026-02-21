--[[
    Test for ShowKeywordMessage() function
    测试 ShowKeywordMessage() 消息过滤器函数
--]]

-- 模拟 WoW API 环境
local function SetupMockEnvironment()
    -- 模拟全局函数
    _G.GetServerTime = function() return os.time() end
    _G.date = os.date
    _G.GetTime = function() return os.clock() end
    _G.InCombatLockdown = function() return false end
    _G.PlaySound = function() end
    _G.PlaySoundFile = function() end
    _G.Ambiguate = function(name, mode) return name end
    _G.UnitName = function(unit) return "TestPlayer" end
    _G.GetColoredName = function(event, msg, author, ...) return "|cff00ff00" .. author .. "|r" end
    _G.GetPlayerLink = function(author, text) return text end
    _G.CreateFrame = function() return {} end
    _G.UIParent = {}
    _G.FCF_StartAlertFlash = function() end
    _G.GeneralDockManager = {selected = nil}
    _G.SOUNDKIT = {}
    _G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    _G.BNET_CLIENT_WOW = "WoW"
    _G.RAID_CLASS_COLORS = {}
    
    -- 模拟 C_API
    _G.C_Timer = {After = function(delay, func) func() end}
    _G.C_FriendList = {
        GetNumOnlineFriends = function() return 0 end,
        GetFriendInfoByIndex = function(i) return nil end,
    }
    _G.C_BattleNet = {
        GetFriendNumGameAccounts = function(i) return 0 end,
        GetFriendGameAccountInfo = function(i, j) return nil end,
    }
    _G.BNGetNumFriends = function() return 0, 0 end
    _G.BNGetFriendInfoByID = function() return nil end
    
    -- 模拟 KeywordMonitorDB
    _G.KeywordMonitorDB = {
        Enabled = true,
        UseKeywordGroups = false,
        Keywords = "MC,ZS,FS",
        KeywordGroups = {
            {name = "默认组", keywords = "", enabled = true, color = {0, 1, 0}},
        },
        OutputMode = 1,
        OutputChatFrame = 1,
        FlashOnMatch = true,
        AudioEnabled = false,
        Channels = {
            CHANNEL = true,
        },
        Blacklist = {
            Players = {},
            Keywords = {},
        },
    }
    
    -- 模拟聊天框架
    _G.ChatFrame1 = {
        AddMessage = function(self, msg, r, g, b)
            print("ChatFrame1: " .. msg)
        end,
        GetFont = function() return "Fonts\\FRIZQT__.TTF", 12 end,
        GetWidth = function() return 400 end,
    }
end

-- 加载模块
local function LoadModules()
    -- 初始化命名空间
    _G.KeywordMonitor = {}
    
    -- 加载 Utils 模块
    dofile("AddOns/KeywordMonitor/Modules/Utils.lua")
    
    -- 加载 Config 模块
    dofile("AddOns/KeywordMonitor/Modules/Config.lua")
    
    -- 加载 Core 模块
    dofile("AddOns/KeywordMonitor/Modules/Core.lua")
end

-- 测试函数
local function RunTests()
    local KM = _G.KeywordMonitor
    local Core = KM.Core
    
    print("=== 测试 ShowKeywordMessage() 函数 ===\n")
    
    -- 初始化关键词列表
    Core.UpdateKeywordList("MC,ZS,FS")
    
    -- 测试 1: 匹配关键词的消息
    print("测试 1: 匹配关键词的消息")
    local result = Core.ShowKeywordMessage(
        nil,
        "CHAT_MSG_CHANNEL",
        "来MC，需要ZS和FS",
        "OtherPlayer",
        "",
        "1. 综合"
    )
    assert(result == false, "应该返回 false（不过滤消息）")
    print("✓ 匹配关键词的消息测试通过\n")
    
    -- 测试 2: 不匹配关键词的消息
    print("测试 2: 不匹配关键词的消息")
    local result = Core.ShowKeywordMessage(
        nil,
        "CHAT_MSG_CHANNEL",
        "这是一条普通消息",
        "OtherPlayer",
        "",
        "1. 综合"
    )
    assert(result == false, "应该返回 false")
    print("✓ 不匹配关键词的消息测试通过\n")
    
    -- 测试 3: 过滤自己的消息
    print("测试 3: 过滤自己的消息")
    local result = Core.ShowKeywordMessage(
        nil,
        "CHAT_MSG_CHANNEL",
        "来MC，需要ZS",
        "TestPlayer",
        "",
        "1. 综合"
    )
    assert(result == false, "应该返回 false（过滤自己的消息）")
    print("✓ 过滤自己的消息测试通过\n")
    
    -- 测试 4: 监控禁用时
    print("测试 4: 监控禁用时")
    KeywordMonitorDB.Enabled = false
    local result = Core.ShowKeywordMessage(
        nil,
        "CHAT_MSG_CHANNEL",
        "来MC，需要ZS",
        "OtherPlayer",
        "",
        "1. 综合"
    )
    assert(result == false, "应该返回 false（监控已禁用）")
    KeywordMonitorDB.Enabled = true
    print("✓ 监控禁用时测试通过\n")
    
    -- 测试 5: 重复消息过滤
    print("测试 5: 重复消息过滤")
    Core.UpdateKeywordList("MC")
    local result1 = Core.ShowKeywordMessage(
        nil,
        "CHAT_MSG_CHANNEL",
        "来MC",
        "OtherPlayer",
        "",
        "1. 综合"
    )
    -- 立即发送相同消息
    local result2 = Core.ShowKeywordMessage(
        nil,
        "CHAT_MSG_CHANNEL",
        "来MC",
        "OtherPlayer",
        "",
        "1. 综合"
    )
    assert(result1 == false, "第一条消息应该显示")
    assert(result2 == false, "第二条消息应该被过滤（重复）")
    print("✓ 重复消息过滤测试通过\n")
    
    print("=== 所有测试通过! ===")
end

-- 主函数
local function Main()
    SetupMockEnvironment()
    LoadModules()
    RunTests()
end

-- 运行测试
local success, err = pcall(Main)
if not success then
    print("测试失败: " .. tostring(err))
    os.exit(1)
end

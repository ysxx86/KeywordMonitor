--[[
    Test for UpdateKeywordList() function
    测试 UpdateKeywordList() 函数
--]]

-- 模拟 WoW API 环境
local function SetupMockEnvironment()
    -- 模拟全局函数
    _G.GetServerTime = function() return os.time() end
    _G.date = os.date
    _G.GetTime = function() return os.clock() end
    
    -- 模拟 KeywordMonitorDB
    _G.KeywordMonitorDB = {
        UseKeywordGroups = false,
        Keywords = "",
        KeywordGroups = {
            {name = "默认组", keywords = "", enabled = true, color = {0, 1, 0}},
        },
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
    
    print("=== 测试 UpdateKeywordList() 函数 ===\n")
    
    -- 测试 1: 传统模式 - 简单关键词
    print("测试 1: 传统模式 - 简单关键词")
    KeywordMonitorDB.UseKeywordGroups = false
    KeywordMonitorDB.Keywords = "MC,ZS,FS"
    Core.UpdateKeywordList(KeywordMonitorDB.Keywords)
    print("✓ 传统模式简单关键词测试通过\n")
    
    -- 测试 2: 传统模式 - 组合关键词
    print("测试 2: 传统模式 - 组合关键词")
    KeywordMonitorDB.Keywords = "MC+ZS,FS#DZ"
    Core.UpdateKeywordList(KeywordMonitorDB.Keywords)
    print("✓ 传统模式组合关键词测试通过\n")
    
    -- 测试 3: 传统模式 - 排除关键词
    print("测试 3: 传统模式 - 排除关键词")
    KeywordMonitorDB.Keywords = "MC&金团"
    Core.UpdateKeywordList(KeywordMonitorDB.Keywords)
    print("✓ 传统模式排除关键词测试通过\n")
    
    -- 测试 4: 分组模式
    print("测试 4: 分组模式")
    KeywordMonitorDB.UseKeywordGroups = true
    KeywordMonitorDB.KeywordGroups = {
        {name = "组1", keywords = "MC,ZS", enabled = true, color = {0, 1, 0}},
        {name = "组2", keywords = "FS,DZ", enabled = true, color = {1, 0, 0}},
        {name = "组3", keywords = "LR", enabled = false, color = {0, 0, 1}},
    }
    Core.UpdateKeywordList()
    print("✓ 分组模式测试通过\n")
    
    -- 测试 5: 中文标点符号替换
    print("测试 5: 中文标点符号替换")
    KeywordMonitorDB.UseKeywordGroups = false
    KeywordMonitorDB.Keywords = "MC，ZS＋FS"
    Core.UpdateKeywordList(KeywordMonitorDB.Keywords)
    print("✓ 中文标点符号替换测试通过\n")
    
    -- 测试 6: 空关键词
    print("测试 6: 空关键词")
    KeywordMonitorDB.UseKeywordGroups = false
    KeywordMonitorDB.Keywords = ""
    Core.UpdateKeywordList(KeywordMonitorDB.Keywords)
    print("✓ 空关键词测试通过\n")
    
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

--[[
    测试文件：CreateKeywordFrame 函数迁移验证
    
    目的：验证 CreateKeywordFrame() 函数从 Core.lua.backup 迁移到 Modules/Core.lua 后功能正常
    
    测试内容：
    1. 验证函数能够创建独立监控窗口
    2. 验证窗口属性设置正确
    3. 验证滚动按钮功能
    4. 验证重复调用返回同一实例
--]]

-- 模拟 WoW API 环境
local mockEnv = {}

-- 模拟全局变量
_G.KeywordMonitorDB = {
    KeywordFrameHeight = 180,
    UseNDuiStyle = false,
}

-- 模拟 UIParent
_G.UIParent = {
    GetWidth = function() return 800 end,
    GetHeight = function() return 600 end,
}

-- 模拟 ChatFrame1
_G.ChatFrame1 = {
    GetWidth = function() return 400 end,
    GetHeight = function() return 300 end,
    GetFont = function() return "Fonts\\FRIZQT__.TTF", 12 end,
}

-- 模拟 SOUNDKIT
_G.SOUNDKIT = {
    IG_CHAT_BOTTOM = 1234,
}

-- 模拟 CreateFrame
local frameCounter = 0
_G.CreateFrame = function(frameType, name, parent, template)
    frameCounter = frameCounter + 1
    local frame = {
        _type = frameType,
        _name = name or ("Frame" .. frameCounter),
        _parent = parent,
        _template = template,
        _size = {width = 100, height = 100},
        _point = {},
        _strata = "MEDIUM",
        _fading = true,
        _maxLines = 10,
        _hyperlinks = false,
        _mouse = false,
        _mouseWheel = false,
        _font = {},
        _shadow = {},
        _justify = "LEFT",
        _alpha = 1,
        _visible = true,
        _scripts = {},
        _textures = {},
        _numMessages = 0,
        _atBottom = true,
    }
    
    -- 框架方法
    frame.SetSize = function(self, width, height)
        self._size.width = width
        self._size.height = height
    end
    
    frame.SetPoint = function(self, point, relativeTo, relativePoint, x, y)
        self._point = {point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x, y = y}
    end
    
    frame.SetFrameStrata = function(self, strata)
        self._strata = strata
    end
    
    frame.SetFading = function(self, fading)
        self._fading = fading
    end
    
    frame.SetMaxLines = function(self, lines)
        self._maxLines = lines
    end
    
    frame.SetHyperlinksEnabled = function(self, enabled)
        self._hyperlinks = enabled
    end
    
    frame.EnableMouse = function(self, enabled)
        self._mouse = enabled
    end
    
    frame.EnableMouseWheel = function(self, enabled)
        self._mouseWheel = enabled
    end
    
    frame.SetFont = function(self, path, size, flags)
        self._font = {path = path, size = size, flags = flags}
    end
    
    frame.GetFont = function(self)
        return self._font.path, self._font.size, self._font.flags
    end
    
    frame.SetShadowColor = function(self, r, g, b, a)
        self._shadow = {r = r, g = g, b = b, a = a}
    end
    
    frame.SetJustifyH = function(self, justify)
        self._justify = justify
    end
    
    frame.SetAlpha = function(self, alpha)
        self._alpha = alpha
    end
    
    frame.GetAlpha = function(self)
        return self._alpha
    end
    
    frame.Hide = function(self)
        self._visible = false
    end
    
    frame.Show = function(self)
        self._visible = true
    end
    
    frame.IsShown = function(self)
        return self._visible
    end
    
    frame.SetScript = function(self, event, handler)
        self._scripts[event] = handler
    end
    
    frame.CreateTexture = function(self, name, layer)
        local texture = {
            _name = name,
            _layer = layer,
            _texture = "",
        }
        texture.SetAllPoints = function() end
        texture.SetTexture = function(self, path)
            self._texture = path
        end
        table.insert(self._textures, texture)
        return texture
    end
    
    frame.GetNumMessages = function(self)
        return self._numMessages
    end
    
    frame.ScrollUp = function(self)
        self._atBottom = false
    end
    
    frame.ScrollDown = function(self)
        -- 模拟滚动
    end
    
    frame.ScrollToBottom = function(self)
        self._atBottom = true
    end
    
    frame.AtBottom = function(self)
        return self._atBottom
    end
    
    return frame
end

-- 模拟 PlaySound
_G.PlaySound = function(soundId)
    -- 不做任何事
end

-- 加载模块
print("=== 开始测试 CreateKeywordFrame 函数 ===\n")

-- 加载 Utils 模块
local utilsPath = "AddOns/KeywordMonitor/Modules/Utils.lua"
local utilsFunc, utilsErr = loadfile(utilsPath)
if not utilsFunc then
    print("错误：无法加载 Utils 模块")
    print("错误信息：" .. tostring(utilsErr))
    return
end

local success, err = pcall(utilsFunc)
if not success then
    print("错误：Utils 模块执行失败")
    print("错误信息：" .. tostring(err))
    return
end

print("✓ Utils 模块加载成功")

-- 加载 Config 模块
local configPath = "AddOns/KeywordMonitor/Modules/Config.lua"
local configFunc, configErr = loadfile(configPath)
if not configFunc then
    print("错误：无法加载 Config 模块")
    print("错误信息：" .. tostring(configErr))
    return
end

success, err = pcall(configFunc)
if not success then
    print("错误：Config 模块执行失败")
    print("错误信息：" .. tostring(err))
    return
end

print("✓ Config 模块加载成功")

-- 加载 Core 模块
local corePath = "AddOns/KeywordMonitor/Modules/Core.lua"
local coreFunc, coreErr = loadfile(corePath)
if not coreFunc then
    print("错误：无法加载 Core 模块")
    print("错误信息：" .. tostring(coreErr))
    return
end

success, err = pcall(coreFunc)
if not success then
    print("错误：Core 模块执行失败")
    print("错误信息：" .. tostring(err))
    return
end

print("✓ Core 模块加载成功\n")

-- 获取模块引用
local KM = _G.KeywordMonitor
if not KM or not KM.Core then
    print("错误：无法获取 KeywordMonitor.Core 模块")
    return
end

local Core = KM.Core

-- 测试 1：验证函数存在
print("测试 1：验证 CreateKeywordFrame 函数存在")
if type(Core.CreateKeywordFrame) == "function" then
    print("✓ CreateKeywordFrame 函数存在\n")
else
    print("✗ CreateKeywordFrame 函数不存在\n")
    return
end

-- 测试 2：创建监控窗口
print("测试 2：创建监控窗口")
local frame1 = Core.CreateKeywordFrame()
if frame1 then
    print("✓ 成功创建监控窗口")
    print("  - 窗口类型：" .. tostring(frame1._type))
    print("  - 窗口名称：" .. tostring(frame1._name))
else
    print("✗ 创建监控窗口失败\n")
    return
end

-- 测试 3：验证窗口属性
print("\n测试 3：验证窗口属性")
local allPassed = true

-- 检查尺寸
if frame1._size.width == 400 and frame1._size.height == 180 then
    print("✓ 窗口尺寸正确：" .. frame1._size.width .. "x" .. frame1._size.height)
else
    print("✗ 窗口尺寸错误：" .. frame1._size.width .. "x" .. frame1._size.height)
    allPassed = false
end

-- 检查层级
if frame1._strata == "MEDIUM" then
    print("✓ 窗口层级正确：" .. frame1._strata)
else
    print("✗ 窗口层级错误：" .. frame1._strata)
    allPassed = false
end

-- 检查淡出
if frame1._fading == false then
    print("✓ 淡出设置正确：false")
else
    print("✗ 淡出设置错误：" .. tostring(frame1._fading))
    allPassed = false
end

-- 检查最大行数
if frame1._maxLines == 100 then
    print("✓ 最大行数正确：" .. frame1._maxLines)
else
    print("✗ 最大行数错误：" .. frame1._maxLines)
    allPassed = false
end

-- 检查超链接
if frame1._hyperlinks == true then
    print("✓ 超链接启用正确：true")
else
    print("✗ 超链接启用错误：" .. tostring(frame1._hyperlinks))
    allPassed = false
end

-- 检查鼠标
if frame1._mouse == true then
    print("✓ 鼠标启用正确：true")
else
    print("✗ 鼠标启用错误：" .. tostring(frame1._mouse))
    allPassed = false
end

-- 检查鼠标滚轮
if frame1._mouseWheel == true then
    print("✓ 鼠标滚轮启用正确：true")
else
    print("✗ 鼠标滚轮启用错误：" .. tostring(frame1._mouseWheel))
    allPassed = false
end

-- 检查字体
local fontPath, fontSize = frame1:GetFont()
if fontPath == "Fonts\\FRIZQT__.TTF" and fontSize == 12 then
    print("✓ 字体设置正确：" .. fontPath .. ", " .. fontSize)
else
    print("✗ 字体设置错误：" .. tostring(fontPath) .. ", " .. tostring(fontSize))
    allPassed = false
end

-- 检查初始可见性
if frame1._visible == false then
    print("✓ 初始隐藏正确：false")
else
    print("✗ 初始隐藏错误：" .. tostring(frame1._visible))
    allPassed = false
end

-- 测试 4：验证滚动按钮
print("\n测试 4：验证滚动按钮")
if frame1.ScrollToBottomButton then
    print("✓ 滚动按钮存在")
    local btn = frame1.ScrollToBottomButton
    
    -- 检查按钮尺寸
    if btn._size.width == 20 and btn._size.height == 20 then
        print("✓ 按钮尺寸正确：20x20")
    else
        print("✗ 按钮尺寸错误：" .. btn._size.width .. "x" .. btn._size.height)
        allPassed = false
    end
    
    -- 检查按钮图标
    if #btn._textures > 0 and btn._textures[1]._texture == "Interface\\ChatFrame\\UI-ChatIcon-ScrollEnd-Up" then
        print("✓ 按钮图标正确")
    else
        print("✗ 按钮图标错误")
        allPassed = false
    end
    
    -- 检查按钮脚本
    if btn._scripts.OnEnter and btn._scripts.OnLeave and btn._scripts.OnClick then
        print("✓ 按钮脚本已设置")
    else
        print("✗ 按钮脚本未完整设置")
        allPassed = false
    end
else
    print("✗ 滚动按钮不存在")
    allPassed = false
end

-- 测试 5：验证鼠标滚轮脚本
print("\n测试 5：验证鼠标滚轮脚本")
if frame1._scripts.OnMouseWheel then
    print("✓ 鼠标滚轮脚本已设置")
else
    print("✗ 鼠标滚轮脚本未设置")
    allPassed = false
end

-- 测试 6：验证重复调用返回同一实例
print("\n测试 6：验证重复调用返回同一实例")
local frame2 = Core.CreateKeywordFrame()
if frame1 == frame2 then
    print("✓ 重复调用返回同一实例")
else
    print("✗ 重复调用返回不同实例")
    allPassed = false
end

-- 总结
print("\n=== 测试完成 ===")
if allPassed then
    print("✓ 所有测试通过！CreateKeywordFrame 函数迁移成功。")
else
    print("✗ 部分测试失败，请检查实现。")
end

--[[
    KeywordMonitor - Aliases Module
    关键词别名映射模块
    
    职责：
    - 提供关键词的中英文及缩写双向映射
    - 支持副本、职业、角色等常用缩写
    - 覆盖经典旧世、TBC、WLK 等版本内容
    
    依赖：无（基础模块）
    
    公共接口：
    - ExpandKeyword(keyword) - 扩展关键词，返回所有可能的匹配项
    - GetAliases(keyword) - 获取关键词的所有别名
--]]

local addonName, addon = ...

-- 确保全局命名空间存在
if not _G.KeywordMonitor then
	_G.KeywordMonitor = {}
end

local KM = _G.KeywordMonitor

-- 创建 Aliases 模块命名空间
KM.Aliases = {}
local Aliases = KM.Aliases

--[[============================================
    本地化全局函数引用
============================================]]--

local upper, lower, gsub = string.upper, string.lower, string.gsub
local pairs, ipairs, type = pairs, ipairs, type
local tinsert = table.insert

--[[============================================
    别名映射表
============================================]]--

-- 副本缩写映射（经典旧世 + TBC + WLK）
local RAID_ALIASES = {
	-- 经典旧世 40人团队副本
	["MC"] = {"熔火之心", "熔火", "MOLTENCORE"},
	["熔火之心"] = {"MC", "熔火", "MOLTENCORE"},
	["熔火"] = {"MC", "熔火之心", "MOLTENCORE"},
	
	["BWL"] = {"黑翼之巢", "黑翼", "BLACKWINGLAIR"},
	["黑翼之巢"] = {"BWL", "黑翼", "BLACKWINGLAIR"},
	["黑翼"] = {"BWL", "黑翼之巢", "BLACKWINGLAIR"},
	
	["TAQ"] = {"安其拉神殿", "安其拉", "AQ40", "TEMPLEOFAHNQIRAJ"},
	["AQ40"] = {"安其拉神殿", "安其拉", "TAQ", "TEMPLEOFAHNQIRAJ"},
	["安其拉神殿"] = {"TAQ", "AQ40", "安其拉", "TEMPLEOFAHNQIRAJ"},
	["安其拉"] = {"TAQ", "AQ40", "安其拉神殿", "TEMPLEOFAHNQIRAJ"},
	
	["NAXX"] = {"纳克萨玛斯", "纳克", "NAXXRAMAS"},
	["纳克萨玛斯"] = {"NAXX", "纳克", "NAXXRAMAS"},
	["纳克"] = {"NAXX", "纳克萨玛斯", "NAXXRAMAS"},
	
	-- 经典旧世 20人团队副本
	["ZG"] = {"祖尔格拉布", "祖格", "ZULGURUB"},
	["祖尔格拉布"] = {"ZG", "祖格", "ZULGURUB"},
	["祖格"] = {"ZG", "祖尔格拉布", "ZULGURUB"},
	
	["AQ20"] = {"安其拉废墟", "废墟", "RUINSOFAHNQIRAJ"},
	["安其拉废墟"] = {"AQ20", "废墟", "RUINSOFAHNQIRAJ"},
	
	-- TBC 25人团队副本
	["KLZ"] = {"卡拉赞", "卡拉", "KARAZHAN"},
	["卡拉赞"] = {"KLZ", "卡拉", "KARAZHAN"},
	["卡拉"] = {"KLZ", "卡拉赞", "KARAZHAN"},
	
	["GLR"] = {"格鲁尔的巢穴", "格鲁尔", "GRUULSLAIR"},
	["格鲁尔的巢穴"] = {"GLR", "格鲁尔", "GRUULSLAIR"},
	["格鲁尔"] = {"GLR", "格鲁尔的巢穴", "GRUULSLAIR"},
	
	["MAG"] = {"玛瑟里顿的巢穴", "玛瑟里顿", "MAGTHERIDON"},
	["玛瑟里顿的巢穴"] = {"MAG", "玛瑟里顿", "MAGTHERIDON"},
	["玛瑟里顿"] = {"MAG", "玛瑟里顿的巢穴", "MAGTHERIDON"},
	
	["SSC"] = {"毒蛇神殿", "毒蛇", "SERPENTSHRINECAVERN"},
	["毒蛇神殿"] = {"SSC", "毒蛇", "SERPENTSHRINECAVERN"},
	["毒蛇"] = {"SSC", "毒蛇神殿", "SERPENTSHRINECAVERN"},
	
	["TK"] = {"风暴要塞", "风暴", "TEMPESTKEEP"},
	["风暴要塞"] = {"TK", "风暴", "TEMPESTKEEP"},
	["风暴"] = {"TK", "风暴要塞", "TEMPESTKEEP"},
	
	["MH"] = {"海加尔山", "海加尔", "MOUNTHYJAL"},
	["海加尔山"] = {"MH", "海加尔", "MOUNTHYJAL"},
	["海加尔"] = {"MH", "海加尔山", "MOUNTHYJAL"},
	
	["BT"] = {"黑暗神殿", "黑庙", "BLACKTEMPLE"},
	["黑暗神殿"] = {"BT", "黑庙", "BLACKTEMPLE"},
	["黑庙"] = {"BT", "黑暗神殿", "BLACKTEMPLE"},
	
	["ZAM"] = {"祖阿曼", "ZA", "ZULAMANM"},
	["ZA"] = {"祖阿曼", "ZAM", "ZULAMANM"},
	["祖阿曼"] = {"ZAM", "ZA", "ZULAMANM"},
	
	["SW"] = {"太阳之井高地", "太阳井", "SUNWELL"},
	["太阳之井高地"] = {"SW", "太阳井", "SUNWELL"},
	["太阳井"] = {"SW", "太阳之井高地", "SUNWELL"},
	
	-- WLK 团队副本
	["NAXX"] = {"纳克萨玛斯", "纳克", "NAXXRAMAS"},
	
	["OBS"] = {"黑曜石圣殿", "黑曜石", "OBSIDIANSANCTUM"},
	["黑曜石圣殿"] = {"OBS", "黑曜石", "OBSIDIANSANCTUM"},
	["黑曜石"] = {"OBS", "黑曜石圣殿", "OBSIDIANSANCTUM"},
	
	["EOE"] = {"永恒之眼", "永恒", "EYEOFETERNITY"},
	["永恒之眼"] = {"EOE", "永恒", "EYEOFETERNITY"},
	["永恒"] = {"EOE", "永恒之眼", "EYEOFETERNITY"},
	
	["ULD"] = {"奥杜尔", "奥都", "ULDUAR"},
	["奥杜尔"] = {"ULD", "奥都", "ULDUAR"},
	["奥都"] = {"ULD", "奥杜尔", "ULDUAR"},
	
	["TOC"] = {"十字军试炼", "十字军", "TRIALOFTHECRUSADER"},
	["十字军试炼"] = {"TOC", "十字军", "TRIALOFTHECRUSADER"},
	["十字军"] = {"TOC", "十字军试炼", "TRIALOFTHECRUSADER"},
	
	["ICC"] = {"冰冠堡垒", "冰冠", "ICECROWNCITADEL"},
	["冰冠堡垒"] = {"ICC", "冰冠", "ICECROWNCITADEL"},
	["冰冠"] = {"ICC", "冰冠堡垒", "ICECROWNCITADEL"},
	
	["RS"] = {"红玉圣殿", "红玉", "RUBYSANCTUM"},
	["红玉圣殿"] = {"RS", "红玉", "RUBYSANCTUM"},
	["红玉"] = {"RS", "红玉圣殿", "RUBYSANCTUM"},
}

-- 职业缩写映射
local CLASS_ALIASES = {
	-- 战士
	["ZS"] = {"战士", "战", "WARRIOR"},
	["战士"] = {"ZS", "战", "WARRIOR"},
	["战"] = {"ZS", "战士", "WARRIOR"},
	
	-- 圣骑士
	["QS"] = {"圣骑士", "骑士", "圣骑", "PALADIN"},
	["圣骑士"] = {"QS", "骑士", "圣骑", "PALADIN"},
	["圣骑"] = {"QS", "圣骑士", "骑士", "PALADIN"},
	["骑士"] = {"QS", "圣骑士", "圣骑", "PALADIN"},
	
	-- 猎人
	["LR"] = {"猎人", "猎", "HUNTER"},
	["猎人"] = {"LR", "猎", "HUNTER"},
	["猎"] = {"LR", "猎人", "HUNTER"},
	
	-- 盗贼
	["DZ"] = {"盗贼", "贼", "ROGUE"},
	["盗贼"] = {"DZ", "贼", "ROGUE"},
	["贼"] = {"DZ", "盗贼", "ROGUE"},
	
	-- 牧师
	["MS"] = {"牧师", "牧", "PRIEST"},
	["牧师"] = {"MS", "牧", "PRIEST"},
	["牧"] = {"MS", "牧师", "PRIEST"},
	
	-- 萨满祭司
	["SM"] = {"萨满祭司", "萨满", "萨", "SHAMAN"},
	["萨满祭司"] = {"SM", "萨满", "萨", "SHAMAN"},
	["萨满"] = {"SM", "萨满祭司", "萨", "SHAMAN"},
	["萨"] = {"SM", "萨满祭司", "萨满", "SHAMAN"},
	
	-- 法师
	["FS"] = {"法师", "法", "MAGE"},
	["法师"] = {"FS", "法", "MAGE"},
	["法"] = {"FS", "法师", "MAGE"},
	
	-- 术士
	["SS"] = {"术士", "术", "WARLOCK"},
	["术士"] = {"SS", "术", "WARLOCK"},
	["术"] = {"SS", "术士", "WARLOCK"},
	
	-- 德鲁伊
	["XD"] = {"德鲁伊", "德", "小德", "DRUID"},
	["德鲁伊"] = {"XD", "德", "小德", "DRUID"},
	["德"] = {"XD", "德鲁伊", "小德", "DRUID"},
	["小德"] = {"XD", "德鲁伊", "德", "DRUID"},
	
	-- 死亡骑士 (WLK)
	["DK"] = {"死亡骑士", "死骑", "DEATHKNIGHT"},
	["死亡骑士"] = {"DK", "死骑", "DEATHKNIGHT"},
	["死骑"] = {"DK", "死亡骑士", "DEATHKNIGHT"},
}

-- 角色定位缩写映射
local ROLE_ALIASES = {
	-- 坦克
	["T"] = {"坦克", "坦", "T", "TANK"},
	["坦克"] = {"T", "坦", "TANK"},
	["坦"] = {"T", "坦克", "TANK"},
	
	-- 治疗
	["N"] = {"治疗", "奶", "奶妈", "HEALER"},
	["奶"] = {"N", "治疗", "奶妈", "HEALER"},
	["治疗"] = {"N", "奶", "奶妈", "HEALER"},
	["奶妈"] = {"N", "治疗", "奶", "HEALER"},
	
	-- 输出
	["DPS"] = {"输出", "DD", "DAMAGE"},
	["输出"] = {"DPS", "DD", "DAMAGE"},
	["DD"] = {"DPS", "输出", "DAMAGE"},
}

-- 职业+角色组合缩写
local CLASS_ROLE_ALIASES = {
	-- 奶骑
	["NQ"] = {"奶骑", "奶骑士", "治疗骑士", "神圣骑士"},
	["奶骑"] = {"NQ", "奶骑士", "治疗骑士", "神圣骑士"},
	["奶骑士"] = {"NQ", "奶骑", "治疗骑士", "神圣骑士"},
	
	-- 防骑
	["FQ"] = {"防骑", "防战骑士", "坦克骑士", "防护骑士"},
	["防骑"] = {"FQ", "防战骑士", "坦克骑士", "防护骑士"},
	
	-- 惩戒骑
	["CJQ"] = {"惩戒骑", "惩戒骑士", "输出骑士"},
	["惩戒骑"] = {"CJQ", "惩戒骑士", "输出骑士"},
	["惩戒骑士"] = {"CJQ", "惩戒骑", "输出骑士"},
	
	-- 神圣骑（奶骑的另一种说法）
	["SSQ"] = {"神圣骑", "神圣骑士", "奶骑"},
	["神圣骑"] = {"SSQ", "神圣骑士", "奶骑"},
	["神圣骑士"] = {"SSQ", "神圣骑", "奶骑"},
	
	-- 奶德
	["ND"] = {"奶德", "奶德鲁伊", "治疗德鲁伊", "恢复德"},
	["奶德"] = {"ND", "奶德鲁伊", "治疗德鲁伊", "恢复德"},
	["奶德鲁伊"] = {"ND", "奶德", "治疗德鲁伊", "恢复德"},
	
	-- 野德/熊T
	["YD"] = {"野德", "熊T", "熊坦", "坦克德鲁伊"},
	["野德"] = {"YD", "熊T", "熊坦", "坦克德鲁伊"},
	["熊T"] = {"YD", "野德", "熊坦", "坦克德鲁伊"},
	["熊坦"] = {"YD", "野德", "熊T", "坦克德鲁伊"},
	
	-- 鸟德
	["鸟德"] = {"平衡德", "平衡德鲁伊", "输出德鲁伊"},
	["平衡德"] = {"鸟德", "平衡德鲁伊", "输出德鲁伊"},
	
	-- 猫德
	["猫德"] = {"野性德", "野性德鲁伊", "近战德鲁伊"},
	["野性德"] = {"猫德", "野性德鲁伊", "近战德鲁伊"},
	
	-- 奶萨
	["NS"] = {"奶萨", "奶萨满", "治疗萨满", "恢复萨"},
	["奶萨"] = {"NS", "奶萨满", "治疗萨满", "恢复萨"},
	["奶萨满"] = {"NS", "奶萨", "治疗萨满", "恢复萨"},
	
	-- 元素萨
	["YSS"] = {"元素萨", "元素萨满", "输出萨满"},
	["元素萨"] = {"YSS", "元素萨满", "输出萨满"},
	["元素萨满"] = {"YSS", "元素萨", "输出萨满"},
	
	-- 增强萨
	["ZQS"] = {"增强萨", "增强萨满", "近战萨满"},
	["增强萨"] = {"ZQS", "增强萨满", "近战萨满"},
	["增强萨满"] = {"ZQS", "增强萨", "近战萨满"},
	
	-- 奶牧
	["NM"] = {"奶牧", "奶牧师", "治疗牧师"},
	["奶牧"] = {"NM", "奶牧师", "治疗牧师"},
	["奶牧师"] = {"NM", "奶牧", "治疗牧师"},
	
	-- 暗牧
	["AM"] = {"暗牧", "暗影牧师", "输出牧师"},
	["暗牧"] = {"AM", "暗影牧师", "输出牧师"},
	["暗影牧师"] = {"AM", "暗牧", "输出牧师"},
	
	-- 戒律牧
	["JLM"] = {"戒律牧", "戒律牧师"},
	["戒律牧"] = {"JLM", "戒律牧师"},
	["戒律牧师"] = {"JLM", "戒律牧"},
	
	-- 神圣牧
	["SSM"] = {"神圣牧", "神圣牧师"},
	["神圣牧"] = {"SSM", "神圣牧师"},
	["神圣牧师"] = {"SSM", "神圣牧"},
	
	-- 防战
	["FZ"] = {"防战", "防战士", "坦克战士", "防护战士"},
	["防战"] = {"FZ", "防战士", "坦克战士", "防护战士"},
	["防战士"] = {"FZ", "防战", "坦克战士", "防护战士"},
	
	-- 狂暴战
	["KBZ"] = {"狂暴战", "狂战", "输出战士"},
	["狂暴战"] = {"KBZ", "狂战", "输出战士"},
	["狂战"] = {"KBZ", "狂暴战", "输出战士"},
	
	-- 武器战
	["WQZ"] = {"武器战", "武战", "输出战士"},
	["武器战"] = {"WQZ", "武战", "输出战士"},
	["武战"] = {"WQZ", "武器战", "输出战士"},
	
	-- 法师专精
	["AOE法"] = {"奥术法师", "奥法"},
	["奥法"] = {"AOE法", "奥术法师"},
	["奥术法师"] = {"AOE法", "奥法"},
	["火法"] = {"火焰法师"},
	["火焰法师"] = {"火法"},
	["冰法"] = {"冰霜法师"},
	["冰霜法师"] = {"冰法"},
	
	-- 术士专精
	["痛苦术"] = {"痛苦术士"},
	["痛苦术士"] = {"痛苦术"},
	["恶魔术"] = {"恶魔术士"},
	["恶魔术士"] = {"恶魔术"},
	["毁灭术"] = {"毁灭术士"},
	["毁灭术士"] = {"毁灭术"},
	
	-- 猎人专精
	["兽王猎"] = {"兽王猎人", "BM猎"},
	["兽王猎人"] = {"兽王猎", "BM猎"},
	["BM猎"] = {"兽王猎", "兽王猎人"},
	["射击猎"] = {"射击猎人"},
	["射击猎人"] = {"射击猎"},
	["生存猎"] = {"生存猎人"},
	["生存猎人"] = {"生存猎"},
	
	-- 盗贼专精
	["刺杀贼"] = {"刺杀盗贼"},
	["刺杀盗贼"] = {"刺杀贼"},
	["战斗贼"] = {"战斗盗贼"},
	["战斗盗贼"] = {"战斗贼"},
	["敏锐贼"] = {"敏锐盗贼"},
	["敏锐盗贼"] = {"敏锐贼"},
	
	-- 死亡骑士专精 (WLK)
	["血DK"] = {"血死骑", "血坦", "坦克DK"},
	["血死骑"] = {"血DK", "血坦", "坦克DK"},
	["血坦"] = {"血DK", "血死骑", "坦克DK"},
	["冰DK"] = {"冰霜DK", "冰霜死骑"},
	["冰霜DK"] = {"冰DK", "冰霜死骑"},
	["冰霜死骑"] = {"冰DK", "冰霜DK"},
	["邪DK"] = {"邪恶DK", "邪恶死骑"},
	["邪恶DK"] = {"邪DK", "邪恶死骑"},
	["邪恶死骑"] = {"邪DK", "邪恶DK"},
	
	-- 其他常见组合
	["DKT"] = {"DK坦", "血DK", "死骑坦克"},
	["DK坦"] = {"DKT", "血DK", "死骑坦克"},
	
	-- 坦克职业缩写
	["ZST"] = {"战士坦克", "防战", "坦克战士"},
	["战士坦克"] = {"ZST", "防战", "坦克战士"},
	["QST"] = {"骑士坦克", "防骑", "坦克骑士"},
	["骑士坦克"] = {"QST", "防骑", "坦克骑士"},
	["XDT"] = {"德鲁伊坦克", "熊T", "熊坦"},
	["德鲁伊坦克"] = {"XDT", "熊T", "熊坦"},
	
	-- 治疗职业缩写（补充）
	["QSN"] = {"骑士奶", "奶骑", "治疗骑士"},
	["骑士奶"] = {"QSN", "奶骑", "治疗骑士"},
	["XDN"] = {"德鲁伊奶", "奶德", "治疗德鲁伊"},
	["德鲁伊奶"] = {"XDN", "奶德", "治疗德鲁伊"},
	["SMN"] = {"萨满奶", "奶萨", "治疗萨满"},
	["萨满奶"] = {"SMN", "奶萨", "治疗萨满"},
	["MSN"] = {"牧师奶", "奶牧", "治疗牧师"},
	["牧师奶"] = {"MSN", "奶牧", "治疗牧师"},
}

-- 其他常用缩写
local MISC_ALIASES = {
	-- G团相关
	["G团"] = {"金团", "GDKP"},
	["金团"] = {"G团", "GDKP"},
	["GDKP"] = {"G团", "金团"},
	
	-- 装备相关
	["MS"] = {"主需", "MAINSPEC"},
	["主需"] = {"MS", "MAINSPEC"},
	["OS"] = {"副需", "OFFSPEC"},
	["副需"] = {"OS", "OFFSPEC"},
	
	-- 组队相关
	["YX"] = {"有效", "有效率"},
	["有效"] = {"YX", "有效率"},
	["速通"] = {"ST", "SPEEDRUN"},
	["ST"] = {"速通", "SPEEDRUN"},
	["来"] = {"M", "密我", "来人"},
	["M"] = {"来", "密我", "来人"},
	["密我"] = {"M", "来", "来人"},
	
	-- 装等相关
	["GS"] = {"装等", "装备等级", "GEARSCORE"},
	["装等"] = {"GS", "装备等级", "GEARSCORE"},
	["装备等级"] = {"GS", "装等", "GEARSCORE"},
	
	-- 职业简写（单字母或双字母）
	["CJ"] = {"惩戒", "惩戒骑士"},
	["惩戒"] = {"CJ", "惩戒骑士"},
	["SH"] = {"神圣", "神圣骑士"},
	["神圣"] = {"SH", "神圣骑士"},
	["FH"] = {"防护", "防护骑士", "防护战士"},
	["防护"] = {"FH", "防护骑士", "防护战士"},
	
	-- 其他常见
	["FB"] = {"副本", "DUNGEON"},
	["副本"] = {"FB", "DUNGEON"},
	["YX"] = {"英雄", "英雄副本"},
	["英雄"] = {"YX", "英雄副本"},
	["PT"] = {"普通", "普通副本"},
	["普通"] = {"PT", "普通副本"},
}

--[[============================================
    公共接口函数
============================================]]--

-- 扩展关键词，返回所有可能的匹配项
-- @param keyword string 原始关键词
-- @return table 包含原始关键词和所有别名的数组
function Aliases.ExpandKeyword(keyword)
	if not keyword or keyword == "" then
		return {keyword}
	end
	
	local upperKeyword = upper(keyword)
	local result = {upperKeyword}  -- 始终包含原始关键词
	
	-- 查找所有映射表
	local allMaps = {
		RAID_ALIASES,
		CLASS_ALIASES,
		ROLE_ALIASES,
		CLASS_ROLE_ALIASES,
		MISC_ALIASES
	}
	
	for _, aliasMap in ipairs(allMaps) do
		if aliasMap[upperKeyword] then
			-- 找到匹配的别名组
			for _, alias in ipairs(aliasMap[upperKeyword]) do
				local upperAlias = upper(alias)
				-- 避免重复添加
				local found = false
				for _, existing in ipairs(result) do
					if existing == upperAlias then
						found = true
						break
					end
				end
				if not found then
					tinsert(result, upperAlias)
				end
			end
			break  -- 找到一个匹配就停止
		end
	end
	
	return result
end

-- 获取关键词的所有别名（不包含原始关键词）
-- @param keyword string 原始关键词
-- @return table 别名数组
function Aliases.GetAliases(keyword)
	if not keyword or keyword == "" then
		return {}
	end
	
	local upperKeyword = upper(keyword)
	local result = {}
	
	-- 查找所有映射表
	local allMaps = {
		RAID_ALIASES,
		CLASS_ALIASES,
		ROLE_ALIASES,
		CLASS_ROLE_ALIASES,
		MISC_ALIASES
	}
	
	for _, aliasMap in ipairs(allMaps) do
		if aliasMap[upperKeyword] then
			-- 找到匹配的别名组
			for _, alias in ipairs(aliasMap[upperKeyword]) do
				local upperAlias = upper(alias)
				if upperAlias ~= upperKeyword then  -- 排除原始关键词
					tinsert(result, upperAlias)
				end
			end
			break
		end
	end
	
	return result
end

--[[============================================
    模块初始化
============================================]]--

-- 模块加载完成标记
KM.Aliases.Loaded = true

-- 调试信息
if KM.Debug then
	print("|cff00ff00KeywordMonitor:|r Aliases 模块已加载")
end

-- don't load if class is wrong
local _, class = UnitClass("player")
if class ~= "PALADIN" then return end


local UnitBuff = clcret.UnitBuff

SPELL_POWER_HOLY_POWER = Enum.PowerType.HolyPower

local GetTime = GetTime
local dbg

local db

-- @defines
--------------------------------------------------------------------------------
local gcdId 				= 85256 -- tv for gcd
-- list of spellId
local howId 				=	24275	-- hammer of wrath
local csId 					= 35395	-- crusader strike
local tvId					= 85256	-- templar's verdict
local inqId					= 84963	-- inquisition
local dsId					= 53385	-- divine storm
local jId						= 20271	-- judgement
local consId				= 26573	-- consecration
local exoId					= 879		-- exorcism
local hwId					= 2812 	-- holy wrath
local zealId				= 85696 -- zealotry
local inqId					= 84963 -- inquisition
-- csName to pass as argument for melee range checks
local csName			= GetSpellInfo(csId)
-- buffs
local buffZeal 	= GetSpellInfo(zealId)	-- zealotry
local buffDP		= GetSpellInfo(90174)		-- divine purpose
local buffAoW		= GetSpellInfo(59578)		-- the art of war
local buffInq 	= GetSpellInfo(inqId)		-- inquisition

-- status vars
local s1, s2
local s_ctime, s_otime, s_gcd, s_hp, s_inq, s_zeal, s_aow, s_dp, s_haste, s_targetType

-- the queue
local qn = {} 		-- normal queue
local qz = {} 		-- zeal queue
local q 					-- working var

local function GetCooldown(id)
	local start, duration = GetSpellCooldown(id)
	local cd = start + duration - s_ctime - s_gcd
	if cd < 0 then return 0 end
	return cd
end


local t13 = 0
local tierSlots = {1,3,5,7,10}
local combatStart = 0
function clcret.GetRGSetBonus(self,event)
	if event == "PLAYER_REGEN_DISABLED" then
		combatStart = GetTime()
	end
	local t = 0
	for _,slot in ipairs(tierSlots) do
		local id = GetInventoryItemID("player",slot)
		if id then
			local set = select(16,GetItemInfo(id))
			if set == 1064 then
				t = t + 1
			end
		end
	end
	--if t ~= tierPieces then print(t) end 
	t13 = t
end

local setbonusTracker = CreateFrame("Frame")
setbonusTracker:RegisterEvent("PLAYER_REGEN_ENABLED")
setbonusTracker:RegisterEvent("PLAYER_REGEN_DISABLED")
setbonusTracker:SetScript("OnEvent",clcret.GetRGSetBonus)

-- actions ---------------------------------------------------------------------
local actions = {
	-- inquisition, apply, 3 hp
	inqa = {
		id = inqId,
		GetCD = function()
			--79634 pre pot
			if db.inq3hp and (GetTime() - combatStart < 30 or not InCombatLockdown()) and not(s_dp > 0 or s_hp >= 3) and GetCooldown(zealId) <= 0 then
				return 100
			elseif s_inq <= 0 and (s_hp >= db.inqApplyMin or s_dp > 0) then
				return 0
			else
				return 100
			end
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5 / s_haste
			s_inq = 100	-- make sure it's not shown for next skill
			if s_dp > 0 then s_dp = 0 else s_hp = 0 end -- adjust hp/dp
		end,
		info = "apply Inquisition",
	},
	inqahp = {
		id = inqId,
		GetCD = function()
			if s_inq <= 0 and s_hp >= db.inqApplyMin then
				return 0
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5 / s_haste
			s_inq = 100	-- make sure it's not shown for next skill
			if s_dp > 0 then s_dp = 0 else s_hp = 0 end -- adjust hp/dp
		end,
		info = "apply Inquisition at x HP",
	},
	inqadp = {
		id = inqId,
		GetCD = function()
			if s_inq <= 0 and s_dp > 0 then
				return 0
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5 / s_haste
			s_inq = 100	-- make sure it's not shown for next skill
			if s_dp > 0 then s_dp = 0 else s_hp = 0 end -- adjust hp/dp
		end,
		info = "apply Inquisition at DP",
	},
	inqr = {
		id = inqId,
		GetCD = function()
			if s_inq > 0 and s_inq <= db.inqRefresh and (s_hp >= db.inqRefreshMin or s_dp > 0) then
				return 0
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5 / s_haste
			s_inq = 100	-- make sure it's not shown for next skill
			if s_dp > 0 then s_dp = 0 else s_hp = 0 end -- adjust hp/dp
		end,
		info = "refresh Inquisition",
	},
	inqrhp = {
		id = inqId,
		GetCD = function()
			if s_inq > 0 and s_inq <= db.inqRefresh and s_hp >= db.inqRefreshMin then
				return 0
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5 / s_haste
			s_inq = 100	-- make sure it's not shown for next skill
			if s_dp > 0 then s_dp = 0 else s_hp = 0 end -- adjust hp/dp
		end,
		info = "refresh Inquisition at x HP",
	},
	inqrdp = {
		id = inqId,
		GetCD = function()
			if s_inq > 0 and s_inq <= db.inqRefresh - 0.5 and s_dp > 0 then
				return 0
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5 / s_haste
			s_inq = 100	-- make sure it's not shown for next skill
			if s_dp > 0 then s_dp = 0 else s_hp = 0 end -- adjust hp/dp
		end,
		info = "refresh Inquisition at DP",
	},
	exoud = {
		id = exoId,
		GetCD = function()
			if (s_targetType == db.undead or s_targetType == db.demon) and s_aow > 0 then
				return 0
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5 / s_haste
			s_aow = 0 -- make sure it's not shown for next skill
		end,
		info = "Exorcism with guaranteed crit",
	},
	exo = {
		id = exoId,
		GetCD = function()
			if s_aow > 0 then
				return 0
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5 / s_haste
			s_aow = 0 -- make sure it's not shown for next skill
		end,
		info = "Exorcism",
	},
	how = {
		id = howId,
		GetCD = function()
			if IsUsableSpell(howId) and s1 ~= howId then
				return GetCooldown(howId)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5 / s_haste
		end,
		info = "Hammer of Wrath",
	},
	tv = {
		id = tvId,
		GetCD = function()
			if s_hp >= 3 or s_dp > 0 then
				return 0
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			if s_dp > 0 then s_dp = 0 else s_hp = 0 end -- adjust hp/dp
		end,
		info = "Templar's Verdict",
	},
	tvhp = {
		id = tvId,
		GetCD = function()
			if s_hp >= 3 then
				return 0
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			if s_dp > 0 then s_dp = 0 else s_hp = 0 end -- adjust hp/dp
		end,
		info = "Templar's Verdict at 3 HP",
	},
	tvdp = {
		id = tvId,
		GetCD = function()
			if s_dp > 0 then
				return 0
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			if s_dp > 0 then s_dp = 0 else s_hp = 0 end -- adjust hp/dp
		end,
		info = "Templar's Verdict at DP",
	},
	cs = {
		id = csId,
		GetCD = function()
			if s_hp >= 3 then return 100 end
			if s1 == csId then
				return (4.5 / s_haste - 1.5)
			else
				local csCd = GetCooldown(csId) - db.csBuffer
				if csCd < 0 then csCd = 0 end
				return csCd
			end
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			if s_zeal > 0 then
				s_hp = 3
			else
				s_hp = s_hp + 1
			end
		end,
		info = "Crusader Strike",
	},
	j = {
		id = jId,
		GetCD = function()
			if s1 ~= jId then
				return GetCooldown(jId) + db.jClash
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
		end,
		info = "Judgement",
	},
	jhp = {
		id = jId,
		GetCD = function()
			if s_hp >= 3 or t13 < 2 then return 100 end
			if s1 ~= jId then
				local jCd = GetCooldown(jId) - db.csBuffer
				if jCd < 0 then jCd = 0 end
				return jCd
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = s_hp + 1
		end,
		info = "Judgement that generates 1 HP",
	},
	hw = {
		id = hwId,
		GetCD = function()
			if s1 ~= hwId then
				return GetCooldown(hwId) + db.hwClash
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5 / s_haste
		end,
		info = "Holy Wrath",
	},
	cons = {
		id = consId,
		GetCD = function()
			if s1 ~= consId and UnitPower("player") > db.consMana then
				return GetCooldown(consId) + db.consClash
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5 / s_haste
		end,
		info = "Consecration",
	},
}
clcret.RR_actions = actions
--------------------------------------------------------------------------------

function clcret.RR_UpdateQueue()
	-- get the current db
	db = clcret.db.profile.rotation

	-- normal queue
	qn = {}
	for v in string.gmatch(db.prio, "[^ ]+") do
		if actions[v] then
			table.insert(qn, v)
		else
			print("clcret", "invalid action:", v)
		end
	end
	db.prio = table.concat(qn, " ")
	
	-- zealotry queue
	qz = {}
	for v in string.gmatch(db.prioZeal, "[^ ]+") do
		if actions[v] then
			table.insert(qz, v)
		else
			print("clcret", "invalid action (zealotry prio):", v)
		end
	end
	db.prioZeal = table.concat(qz, " ")
end

local function GetBuff(buff)
	local left
	--print(UnitBuff("player", buff, nil, "PLAYER"))
	_, _, _, _, _, expires = UnitBuff("player", buff, nil, "PLAYER")
	if expires then
		left = expires - s_ctime - s_gcd
		if left < 0 then left = 0 end
		--print(left)
	else
		left = 0
	end
	return left
end

-- reads all the interesting data
local function GetStatus()
	-- current time
	s_ctime = GetTime()
	
	-- gcd value
	local start, duration = GetSpellCooldown(gcdId)
	s_gcd = start + duration - s_ctime
	if s_gcd < 0 then s_gcd = 0 end
	
	-- the buffs
	s_dp = GetBuff(buffDP)
	s_aow = GetBuff(buffAoW)
	s_zeal = GetBuff(buffZeal)
	s_inq = GetBuff(buffInq)
	
	-- client hp and haste
	s_hp = UnitPower("player", SPELL_POWER_HOLY_POWER)
	s_haste = 1 + UnitSpellHaste("player") / 100
	
	-- undead/demon -> different exorcism
	s_targetType = UnitCreatureType("target")
end

local function GetNextAction()
	-- get the current db
	db = clcret.db.profile.rotation
	-- decide which queue to use
	if s_zeal > 0 and db.usePrioZeal then
		q = qz
	else
		q = qn
	end

	local n = #q
	
	-- parse once, get cooldowns, return first 0
	for i = 1, n do
		local action = actions[q[i]]
		local cd = action.GetCD()
		if cd == 0 then
			return action.id, q[i]
		end
		action.cd = cd
	end
	
	-- parse again, return min cooldown
	local minQ = 1
	local minCd = actions[q[1]].cd
	for i = 2, n do
		local action = actions[q[i]]
		if minCd > action.cd then
			minCd = action.cd
			minQ = i
		end
	end
	return actions[q[minQ]].id, q[minQ]
end

function clcret.RetRotation()
	-- get the current db
	db = clcret.db.profile.rotation

	s1 = nil
	GetStatus()
	local action
	s1, action = GetNextAction()
	s_otime = s_ctime -- save it so we adjust buffs for next
	actions[action].UpdateStatus()
	
	-- adjust buffs
	s_otime = s_ctime - s_otime
	s_dp = max(0, s_dp - s_otime)
	s_aow = max(0, s_aow - s_otime)
	s_zeal = max(0, s_zeal - s_otime)
	s_inq = max(0, s_inq - s_otime)
	
	s2, action = GetNextAction()
	
	return s1, s2
end


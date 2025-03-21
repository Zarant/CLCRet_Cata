local _, trueclass = UnitClass("player")
if trueclass ~= "PALADIN" then return end

clcret.optionsLoaded = true

local MAX_AURAS = 20
local MAX_SOVBARS = 5

local db = clcret.db.profile
local root

local strataLevels = {
	"BACKGROUND",
	"LOW",
	"MEDIUM",
	"HIGH",
	"DIALOG",
	"FULLSCREEN",
	"FULLSCREEN_DIALOG",
	"TOOLTIP",
}

local anchorPoints = {
	CENTER = "CENTER",
	TOP = "TOP",
	BOTTOM = "BOTTOM",
	LEFT = "LEFT",
	RIGHT = "RIGHT",
	TOPLEFT = "TOPLEFT",
	TOPRIGHT = "TOPRIGHT",
	BOTTOMLEFT = "BOTTOMLEFT",
	BOTTOMRIGHT = "BOTTOMRIGHT"
}
local execList = {
	AuraButtonExecNone = "None",
	AuraButtonExecSkillVisibleAlways = "Skill always visible",
	AuraButtonExecSkillVisibleNoCooldown = "Skill visible when available",
	AuraButtonExecSkillVisibleOnCooldown = "Skill visible when not available",
	AuraButtonExecItemVisibleAlways = "OnUse item always visible",
	AuraButtonExecItemVisibleNoCooldown = "OnUse item visible when available",
	AuraButtonExecGenericBuff = "Generic buff",
	AuraButtonExecGenericDebuff = "Generic debuff",
	AuraButtonExecPlayerMissingBuff = "Missing player buff",
	AuraButtonExecICDItem = "ICD Proc",
}
local skillButtonNames = { "Main skill", "Secondary skill" }


-- index lookup for aura buttons
local ilt = {}
for i = 1, MAX_AURAS do
	ilt["aura" .. i] = i
end

-- aura buttons get/set functions
local abgs = {}

function abgs:UpdateAll()
	clcret:UpdateEnabledAuraButtons()
	clcret:UpdateAuraButtonsCooldown()
	clcret:AuraButtonUpdateICD()
	clcret:AuraButtonResetTextures()
end

-- enabled toggle
function abgs:EnabledGet()
	local i = ilt[self[2]]
	
	return db.auras[i].enabled
end
function abgs:EnabledSet(val)
	local i = ilt[self[2]]
	
	clcret.temp = info
	if db.auras[i].data.spell == "" then
		val = false
		print("Not a valid spell name/id or buff name!")
	end
	db.auras[i].enabled = val
	if not val then clcret:AuraButtonHide(i) end
	abgs:UpdateAll()
end

-- id/name field
function abgs:SpellGet()
	local i = ilt[self[2]]
	
	-- special case for items since link is used instead of name
	if (db.auras[i].data.exec == "AuraButtonExecItemVisibleAlways") or (db.auras[i].data.exec == "AuraButtonExecItemVisibleNoCooldown") then
		return db.auras[i].data.spell
	elseif db.auras[i].data.exec == "AuraButtonExecICDItem" then
		return GetSpellInfo(db.auras[i].data.spell)
	end
	return db.auras[i].data.spell
end

function abgs:SpellSet(val)
	local i = ilt[self[2]]
	
	-- skill
	if (db.auras[i].data.exec == "AuraButtonExecSkillVisibleAlways") or (db.auras[i].data.exec == "AuraButtonExecSkillVisibleNoCooldown") or (db.auras[i].data.exec == "AuraButtonExecSkillVisibleOnCooldown") then
		local name = GetSpellInfo(val)
		if name then
			db.auras[i].data.spell = name
		else
			db.auras[i].data.spell = ""
			db.auras[i].enabled = false
			clcret:AuraButtonHide(i)
			print("Not a valid spell name or id !")
		end
	-- item
	elseif (db.auras[i].data.exec == "AuraButtonExecItemVisibleAlways") or (db.auras[i].data.exec == "AuraButtonExecItemVisibleNoCooldown") then
		local name, link = GetItemInfo(val)
		if name then
			db.auras[i].data.spell = val
		else
			db.auras[i].data.spell = ""
			db.auras[i].enabled = false
			clcret:AuraButtonHide(i)
			print("Not a valid item name or id !")
		end
	-- icd stuff
	elseif (db.auras[i].data.exec == "AuraButtonExecICDItem") then
		local tid = tonumber(val)
		local name = GetSpellInfo(tid)
		if name then
			db.auras[i].data.spell = tid
		else
			db.auras[i].data.spell = ""
			db.auras[i].enabled = false
			clcret:AuraButtonHide(i)
			print("Not a valid spell id!")
		end
	else
		db.auras[i].data.spell = val
	end
	
	abgs:UpdateAll()
end

-- type select
function abgs:ExecGet()
	local i = ilt[self[2]]
	
	return db.auras[i].data.exec
end

function abgs:ExecSet(val)
	local i = ilt[self[2]]
	local aura = db.auras[i]
	
	-- reset every other setting when this is changed
	aura.enabled = false
	aura.data.spell = ""
	aura.data.unit = ""
	aura.data.byPlayer = false
	clcret:AuraButtonHide(i)
	
	aura.data.exec = val
	
	abgs:UpdateAll()
end

-- target field
function abgs:UnitGet()
	local i = ilt[self[2]]
	
	return db.auras[i].data.unit
end

function abgs:UnitSet(val)
	local i = ilt[self[2]]
	
	db.auras[i].data.unit = val
	abgs:UpdateAll()
end

-- cast by player toggle
function abgs:ByPlayerGet()
	local i = ilt[self[2]]
	
	return db.auras[i].data.byPlayer
end

function abgs:ByPlayerSet(val)
	local i = ilt[self[2]]
	
	db.auras[i].data.byPlayer = val
	abgs:UpdateAll()
end

local function RotationGet(info)
	local xdb = clcret.db.profile.rotation
	return xdb[info[#info]]
end

local function RotationSet(info, val)
	local xdb = clcret.db.profile.rotation
	xdb[info[#info]] = val
	
	if info[#info] == "prio" or info[#info] == "prioZeal" then
		clcret.RR_UpdateQueue()
	end
end

local tx = {}
for k, v in pairs(clcret.RR_actions) do
	table.insert(tx, format("\n%s - %s", k, v.info))
end
table.sort(tx)
local prioInfo = "Legend:\n" .. table.concat(tx)

local options = {
	type = "group",
	name = "CLCRet",
	args = {
		global = {
			type = "group",
			name = "Global",
			order = 1,
			args = {
				-- lock frame
				lock = {
					order = 1,
					width = "full",
					type = "toggle",
					name = "Lock Frame",
					get = function(info) return clcret.locked end,
					set = function(info, val)
						clcret:ToggleLock()
					end,
				},
				
				show = {
					order = 10,
					type = "select",
					name = "Show",
					get = function(info) return db.show end,
					set = function(info, val)
						db.show = val
						clcret:UpdateShowMethod()
					end,
					values = { always = "Always", combat = "In Combat", valid = "Valid Target", boss = "Boss" }
				},
				
				__strata = {
					order = 15,
					type = "header",
					name = "",
				},
				____strata = {
					order = 16,
					type = "description",
					name = "|cffff0000WARNING|cffffffff Changing Strata value will automatically reload your UI."
				},
				strata = {
					order = 17,
					type = "select",
					name = "Frame Strata",
					get = function(info) return db.strata end,
					set = function(info, val)
						db.strata = val
						ReloadUI()
					end,
					values = strataLevels,
				},
				
				-- full disable toggle
				__fulldisable = {
					order = 20,
					type = "header",
					name = "",
				},
				fullDisable = {
					order = 21,
					width = "full",
					type = "toggle",
					name = "Addon disabled",
					get = function(info) return db.fullDisable end,
					set = function(info, val) clcret:FullDisableToggle() end,
				},
			},
		},
	
		-- appearance
		appearance = {
			order = 10,
			name = "Appearance",
			type = "group",
			args = {
				myppb = {
					order = 1, type = "group", inline = true, name = "Adjust Holy Power Bar",
					args = {
						adjustHPBar = {
							order = 1, type = "toggle",
							name = "Use own bar",
							get = function(info) return db.adjustHPBar end,
							set = function(info, val) db.adjustHPBar = val clcret:UpdatePPB() end,
						},
						hideBlizPPB = {
							order = 2, type = "toggle", width="double",
							name = "Hide Blizzard",
							get = function(info) return db.hideBlizPPB end,
							set = function(info, val) db.hideBlizPPB = val clcret:UpdatePPB() end,
						},
						ppbX = {
							order = 12, type = "range", min = -2000, max = 2000, step = 1, name = "X",
							get = function(info) return db.ppbX end,
							set = function(info, val) db.ppbX = val clcret:UpdatePPB() end,
						},
						ppbY = {
							order = 13, type = "range", min = -2000, max = 2000, step = 1, name = "Y",
							get = function(info) return db.ppbY end,
							set = function(info, val) db.ppbY = val clcret:UpdatePPB() end,
						},
						ppbScale = {
							order = 14, type = "range", min = 0.1, max = 10, step = 0.1, name = "Scale",
							get = function(info) return db.ppbScale end,
							set = function(info, val) db.ppbScale = val clcret:UpdatePPB() end,
						},
						ppbAlpha = {
							order = 15, type = "range", min = 0, max = 1, step = 0.01, name = "Alpha",
							get = function(info) return db.ppbAlpha end,
							set = function(info, val) db.ppbAlpha = val clcret:UpdatePPB() end,
						},
					},
				},
				__buttonAspect = {
					type = "header",
					name = "Button Aspect",
					order = 2,
				},
				zoomIcons = {
					order = 3,
					type = "toggle",
					name = "Zoomed icons",
					get = function(info) return db.zoomIcons end,
					set = function(info, val)
						db.zoomIcons = val
						clcret:UpdateSkillButtonsLayout()
						clcret:UpdateAuraButtonsLayout()
						clcret:UpdateSovBarsLayout()
					end,
				},
				noBorder = {
					order = 4,
					type = "toggle",
					name = "Hide border",
					get = function(info) return db.noBorder end,
					set = function(info, val)
						db.noBorder = val
						clcret:UpdateSkillButtonsLayout()
						clcret:UpdateAuraButtonsLayout()
						clcret:UpdateSovBarsLayout()
					end,
				},
				borderColor = {
					order = 5,
					type = "color",
					name = "Border color",
					hasAlpha = true,
					get = function(info) return unpack(db.borderColor) end,
					set = function(info, r, g, b, a)
						db.borderColor = {r, g, b, a}
						clcret:UpdateSkillButtonsLayout()
						clcret:UpdateAuraButtonsLayout()
						clcret:UpdateSovBarsLayout()
					end,
				},
				borderType = {
					order = 6,
					type = "select",
					name = "Border type",
					get = function(info) return db.borderType end,
					set = function(info, val)
						db.borderType = val
						clcret:UpdateSkillButtonsLayout()
						clcret:UpdateAuraButtonsLayout()
						clcret:UpdateSovBarsLayout()
					end,
					values = { "Light", "Medium", "Heavy" }
				},
				grayOOM = {
					order = 7,
					type = "toggle",
					name = "Gray when OOM",
					get = function(info) return db.grayOOM end,
					set = function(info, val)
						db.grayOOM = val
						clcret:ResetButtonVertexColor()
					end,
				},
				
				__hudAspect = {
					type = "header",
					name = "HUD Aspect",
					order = 10,
				},
				scale = {
					order = 11,
					type = "range",
					name = "Scale",
					min = 0.01,
					max = 3,
					step = 0.01,
					get = function(info) return db.scale end,
					set = function(info, val)
						db.scale = val
						clcret:UpdateFrameSettings()
					end,
				},
				alpha = {
					order = 12,
					type = "range",
					name = "Alpha",
					min = 0,
					max = 1,
					step = 0.001,
					get = function(info) return db.alpha end,
					set = function(info, val)
						db.alpha = val
						clcret:UpdateFrameSettings()
					end,
				},
				_hudPosition = {
					type = "header",
					name = "HUD Position",
					order = 13,
				},
				x = {
					order = 20,
					type = "range",
					name = "X",
					min = 0,
					max = 5000,
					step = 21,
					get = function(info) return db.x end,
					set = function(info, val)
						db.x = val
						clcret:UpdateFrameSettings()
					end,
				},
				y = {
					order = 22,
					type = "range",
					name = "Y",
					min = 0,
					max = 3000,
					step = 1,
					get = function(info) return db.y end,
					set = function(info, val)
						db.y = val
						clcret:UpdateFrameSettings()
					end,
				},
				align = {
					order = 23,
					type = "execute",
					name = "Center Horizontally",
					func = function()
						clcret:CenterHorizontally()
					end,
				},
				
				__icd = {
					order = 50,
					type = "header",
					name = "ICD Visibility",
				},
				____icd = {
					order = 51,
					type = "description",
					name = "Controls the way ICD Aura Buttons are displayed while the proc is ready or on cooldown.",
				},
				icdReady = {
					order = 52,
					type = "select",
					name = "Ready",
					values = { [1] = "Visible", [2] = "Faded", [3] = "Invisible" },
					get = function(info) return db.icd.visibility.ready end,
					set = function(info, val)
						db.icd.visibility.ready = val
					end,
				},
				icdCooldown = {
					order = 53,
					type = "select",
					name = "On cooldown",
					values = { [1] = "Visible", [2] = "Faded", [3] = "Invisible" },
					get = function(info) return db.icd.visibility.cd end,
					set = function(info, val)
						db.icd.visibility.cd = val
					end,
				}
			},
		},
	
		-- behavior
		behavior = {
			order = 15,
			name = "Behavior",
			type = "group",
			args = {
				__updateRates = {
					order = 1,
					type = "header",
					name = "Updates per Second",
				},
				ups = {
					order = 5,
					type = "range",
					name = "FCFS Detection",
					min = 1,
					max = 100,
					step = 1,
					get = function(info) return db.updatesPerSecond end,
					set = function(info, val)
						db.updatesPerSecond = val
						clcret.scanFrequency = 1 / val
					end,
				},
				upsAuras = {
					order = 6,
					type = "range",
					name = "Aura Detection",
					min = 1,
					max = 100,
					step = 1,
					get = function(info) return db.updatesPerSecondAuras end,
					set = function(info, val)
						db.updatesPerSecondAuras = val
						clcret.scanFrequencyAuras = 1 / val
					end,
				},
			
				__rangePerSkill = {
					order = 15,
					type = "header",
					name = "Range Display",
				},
				____rangePerSkill = {
					order = 16,
					type = "description",
					name = "By default the addon checks if you are in melee range and colors both main and secondary skills if not. This option allows you to display the range of the actual skills displayed.",
				},
				rangePerSkill = {
					order = 17,
					type = "toggle",
					width = "full",
					name = "Check range for each skill",
					get = function(info) return db.rangePerSkill end,
					set = function(info, val) db.rangePerSkill = val end,
				},
			},
		},
		
		rotation = {
			type = "group", name = "Rotation",
			args = {
				igPrio = {
					order = 1, type = "group", inline = true, name = "Priority",
					args = {
						info = {
							order = 1, type = "description", name = prioInfo,
						},
						normalPrio = {
							order = 2, type="group", inline = true, name = "Normal priority",
							args = {
								prio = {
									order = 2, type = "input", width = "full", name = "",
									get = RotationGet, set = RotationSet,
								},
								infoCMD = {
									order = 3, type = "description", name = "Sample command line usage: /clcretlp inqa tv cs exoud how exo",
								},
							},
						},
						inq3hp = {
							order = 2.1, type = "toggle", width = "full", name = "3 HP Inquisition on pull",
							get = RotationGet, set = RotationSet,
						},
						zealPrio = {
							order = 3, type="group", inline = true, name = "Zealotry priority",
							args = {
								usePrioZeal = {
									order = 1, type = "toggle", width = "full", name = "Enable zealotry priority",
									get = RotationGet, set = RotationSet,
								},
								prioZeal = {
									order = 2, type = "input", width = "full", name = "",
									get = RotationGet, set = RotationSet,
								},
								infoCMD = {
									order = 3, type = "description", name = "Sample command line usage: /clcretlpz inqa tv cs exoud how exo",
								},
							},
						},
						disclaimer = {
							order = 4, type = "description", name = "|cffff0000These are just examples, make sure you adjust them properly!|cffffffff",
						},
					},
				},
				igInquisition = {
					order = 2, type = "group", inline = true, name = "Inquisition",
					args = {
						inqRefresh = {
							order = 1, type = "range", min = 1, max = 15, step = 0.1, name = "Time before refresh",
							get = RotationGet, set = RotationSet,
						},
						inqApplyMin = {
							order = 2, type = "range", min = 1, max = 3, step = 1, name = "Min HP for Inquisition Apply",
							get = RotationGet, set = RotationSet,
						},
						inqRefreshMin = {
							order = 3, type = "range", min = 1, max = 3, step = 1, name = "Min HP for Inquisition Refresh",
							get = RotationGet, set = RotationSet,
						},
					},
				},
				igLocalization = {
					order = 3, type = "group", inline = true, name = "Creature type localization",
					args = {
						undead = {
							order = 1, type = "input", name = "Undead",
							get = RotationGet, set = RotationSet,
						},
						demon = {
							order = 2, type = "input", name = "Demon",
							get = RotationGet, set = RotationSet,
						},
					},
				},
				igFillers = {
					order = 4, type = "group", inline = true, name = "Fillers",
					args = {
						infoClash = {
							order = 1, type = "description", name = "Clash means the value of CS cooldown before the filler is used.",
						},
						jClash = {
							order = 2, type = "range", min = 0, max = 2, step = 0.1, name = "Judgement Clash",
							get = RotationGet, set = RotationSet,
						},
						spacing1 = {
							order = 3, type = "description", name = "",
						},
						hwClash = {
							order = 5, type = "range", min = 0, max = 2, step = 0.1, name = "Holy Wrath Clash",
							get = RotationGet, set = RotationSet,
						},
						csBuffer = {
							order = 5.5, type = "range", min = 0, max = 2, step = 0.1, name = "Crusader Strike Buffer",
							get = RotationGet, set = RotationSet,
						},
						spacing2 = {
							order = 6, type = "description", name = "",
						},
						consClash = {
							order = 8, type = "range", min = 0, max = 2, step = 0.1, name = "Consecration Clash",
							get = RotationGet, set = RotationSet,
						},
						consMana = {
							order = 9, type = "range", min = 0, max = 30000, step = 1, name = "Minimum mana required",
							get = RotationGet, set = RotationSet,
						},
					},
				},
			},
		},
		
		-- aura buttons
		auras = {
			order = 30,
			name = "Aura Buttons",
			type = "group",
			args = {
				____info = {
					order = 1,
					type = "description",
					name = "These are cooldown watchers. You can select a player skill, an item or a buff/debuff (on a valid target) to watch.\nItems and skills only need a valid item/spell id (or name) and the type. Target (the target to scan) and Cast by player (filters or not buffs cast by others) are specific to buffs/debuffs.\nValid targets are the ones that work with /cast [target=name] macros. For example: player, target, focus, raid1, raid1target.\n\nICD Proc:\nYou need to specify a valid proc ID (example: 60229 for Greatness STR proc) Name doesn't work, if the ID is valid it will be replaced by the name after the edit.\nIn the \"Target unit\" field you have to enter the ICD and duration of the proc separated by \":\" (example: for Greatness the value should be 45:15).",
				},
			},
		},
	
		-- layout
		layout = {
			order = 31,
			name = "Layout",
			type = "group",
			args = {},
		},
		
		
		-- sov tracking
		sov = {
			order = 40,
			name = "SoV/SoCorr Tracking",
			type = "group",
			args = {
				____info = {
					order = 1,
					type = "description",
					name = "This module provides bars or icons to watch the cooldown of your Seal of Vengeance/Corruption debuff on different targets.\nIt tracks combat log events so disable it unless you really need it.\nTargets are tracked by their GUID from combat log events.",
				},
				enabled = {
					order = 2,
					type = "toggle",
					name = "Enable",
					get = function(info) return db.sov.enabled end,
					set = function(info, val) clcret:ToggleSovTracking() end,
				},
				updatesPerSecond = {
					order = 3,
					type = "range",
					name = "Updates per second",
					min = 1,
					max = 100,
					step = 1,
					get = function(info) return db.sov.updatesPerSecond end,
					set = function(info, val)
						db.sov.updatesPerSecond = val
						clcret.scanFrequencySov = 1 / val
					end,
				},
				__display = {
					order = 10,
					type = "header",
					name = "Appearance"
				},
				useButtons = {
					order = 11,
					width = "full",
					type = "toggle",
					name = "Icons instead of bars",
					get = function(info) return db.sov.useButtons end,
					set = function(invo, val)
						db.sov.useButtons = val
						clcret:UpdateSovBarsLayout()
					end,
				},
				____alpha = {
					order = 20,
					type = "description",
					name = "You can control if the bar/icon of your current target looks different than the other ones.\nFor bars it uses both alpha and color values while the icons only change their alpha.",
				},
				targetDifference = {
					order = 21,
					width = "full",
					type = "toggle",
					name = "Different color for target",
					get = function(info) return db.sov.targetDifference end,
					set = function(info, val)
						db.sov.targetDifference = val
						clcret:UpdateSovBarsLayout()
					end,
				},
				color = {
					order = 22,
					type = "color",
					name = "Target color/alpha",
					hasAlpha = true,
					get = function(info) return unpack(db.sov.color) end,
					set = function(info, r, g, b, a)
						db.sov.color = {r, g, b, a}
						clcret:UpdateSovBarsLayout()
					end,
				},
				colorNonTarget = {
					order = 23,
					type = "color",
					name = "Non target color/alpha",
					hasAlpha = true,
					get = function(info) return unpack(db.sov.colorNonTarget) end,
					set = function(info, r, g, b, a)
						db.sov.colorNonTarget = {r, g, b, a}
					end,
				},
				__layout = {
					order = 40,
					type = "header",
					name = "Layout",
				},
				showAnchor = {
					order = 50,
					width = "full",
					type = "toggle",
					name = "Show anchor (not movable)",
					get = function(info) return clcret.showSovAnchor end,
					set = function(invo, val) clcret:ToggleSovAnchor() end,
				},
				growth = {
					order = 60,
					type = "select",
					name = "Growth direction",
					get = function(info) return db.sov.growth end,
					set = function(info, val)
						db.sov.growth = val
						clcret:UpdateSovBarsLayout()
					end,
					values = { up = "Up", down = "Down", left = "Left", right = "Right" }
				},
				spacing = {
					order = 70,
					type = "range",
					name = "Spacing",
					min = 0,
					max = 100,
					step = 1,
					get = function(info) return db.sov.spacing end,
					set = function(info, val)
						db.sov.spacing = val
						clcret:UpdateSovBarsLayout()
					end,
				},
				
				anchor = {
					order = 80,
					type = "select",
					name = "Anchor",
					get = function(info) return db.sov.point end,
					set = function(info, val)
						db.sov.point = val
						clcret:UpdateSovBarsLayout()
					end,
					values = anchorPoints,
				},
				anchorTo = {
					order = 81,
					type = "select",
					name = "Anchor To",
					get = function(info) return db.sov.pointParent end,
					set = function(info, val)
						db.sov.pointParent = val
						clcret:UpdateSovBarsLayout()
					end,
					values = anchorPoints,
				},
				x = {
					order = 82,
					type = "range",
					name = "X",
					min = -1000,
					max = 1000,
					step = 1,
					get = function(info) return db.sov.x end,
					set = function(info, val)
						db.sov.x = val
						clcret:UpdateSovBarsLayout()
					end,
				},
				y = {
					order = 83,
					type = "range",
					name = "Y",
					min = -1000,
					max = 1000,
					step = 1,
					get = function(info) return db.sov.y end,
					set = function(info, val)
						db.sov.y = val
						clcret:UpdateSovBarsLayout()
					end,
				},
				width = {
					order = 90,
					type = "range",
					name = "Width",
					min = 1,
					max = 1000,
					step = 1,
					get = function(info) return db.sov.width end,
					set = function(info, val)
						db.sov.width = val
						clcret:UpdateSovBarsLayout()
					end,
				},
				height = {
					order = 91,
					type = "range",
					name = "Height (Size for Icons)",
					min = 1,
					max = 500,
					step = 1,
					get = function(info) return db.sov.height end,
					set = function(info, val)
						db.sov.height = val
						clcret:UpdateSovBarsLayout()
					end,
				},
			},
		},
	},
}

	-- add main buttons to layout
for i = 1, 2 do
	options.args.layout.args["button" .. i] = {
		order = i,
		name = skillButtonNames[i],
		type = "group",
		args = {
			size = {
				order = 1,
				type = "range",
				name = "Size",
				min = 1,
				max = 300,
				step = 1,
				get = function(info) return db.layout["button" .. i].size end,
				set = function(info, val)
					db.layout["button" .. i].size = val
					clcret:UpdateSkillButtonsLayout()
				end,
			},
			alpha = {
				order = 2,
				type = "range",
				name = "Alpha",
				min = 0,
				max = 1,
				step = 0.01,
				get = function(info) return db.layout["button" .. i].alpha end,
				set = function(info, val)
					db.layout["button" .. i].alpha = val
					clcret:UpdateSkillButtonsLayout()
				end,
			},
			anchor = {
				order = 6,
				type = "select",
				name = "Anchor",
				get = function(info) return db.layout["button" .. i].point end,
				set = function(info, val)
					db.layout["button" .. i].point = val
					clcret:UpdateSkillButtonsLayout()
				end,
				values = anchorPoints,
			},
			anchorTo = {
				order = 6,
				type = "select",
				name = "Anchor To",
				get = function(info) return db.layout["button" .. i].pointParent end,
				set = function(info, val)
					db.layout["button" .. i].pointParent = val
					clcret:UpdateSkillButtonsLayout()
				end,
				values = anchorPoints,
			},
			x = {
				order = 10,
				type = "range",
				name = "X",
				min = -1000,
				max = 1000,
				step = 1,
				get = function(info) return db.layout["button" .. i].x end,
				set = function(info, val)
					db.layout["button" .. i].x = val
					clcret:UpdateSkillButtonsLayout()
				end,
			},
			y = {
				order = 11,
				type = "range",
				name = "Y",
				min = -1000,
				max = 1000,
				step = 1,
				get = function(info) return db.layout["button" .. i].y end,
				set = function(info, val)
					db.layout["button" .. i].y = val
					clcret:UpdateSkillButtonsLayout()
				end,
			},
		},
	}
end

-- add the buttons to options
for i = 1, MAX_AURAS do
	-- aura options
	options.args.auras.args["aura" .. i] = {
		order = i + 10,
		type = "group",
		name = "Aura Button " .. i,
		args = {
			enabled = {
				order = 1,
				type = "toggle",
				name = "Enabled",
				get = abgs.EnabledGet,
				set = abgs.EnabledSet,
			},
			spell = {
				order = 5,
				type = "input",
				name = "Spell/item name/id or buff to track",
				get = abgs.SpellGet,
				set = abgs.SpellSet,
			},
			exec = {
				order = 10,
				type = "select",
				name = "Type",
				get = abgs.ExecGet,
				set = abgs.ExecSet,
				values = execList,
			},
			unit = {
				order = 15,
				type = "input",
				name = "Target unit",
				get = abgs.UnitGet,
				set = abgs.UnitSet,
			},
			byPlayer = {
				order = 16,
				type = "toggle",
				name = "Cast by player",
				get = abgs.ByPlayerGet,
				set = abgs.ByPlayerSet,
			}
		},
	}
	
	-- layout
	options.args.layout.args["aura" .. i] = {
		order = 10 + i,
		type = "group",
		name = "Aura Button " .. i,
		args = {
			size = {
				order = 1,
				type = "range",
				name = "Size",
				min = 1,
				max = 300,
				step = 1,
				get = function(info) return db.auras[i].layout.size end,
				set = function(info, val)
					db.auras[i].layout.size = val
					clcret:UpdateAuraButtonLayout(i)
				end,
			},
			anchor = {
				order = 6,
				type = "select",
				name = "Anchor",
				get = function(info) return db.auras[i].layout.point end,
				set = function(info, val)
					db.auras[i].layout.point = val
					clcret:UpdateAuraButtonLayout(i)
				end,
				values = anchorPoints,
			},
			anchorTo = {
				order = 6,
				type = "select",
				name = "Anchor To",
				get = function(info) return db.auras[i].layout.pointParent end,
				set = function(info, val)
					db.auras[i].layout.pointParent = val
					clcret:UpdateAuraButtonLayout(i)
				end,
				values = anchorPoints,
			},
			x = {
				order = 10,
				type = "range",
				name = "X",
				min = -1000,
				max = 1000,
				step = 1,
				get = function(info) return db.auras[i].layout.x end,
				set = function(info, val)
					db.auras[i].layout.x = val
					clcret:UpdateAuraButtonLayout(i)
				end,
			},
			y = {
				order = 11,
				type = "range",
				name = "Y",
				min = -1000,
				max = 1000,
				step = 1,
				get = function(info) return db.auras[i].layout.y end,
				set = function(info, val)
					db.auras[i].layout.y = val
					clcret:UpdateAuraButtonLayout(i)
				end,
			},
		},
	}
end

--[[ remove the first one we added
for i = 1, #INTERFACEOPTIONS_ADDONCATEGORIES do
	if 	INTERFACEOPTIONS_ADDONCATEGORIES[i]
	and INTERFACEOPTIONS_ADDONCATEGORIES[i].name
	and INTERFACEOPTIONS_ADDONCATEGORIES[i].name == "CLCRet"
	then
		table.remove(INTERFACEOPTIONS_ADDONCATEGORIES, i)
	end
end]]

local AceConfig = LibStub("AceConfig-3.0")
AceConfig:RegisterOptionsTable("CLCRet", options)

local AceConfigDialog = LibStub("AceConfigDialog-3.0")
AceConfigDialog:AddToBlizOptions("CLCRet", "CLCRet", nil, "global")
AceConfigDialog:AddToBlizOptions("CLCRet", "CLCRet - Appearance", nil, "appearance")
AceConfigDialog:AddToBlizOptions("CLCRet", "CLCRet - Rotation", nil, "rotation")
AceConfigDialog:AddToBlizOptions("CLCRet", "CLCRet - Behavior", nil, "behavior")
AceConfigDialog:AddToBlizOptions("CLCRet", "CLCRet - Aura Buttons", nil, "auras")
AceConfigDialog:AddToBlizOptions("CLCRet", "CLCRet - Layout", nil, "layout")
AceConfigDialog:AddToBlizOptions("CLCRet", "CLCRet - SoV Tracking", nil, "sov")

-- profiles
options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(clcret.db)
options.args.profiles.order = 900
LibStub("AceConfigDialog-3.0"):AddToBlizOptions("CLCRet", "Profiles", "CLCRet", "profiles")

InterfaceOptionsFrame_OpenToCategory("CLCRet")


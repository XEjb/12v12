if not IsDedicatedServer() and not IsInToolsMode() then error("") end
-- Rebalance the distribution of gold and XP to make for a better 10v10 game
local GOLD_SCALE_FACTOR_INITIAL = 1
local GOLD_SCALE_FACTOR_FINAL = 2.5
local GOLD_SCALE_FACTOR_FADEIN_SECONDS = (60 * 60) -- 60 minutes
local XP_SCALE_FACTOR_INITIAL = 2
local XP_SCALE_FACTOR_FINAL = 2
local XP_SCALE_FACTOR_FADEIN_SECONDS = (60 * 60) -- 60 minutes

local game_start = true

-- Anti feed system
local TROLL_FEED_DISTANCE_FROM_FOUNTAIN_TRIGGER = 3000 -- Distance from allince Fountain
local TROLL_FEED_BUFF_BASIC_TIME = (60 * 10)   -- 10 minutes
local TROLL_FEED_TOTAL_RESPAWN_TIME_MULTIPLE = 2.5 -- x2.5 respawn time. If you respawn 100sec, after debuff you respawn 250sec
local TROLL_FEED_INCREASE_BUFF_AFTER_DEATH = 60 -- 1 minute
local TROLL_FEED_RATIO_KD_TO_TRIGGER_MIN = -5 -- (Kills+Assists-Deaths)
local TROLL_FEED_NEED_TOKEN_TO_BUFF = 3
local TROLL_FEED_TOKEN_TIME_DIES_WITHIN = (60 * 1.5) -- 1.5 minutes
local TROLL_FEED_TOKEN_DURATION = (60 * 5) -- 5 minutes
local TROLL_FEED_MIN_RESPAWN_TIME = 60 -- 1 minute
local TROLL_FEED_SYSTEM_ASSISTS_TO_KILL_MULTI = 1 -- 10 assists = 10 "kills"

local TROLL_FEED_FORBIDDEN_TO_BUY_ITEMS = {
	item_smoke_of_deceit = true,
	item_ward_observer = true,
	item_ward_sentry = true,
}

--Requirements to Buy Divine Rapier
local NET_WORSE_FOR_RAPIER_MIN = 20000

--Max neutral items for each player (hero/stash/courier)
_G.MAX_NEUTRAL_ITEMS_FOR_PLAYER = 3

bonusGoldApplied = {}

require("protected_custom_events")
require("common/init")
require("util")
require("neutral_items_drop_choice")
require("gpm_lib")
require("game_options/game_options")
require("shuffle/shuffle_team")
require("custom_pings")
require("chat_commands/admin_commands")

Precache = require( "precache" )

WebApi.customGame = "Dota12v12"

LinkLuaModifier("modifier_global_dummy_custom", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_dummy_inventory", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_core_courier", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_patreon_courier", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_shadow_amulet_thinker", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_fountain_phasing", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_abandoned", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_gold_bonus", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_troll_feed_token", 'anti_feed_system/modifier_troll_feed_token', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_troll_feed_token_couter", 'anti_feed_system/modifier_troll_feed_token_couter', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_troll_debuff_stop_feed", 'anti_feed_system/modifier_troll_debuff_stop_feed', LUA_MODIFIER_MOTION_NONE)

LinkLuaModifier("modifier_super_tower","game_options/modifiers_lib/modifier_super_tower", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_mega_creep","game_options/modifiers_lib/modifier_mega_creep", LUA_MODIFIER_MOTION_NONE)

LinkLuaModifier("modifier_delayed_damage","common/game_perks/modifier_lib/delayed_damage", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("creep_secret_shop","creep_secret_shop", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_stronger_builds","modifier_stronger_builds", LUA_MODIFIER_MOTION_NONE)


_G.lastDeathTimes = {}
_G.lastHeroKillers = {}
_G.lastHerosPlaceLastDeath = {}
_G.tableRadiantHeroes = {}
_G.tableDireHeroes = {}
_G.newRespawnTimes = {}

_G.tPlayersMuted = {}
_G.CUSTOM_GAME_STATS = CUSTOM_GAME_STATS or {}
for player_id = 0, 24 do
	_G.tPlayersMuted[player_id] = {}
	if not CUSTOM_GAME_STATS[player_id] then
		CUSTOM_GAME_STATS[player_id] = {
			perk = "",
			networth = 0,
			experiance = 0,
			building_damage = 0,
			hero_damage = 0,
			damage_taken = 0,
			wards = {
				npc_dota_observer_wards = 0,
				npc_dota_sentry_wards = 0,
			},
			killed_heroes = {},
			total_healing = 0,
		}
	end
end
if CMegaDotaGameMode == nil then
	_G.CMegaDotaGameMode = class({}) -- put CMegaDotaGameMode in the global scope
	--refer to: http://stackoverflow.com/questions/6586145/lua-require-with-global-local
end

function Activate()
	CMegaDotaGameMode:InitGameMode()
end

_G.ItemKVs = {}
_G.abandoned_players = {}
_G.first_dc_players = {}

function CMegaDotaGameMode:InitGameMode()
	_G.ItemKVs = LoadKeyValues("scripts/npc/npc_block_items_for_troll.txt")
	print( "10v10 Mode Loaded!" )

	local neutral_items = LoadKeyValues("scripts/npc/neutral_items.txt")

	_G.neutralItems = {}
	self.spawned_couriers = {}
	self.disconnected_players = {}
	for _, data in pairs( neutral_items ) do
		for item, turn in pairs( data.items ) do
			if turn == 1 then
				_G.neutralItems[item] = true
			end
		end
	end

	self.last_player_orders = {}

	for player_id = 0, 24 do
		self.last_player_orders[player_id] = 0
	end

	-- Adjust team limits
	GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_GOODGUYS, 24)
	GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_BADGUYS, 0)
	GameRules:SetStrategyTime( 0.0 )
	GameRules:SetShowcaseTime( 0.0 )

	-- Hook up gold & xp filters
    GameRules:GetGameModeEntity():SetItemAddedToInventoryFilter( Dynamic_Wrap( CMegaDotaGameMode, "ItemAddedToInventoryFilter" ), self )
	GameRules:GetGameModeEntity():SetModifyGoldFilter( Dynamic_Wrap( CMegaDotaGameMode, "FilterModifyGold" ), self )
	GameRules:GetGameModeEntity():SetModifyExperienceFilter( Dynamic_Wrap(CMegaDotaGameMode, "FilterModifyExperience" ), self )
	GameRules:GetGameModeEntity():SetBountyRunePickupFilter( Dynamic_Wrap(CMegaDotaGameMode, "FilterBountyRunePickup" ), self )
	GameRules:GetGameModeEntity():SetModifierGainedFilter( Dynamic_Wrap( CMegaDotaGameMode, "ModifierGainedFilter" ), self )
	GameRules:GetGameModeEntity():SetExecuteOrderFilter(Dynamic_Wrap(CMegaDotaGameMode, 'ExecuteOrderFilter'), self)
	GameRules:GetGameModeEntity():SetDamageFilter( Dynamic_Wrap( CMegaDotaGameMode, "DamageFilter" ), self )
	GameRules:SetCustomGameBansPerTeam(12)
	GameRules:SetIgnoreLobbyTeamsInCustomGame(false) -- DONT FUCKING REMOVE THIS HOLY SHIT

	GameRules:GetGameModeEntity():SetUseDefaultDOTARuneSpawnLogic(true)

	GameRules:GetGameModeEntity():SetTowerBackdoorProtectionEnabled( true )
	GameRules:GetGameModeEntity():SetPauseEnabled(IsInToolsMode())
	GameRules:SetGoldTickTime( 0.3 ) -- default is 0.6
	GameRules:LockCustomGameSetupTeamAssignment(true)

	if GetMapName() == "dota_tournament" then
		GameRules:SetCustomGameSetupAutoLaunchDelay(20)
	else
		GameRules:SetCustomGameSetupAutoLaunchDelay(10)
	end

	GameRules:GetGameModeEntity():SetKillableTombstones( true )
	GameRules:GetGameModeEntity():SetFreeCourierModeEnabled(true)
	Convars:SetInt("dota_max_physical_items_purchase_limit", 100)
	Convars:SetInt("dota_max_disconnected_time", 300)
	if IsInToolsMode() then
		GameRules:GetGameModeEntity():SetDraftingBanningTimeOverride(0)
	end

	ListenToGameEvent("dota_match_done", Dynamic_Wrap(CMegaDotaGameMode, 'OnMatchDone'), self)
	ListenToGameEvent('game_rules_state_change', Dynamic_Wrap(CMegaDotaGameMode, 'OnGameRulesStateChange'), self)
	ListenToGameEvent( "npc_spawned", Dynamic_Wrap( CMegaDotaGameMode, "OnNPCSpawned" ), self )
	ListenToGameEvent( "entity_killed", Dynamic_Wrap( CMegaDotaGameMode, 'OnEntityKilled' ), self )
	ListenToGameEvent("dota_player_pick_hero", Dynamic_Wrap(CMegaDotaGameMode, "OnHeroPicked"), self)
	ListenToGameEvent('player_connect_full', Dynamic_Wrap(CMegaDotaGameMode, 'OnConnectFull'), self)
	ListenToGameEvent('player_disconnect', Dynamic_Wrap(CMegaDotaGameMode, 'OnPlayerDisconnect'), self)
	ListenToGameEvent( "player_chat", Dynamic_Wrap( CMegaDotaGameMode, "OnPlayerChat" ), self )
	ListenToGameEvent("dota_player_learned_ability", 	Dynamic_Wrap(CMegaDotaGameMode, "OnPlayerLearnedAbility" ),  self)

	self.m_CurrentGoldScaleFactor = GOLD_SCALE_FACTOR_INITIAL
	self.m_CurrentXpScaleFactor = XP_SCALE_FACTOR_INITIAL
	GameRules:GetGameModeEntity():SetThink( "OnThink", self, 5 )

	ListenToGameEvent("dota_player_used_ability", function(event)
		local hero = PlayerResource:GetSelectedHeroEntity(event.PlayerID)
		if not hero then return end
		if event.abilityname == "night_stalker_darkness" then
			local ability = hero:FindAbilityByName(event.abilityname)
			CustomGameEventManager:Send_ServerToAllClients("time_nightstalker_darkness", {
				duration = ability:GetSpecialValueFor("duration")
			})
		end
		if event.abilityname == "item_blink" then
			local oldpos = hero:GetAbsOrigin()
			Timers:CreateTimer( 0.01, function()
				local pos = hero:GetAbsOrigin()

				if IsInBugZone(pos) then
					FindClearSpaceForUnit(hero, oldpos, false)
				end
			end)
		end
	end, nil)

	_G.raxBonuses = {}
	_G.raxBonuses[DOTA_TEAM_GOODGUYS] = 0
	_G.raxBonuses[DOTA_TEAM_BADGUYS] = 0

	Timers:CreateTimer( 0.6, function()
		for i = 0, GameRules:NumDroppedItems() - 1 do
			local container = GameRules:GetDroppedItem( i )

			if container then
				local item = container:GetContainedItem()

				if item and item.GetAbilityName and not item:IsNull() and  item:GetAbilityName():find( "item_ward_" ) then
					local owner = item:GetOwner()

					if owner and not owner:IsNull() then
						local team = owner:GetTeam()
						local fountain
						local multiplier

						if team == DOTA_TEAM_GOODGUYS then
							multiplier = -350
							fountain = Entities:FindByName( nil, "ent_dota_fountain_good" )
						elseif team == DOTA_TEAM_BADGUYS then
							multiplier = -650
							fountain = Entities:FindByName( nil, "ent_dota_fountain_bad" )
						end

						local fountain_pos = fountain:GetAbsOrigin()

						if ( fountain_pos - container:GetAbsOrigin() ):Length2D() > 1200 then
							local pos_item = fountain_pos:Normalized() * multiplier + RandomVector( RandomFloat( 0, 200 ) ) + fountain_pos
							pos_item.z = fountain_pos.z

							container:SetAbsOrigin( pos_item )
							CustomGameEventManager:Send_ServerToPlayer( owner:GetPlayerOwner(), "display_custom_error", { message = "#dropped_wards_return_error" } )
						end
					end
				end
			end
		end

		return 0.6
	end )

	GameOptions:Init()
	UniquePortraits:Init()
	Battlepass:Init()
	CustomChat:Init()
	GamePerks:Init()
	GiftCodes:Init()
	CustomPings:Init()
	Kicks:Init()
	NeutralItemsDrop:Init()
end

function IsInBugZone(pos)
	local sum = pos.x + pos.y
	return sum > 14150 or sum < -14350 or pos.x > 7750 or pos.x < -7750 or pos.y > 7500 or pos.y < -7300
end

function GetActivePlayerCountForTeam(team)
    local number = 0
    for x=0,DOTA_MAX_TEAM do
        local pID = PlayerResource:GetNthPlayerIDOnTeam(team,x)
        if PlayerResource:IsValidPlayerID(pID) and (PlayerResource:GetConnectionState(pID) == 1 or PlayerResource:GetConnectionState(pID) == 2) then
            number = number + 1
        end
    end
    return number
end

function GetActiveHumanPlayerCountForTeam(team)
    local number = 0
    for x=0,DOTA_MAX_TEAM do
        local pID = PlayerResource:GetNthPlayerIDOnTeam(team,x)
        if PlayerResource:IsValidPlayerID(pID) and not self:isPlayerBot(pID) and (PlayerResource:GetConnectionState(pID) == 1 or PlayerResource:GetConnectionState(pID) == 2) then
            number = number + 1
        end
    end
    return number
end

function otherTeam(team)
    if team == DOTA_TEAM_BADGUYS then
        return DOTA_TEAM_GOODGUYS
    elseif team == DOTA_TEAM_GOODGUYS then
        return DOTA_TEAM_BADGUYS
    end
    return -1
end

function UnitInSafeZone(unit , unitPosition)
	local teamNumber = unit:GetTeamNumber()
	local fountains = Entities:FindAllByClassname('ent_dota_fountain')
	local allyFountainPosition
	for i, focusFountain in pairs(fountains) do
		if focusFountain:GetTeamNumber() == teamNumber then
			allyFountainPosition = focusFountain:GetAbsOrigin()
		end
	end
	return ((allyFountainPosition - unitPosition):Length2D()) <= TROLL_FEED_DISTANCE_FROM_FOUNTAIN_TRIGGER
end

function GetHeroKD(unit)
	if unit and unit:IsRealHero() then
		return (unit:GetKills() + (unit:GetAssists() * TROLL_FEED_SYSTEM_ASSISTS_TO_KILL_MULTI) - unit:GetDeaths())
	end
	return 0
end

function ItWorstKD(unit) -- use minimun TROLL_FEED_RATIO_KD_TO_TRIGGER_MIN
	local unitTeam = unit:GetTeamNumber()
	local focusTableHeroes

	if unitTeam == DOTA_TEAM_GOODGUYS then
		focusTableHeroes = _G.tableRadiantHeroes
	elseif unitTeam == DOTA_TEAM_BADGUYS then
		focusTableHeroes = _G.tableDireHeroes
	end

	for i, focusHero in pairs(focusTableHeroes) do
		local unitKD = GetHeroKD(unit)
		if unitKD > TROLL_FEED_RATIO_KD_TO_TRIGGER_MIN then
			return false
		elseif GetHeroKD(focusHero) <= unitKD and unit ~= focusHero then
			return false
		end
	end
	return true
end
function CMegaDotaGameMode:SetTeamColors()
	local ggcolor = {
		{70,70,255},
		{0,255,255},
		{255,0,255},
		{255,255,0},
		{255,165,0},
		{0,255,0},
		{255,0,0},
		{75,0,130},
		{109,49,19},
		{255,20,147},
		{128,128,0},
		{255,255,255}
	}
	local bgcolor = {
		{255,135,195},
		{160,180,70},
		{100,220,250},
		{0,128,0},
		{165,105,0},
		{153,50,204},
		{0,128,128},
		{0,0,165},
		{128,0,0},
		{180,255,180},
		{255,127,80},
		{0,0,0}
	}
	local team_colors = {
		[DOTA_TEAM_GOODGUYS] = { 0 , ggcolor },
		[DOTA_TEAM_BADGUYS] = { 0 , bgcolor },
	}

	for player_id = 0, PlayerResource:GetPlayerCount()-1 do
		local team = PlayerResource:GetTeam(player_id)
		local counter = team_colors[team][1] + 1
		team_colors[team][1] = counter
		local color = team_colors[team][2][counter]

		if color then
			CustomPings:SetColor(player_id, color)
			PlayerResource:SetCustomPlayerColor(player_id, color[1], color[2], color[3])
		end
	end
end

function CMegaDotaGameMode:OnHeroPicked(event)
	local hero = EntIndexToHScript(event.heroindex)
	if not hero then return end

	if hero:GetTeamNumber() == DOTA_TEAM_GOODGUYS then
		table.insert(_G.tableRadiantHeroes, hero)
	end

	if hero:GetTeamNumber() == DOTA_TEAM_BADGUYS then
		table.insert(_G.tableDireHeroes, hero)
	end

	-- Hopefully we never need this ever again
	--[[
	local player_id = hero:GetPlayerOwnerID()
	if not IsInToolsMode() and player_id and _G.tUserIds[player_id] and not self.disconnected_players[player_id] then
		SendToServerConsole('kickid '.. _G.tUserIds[player_id]);
	end
	]]
end
---------------------------------------------------------------------------
-- Filter: DamageFilter
---------------------------------------------------------------------------
function CMegaDotaGameMode:DamageFilter(event)
	local entindex_victim_const = event.entindex_victim_const
	local entindex_attacker_const = event.entindex_attacker_const
	local entindex_inflictor_const = event.entindex_inflictor_const
	local target
	local attacker
	local ability

	if (entindex_victim_const) then target = EntIndexToHScript(entindex_victim_const) end
	if (entindex_attacker_const) then attacker = EntIndexToHScript(entindex_attacker_const) end
	if (entindex_inflictor_const) then ability = EntIndexToHScript(entindex_inflictor_const) end

	if event.damage and target and not target:IsNull() and target:IsAlive() and attacker and not attacker:IsNull() and attacker:IsAlive() and attacker.GetPlayerOwnerID and attacker:GetPlayerOwnerID() then
		local attacker_id = attacker:GetPlayerOwnerID()
		if attacker_id >= 0 then
			if target.IsRealHero and target:IsRealHero() then
				CUSTOM_GAME_STATS[attacker_id].hero_damage = CUSTOM_GAME_STATS[attacker_id].hero_damage + event.damage
			elseif target.IsBuilding and target:IsBuilding() then
				CUSTOM_GAME_STATS[attacker_id].building_damage = CUSTOM_GAME_STATS[attacker_id].building_damage + event.damage
			end
		end
	end

	if target and target:HasModifier("modifier_troll_debuff_stop_feed") and (target:GetHealth() <= event.damage) and (attacker ~= target) and (attacker:GetTeamNumber()~=DOTA_TEAM_NEUTRALS) then
		if ItWorstKD(target) and (not (UnitInSafeZone(target, _G.lastHerosPlaceLastDeath[target]))) then
			local newTime = target:FindModifierByName("modifier_troll_debuff_stop_feed"):GetRemainingTime() + TROLL_FEED_INCREASE_BUFF_AFTER_DEATH
			--target:RemoveModifierByName("modifier_troll_debuff_stop_feed")
			local normalRespawnTime =  target:GetRespawnTime()
			local addRespawnTime = normalRespawnTime * (TROLL_FEED_TOTAL_RESPAWN_TIME_MULTIPLE - 1)

			if addRespawnTime + normalRespawnTime < TROLL_FEED_MIN_RESPAWN_TIME then
				addRespawnTime = TROLL_FEED_MIN_RESPAWN_TIME - normalRespawnTime
			end
			target:AddNewModifier(target, nil, "modifier_troll_debuff_stop_feed", { duration = newTime, addRespawnTime = addRespawnTime })
		end
		target:Kill(nil, target)
	end

	if target and target.delay_damage_by_perk and target.delay_damage_by_perk_duration and event.damage > 10 then
		local delayed_damage = event.damage * (target.delay_damage_by_perk / 100)
		local black_list_for_delay = {
			["delayed_damage_perk"] = true,
			["skeleton_king_reincarnation"] = true,
		}
		if (not ability or not black_list_for_delay[ability:GetName()]) and (not event.damagetype_const or event.damagetype_const > 0) then
			event.damage = event.damage - delayed_damage
			target:AddNewModifier(target, nil, "modifier_delayed_damage", {
				duration = target.delay_damage_by_perk_duration,
				attacker_ent = entindex_attacker_const,
				damage_type = event.damagetype_const,
				damage = delayed_damage
			})
		end
	end

	return true
end

---------------------------------------------------------------------------
-- Event: OnEntityKilled
---------------------------------------------------------------------------
function CMegaDotaGameMode:OnEntityKilled( event )
	local entindex_killed = event.entindex_killed
    local entindex_attacker = event.entindex_attacker
	local killedUnit
    local killer
	local name

	if (entindex_killed) then
		killedUnit = EntIndexToHScript(entindex_killed)
		name = killedUnit:GetUnitName()
	end
	if (entindex_attacker) then killer = EntIndexToHScript(entindex_attacker) end

	local raxRespawnTimeWorth = {
		npc_dota_goodguys_range_rax_top = 2,
		npc_dota_goodguys_melee_rax_top = 4,
		npc_dota_goodguys_range_rax_mid = 2,
		npc_dota_goodguys_melee_rax_mid = 4,
		npc_dota_goodguys_range_rax_bot = 2,
		npc_dota_goodguys_melee_rax_bot = 4,
		npc_dota_badguys_range_rax_top = 2,
		npc_dota_badguys_melee_rax_top = 4,
		npc_dota_badguys_range_rax_mid = 2,
		npc_dota_badguys_melee_rax_mid = 4,
		npc_dota_badguys_range_rax_bot = 2,
		npc_dota_badguys_melee_rax_bot = 4,
	}
	if raxRespawnTimeWorth[name] ~= nil then
		local team = killedUnit:GetTeam()
		raxBonuses[team] = raxBonuses[team] + raxRespawnTimeWorth[name]
		SendOverheadEventMessage( nil, OVERHEAD_ALERT_MANA_ADD, killedUnit, raxRespawnTimeWorth[name], nil )
		GameRules:SendCustomMessage("#destroyed_" .. string.sub(name,10,#name - 4),-1,0)
		if raxBonuses[team] == 18 then
			raxBonuses[team] = 22
			if team == DOTA_TEAM_BADGUYS then
				GameRules:SendCustomMessage("#destroyed_badguys_all_rax",-1,0)
			else
				GameRules:SendCustomMessage("#destroyed_goodguys_all_rax",-1,0)
			end
		end
	end
	if killedUnit:IsClone() then killedUnit = killedUnit:GetCloneSource() end
	--print("fired")
    if killer and killedUnit and killedUnit:IsRealHero() and not killedUnit:IsReincarnating() then
		local player_id = -1
		if killer:IsRealHero() and killer.GetPlayerID then
			player_id = killer:GetPlayerID()
		else
			if killer:GetPlayerOwnerID() ~= -1 then
				player_id = killer:GetPlayerOwnerID()
			end
		end
		if player_id ~= -1 then
			local kh = CUSTOM_GAME_STATS[player_id].killed_heroes

			kh[name] = kh[name] and kh[name] + 1 or 1
		end


	    local dotaTime = GameRules:GetDOTATime(false, false)
	    --local timeToStartReduction = 0 -- 20 minutes
	    local respawnReduction = 0.65 -- Original Reduction rate

	    -- Reducation Rate slowly increases after a certain time, eventually getting to original levels, this is to prevent games lasting too long
	    --if dotaTime > timeToStartReduction then
	    --	dotaTime = dotaTime - timeToStartReduction
	    --	respawnReduction = respawnReduction + ((dotaTime / 60) / 100) -- 0.75 + Minutes of Game Time / 100 e.g. 25 minutes fo game time = 0.25
	    --end

	    --if respawnReduction > 1 then
	    --	respawnReduction = 1
	    --end

	    local timeLeft = killedUnit:GetRespawnTime()
	 	timeLeft = timeLeft * respawnReduction -- Respawn time reduced by a rate

	    -- Disadvantaged teams get 5 seconds less respawn time for every missing player
	    local herosTeam = GetActivePlayerCountForTeam(killedUnit:GetTeamNumber())
	    local opposingTeam = GetActivePlayerCountForTeam(otherTeam(killedUnit:GetTeamNumber()))
	    local difference = herosTeam - opposingTeam

	    local addedTime = 0
	    if difference < 0 then
	        addedTime = difference * 5
	        local RespawnReductionRate = string.format("%.2f", tostring(respawnReduction))
		    local OriginalRespawnTime = tostring(math.floor(timeLeft))
		    local TimeToReduce = tostring(math.floor(addedTime))
		    local NewRespawnTime = tostring(math.floor(timeLeft + addedTime))
	        --GameRules:SendCustomMessage( "ReductionRate:"  .. " " .. RespawnReductionRate .. " " .. "OriginalTime:" .. " " ..OriginalRespawnTime .. " " .. "TimeToReduce:" .. " " ..TimeToReduce .. " " .. "NewRespawnTime:" .. " " .. NewRespawnTime, 0, 0)
	    end

	    timeLeft = timeLeft + addedTime
	    --print(timeLeft)

	    local rax_bonus = raxBonuses[killedUnit:GetTeam()] - raxBonuses[killedUnit:GetOpposingTeamNumber()]
	    if rax_bonus < 0 then rax_bonus = 0 end

		timeLeft = timeLeft + rax_bonus

	    if timeLeft < 1 then
	        timeLeft = 1
	    end

		if killedUnit and (not killedUnit:HasModifier("modifier_troll_debuff_stop_feed")) and (not ItWorstKD(killedUnit)) then
			killedUnit:SetTimeUntilRespawn(timeLeft)
		end
    end

	if killedUnit and killedUnit:IsRealHero() and (PlayerResource:GetSelectedHeroEntity(killedUnit:GetPlayerID())) then
		_G.lastHeroKillers[killedUnit] = killer
		_G.lastHerosPlaceLastDeath[killedUnit] = killedUnit:GetOrigin()
		if (killer ~= killedUnit) then
			_G.lastDeathTimes[killedUnit] = GameRules:GetGameTime()
		end
	end

end

LinkLuaModifier("modifier_rax_bonus", LUA_MODIFIER_MOTION_NONE)


function CMegaDotaGameMode:OnNPCSpawned(event)
	local spawnedUnit = EntIndexToHScript(event.entindex)
	local tokenTrollCouter = "modifier_troll_feed_token_couter"

	-- Apply bonus gold
	if not GameOptions:OptionsIsActive("no_winrate_gold_bonus") then
		if CMegaDotaGameMode.winrates and spawnedUnit and not spawnedUnit:IsNull() and spawnedUnit:IsRealHero()
		and not spawnedUnit.bonusGoldApplied and CMegaDotaGameMode.winrates[spawnedUnit:GetUnitName()] then
			local player_id = spawnedUnit:GetPlayerOwnerID()
			local player_stats = CustomNetTables:GetTableValue("game_state", "player_stats")
			local b_no_bonus
			if player_stats and player_stats[tostring(player_id)] and player_stats[tostring(player_id)].lastWinnerHeroes then
				b_no_bonus = table.contains(player_stats[tostring(player_id)].lastWinnerHeroes, spawnedUnit:GetUnitName())
			end
			if not bonusGoldApplied[player_id] and not b_no_bonus then
				local winrate = math.min(CMegaDotaGameMode.winrates[spawnedUnit:GetUnitName()]  * 100, 49.99)
				-- if you change formula here, change it in hero_selection_overlay.js too
				local gold = math.floor((-100 * winrate + 5100) / 5) * 5

				spawnedUnit:AddNewModifier(spawnedUnit, nil, "modifier_gold_bonus", { duration = 300, gold = gold})
				bonusGoldApplied[spawnedUnit:GetPlayerOwnerID()] = true
			end
		end
	end

	Timers:CreateTimer(0.1, function()
		if spawnedUnit and not spawnedUnit:IsNull() and ((spawnedUnit.IsTempestDouble and spawnedUnit:IsTempestDouble()) or (spawnedUnit.IsClone and spawnedUnit:IsClone())) then
			local playerId = spawnedUnit:GetPlayerOwnerID()
			if GamePerks.choosed_perks[playerId] then
				local perkName = GamePerks.choosed_perks[playerId]
				spawnedUnit:AddNewModifier(spawnedUnit, nil, perkName, {duration = -1})
				local mainHero = PlayerResource:GetSelectedHeroEntity(playerId)
				local perkStacks = mainHero:GetModifierStackCount(perkName, mainHero)
				spawnedUnit:SetModifierStackCount(perkName, nil, perkStacks)
			end
		end
	end)

	if spawnedUnit and spawnedUnit.reduceCooldownAfterRespawn
	and _G.lastHeroKillers[spawnedUnit] and not _G.lastHeroKillers[spawnedUnit]:IsNull() then
		local killersTeam = _G.lastHeroKillers[spawnedUnit]:GetTeamNumber()
		if killersTeam ~=spawnedUnit:GetTeamNumber() and killersTeam~= DOTA_TEAM_NEUTRALS then
			for i = 0, 20 do
				local item = spawnedUnit:GetItemInSlot(i)
				if item then
					local cooldown_remaining = item:GetCooldownTimeRemaining()
					if cooldown_remaining > 0 then
						item:EndCooldown()
						item:StartCooldown(cooldown_remaining-(cooldown_remaining/100*spawnedUnit.reduceCooldownAfterRespawn))
					end
				end
			end
			for i = 0, 30 do
				local ability = spawnedUnit:GetAbilityByIndex(i)
				if ability then
					local cooldown_remaining = ability:GetCooldownTimeRemaining()
					if cooldown_remaining > 0 then
						ability:EndCooldown()
						ability:StartCooldown(cooldown_remaining-(cooldown_remaining/100*spawnedUnit.reduceCooldownAfterRespawn))
					end
				end
			end
		end
		spawnedUnit.reduceCooldownAfterRespawn = false
	end
	-- Assignment of tokens during quick death, maximum 3
	if spawnedUnit and (_G.lastDeathTimes[spawnedUnit] ~= nil) and (spawnedUnit:GetDeaths() > 1)
	and ((GameRules:GetGameTime() - _G.lastDeathTimes[spawnedUnit]) < TROLL_FEED_TOKEN_TIME_DIES_WITHIN)
	and not spawnedUnit:HasModifier("modifier_troll_debuff_stop_feed") and (_G.lastHeroKillers[spawnedUnit]~=spawnedUnit)
	and (not (UnitInSafeZone(spawnedUnit, _G.lastHerosPlaceLastDeath[spawnedUnit]))) and (_G.lastHeroKillers[spawnedUnit]
	and not _G.lastHeroKillers[spawnedUnit]:IsNull() and _G.lastHeroKillers[spawnedUnit]:GetTeamNumber()~=DOTA_TEAM_NEUTRALS) then
		local maxToken = TROLL_FEED_NEED_TOKEN_TO_BUFF
		local currentStackTokenCouter = spawnedUnit:GetModifierStackCount(tokenTrollCouter, spawnedUnit)
		local needToken = currentStackTokenCouter + 1
		if needToken > maxToken then
			needToken = maxToken
		end
		spawnedUnit:AddNewModifier(spawnedUnit, nil, tokenTrollCouter, { duration = TROLL_FEED_TOKEN_DURATION })
		spawnedUnit:AddNewModifier(spawnedUnit, nil, "modifier_troll_feed_token", { duration = TROLL_FEED_TOKEN_DURATION })
		spawnedUnit:SetModifierStackCount(tokenTrollCouter, spawnedUnit, needToken)
	end

	-- Issuing a debuff if 3 quick deaths have accumulated and the hero has the worst KD in the team
	if spawnedUnit:GetModifierStackCount(tokenTrollCouter, spawnedUnit) == 3 and ItWorstKD(spawnedUnit) then
		spawnedUnit:RemoveModifierByName(tokenTrollCouter)
		local normalRespawnTime = spawnedUnit:GetRespawnTime()
		local addRespawnTime = normalRespawnTime * (TROLL_FEED_TOTAL_RESPAWN_TIME_MULTIPLE - 1)
		if addRespawnTime + normalRespawnTime < TROLL_FEED_MIN_RESPAWN_TIME then
			addRespawnTime = TROLL_FEED_MIN_RESPAWN_TIME - normalRespawnTime
		end
		GameRules:SendCustomMessage("#anti_feed_system_add_debuff_message", spawnedUnit:GetPlayerID(), 0)
		spawnedUnit:AddNewModifier(spawnedUnit, nil, "modifier_troll_debuff_stop_feed", { duration = TROLL_FEED_BUFF_BASIC_TIME, addRespawnTime = addRespawnTime })
	end

	local owner = spawnedUnit:GetOwner()
	local name = spawnedUnit:GetUnitName()

	if owner and owner.GetPlayerID and ( name == "npc_dota_sentry_wards" or name == "npc_dota_observer_wards" ) then
		local player_id = owner:GetPlayerID()

		CUSTOM_GAME_STATS[player_id].wards[name] = CUSTOM_GAME_STATS[player_id].wards[name] + 1

		Timers:CreateTimer(0.04, function()
			ReloadTimerHoldingCheckerForPlayer(player_id)
			return nil
		end)


		-- Allow placing sentry wards in your own camps but automatically destroy them just before the end of the minute mark.
		Timers:NextTick(function()
			if not IsValidEntity(spawnedUnit) or not spawnedUnit:IsAlive() then return end

			local list = Entities:FindAllByClassname("trigger_multiple")
			local find_name = "neutralcamp_good"
			if owner:GetTeam() == DOTA_TEAM_BADGUYS then
				find_name = "neutralcamp_evil"
			end

			for _, trigger in pairs(list) do
				if trigger:GetName():find(find_name) ~= nil then
					if IsInTriggerBox(trigger, 12, spawnedUnit:GetAbsOrigin()) then
						local time = GameRules:GetDOTATime(false,false)
						local duration = 59.5 - (time % 60)

						local observer_modifier = spawnedUnit:FindModifierByName("modifier_item_buff_ward")
						if observer_modifier then
							observer_modifier:SetDuration(duration, true)
						end

						local observer_modifier = spawnedUnit:FindModifierByName("modifier_item_ward_true_sight")
						if observer_modifier then
							observer_modifier:SetDuration(duration, true)
						end

						break
					end
				end
			end
		end)
	end

	if spawnedUnit:IsRealHero() then
		spawnedUnit:AddNewModifier(spawnedUnit, nil, "modifier_rax_bonus", {})
		local playerId = spawnedUnit:GetPlayerID()

		Timers:CreateTimer(1, function()
			UniquePortraits:UpdatePortraitsDataFromPlayer(playerId)
		end)

		if not spawnedUnit.firstTimeSpawned then
			spawnedUnit.firstTimeSpawned = true
		end

		Timers:CreateTimer(0, function()
			CreateDummyInventoryForPlayer(playerId)
		end)

		local player = PlayerResource:GetPlayer(playerId)
		if player and not player.checked_courier_secret_shop then
			CheckSuppCourier(spawnedUnit:GetPlayerOwnerID())
		end
	end
end

function CheckSuppCourier(player_id)
	local connect_state = PlayerResource:GetConnectionState(player_id)
	if connect_state == DOTA_CONNECTION_STATE_ABANDONED then return end

	if connect_state ~= DOTA_CONNECTION_STATE_CONNECTED then
		Timers:CreateTimer(1, function() CheckSuppCourier(player_id) end)
		return
	end
	Timers:CreateTimer(2, function()
		local courier = PlayerResource:GetPreferredCourierForPlayer(player_id)
		if courier and not courier:IsNull() then
			if Supporters:GetLevel(player_id) > 0 then
				courier:AddNewModifier(courier, nil, "creep_secret_shop", { duration = -1 })
				PlayerResource:GetPlayer(player_id).checked_courier_secret_shop = true
			end
		else
			Timers:CreateTimer(1, function() CheckSuppCourier(player_id) end)
		end
	end)
end

function CMegaDotaGameMode:CreateCourierForPlayer(pos, player_id)
	local player = PlayerResource:GetPlayer(player_id)
	if player then
		local c_state = PlayerResource:GetConnectionState(player_id)
		if c_state == DOTA_CONNECTION_STATE_CONNECTED or c_state == DOTA_CONNECTION_STATE_NOT_YET_CONNECTED then
			local courier = player:SpawnCourierAtPosition(pos + RandomVector(RandomFloat(10,25)))
			self.spawned_couriers[player_id] = courier
			for i = 0, 23 do
				courier:SetControllableByPlayer(i, false)
			end
			courier:SetControllableByPlayer(player_id, true)
		elseif not c_state == DOTA_CONNECTION_STATE_ABANDONED then
			Timers:CreateTimer(0.1, function()
				CMegaDotaGameMode:CreateCourierForPlayer(pos, player_id)
			end)
		end
	else
		Timers:CreateTimer(0.1, function()
			CMegaDotaGameMode:CreateCourierForPlayer(pos, player_id)
		end)
	end
end

function CMegaDotaGameMode:ModifierGainedFilter(filterTable)

	local disableHelpResult = DisableHelp.ModifierGainedFilter(filterTable)
	if disableHelpResult == false then
		return false
	end

	local parent = filterTable.entindex_parent_const and filterTable.entindex_parent_const ~= 0 and EntIndexToHScript(filterTable.entindex_parent_const)

	if parent and filterTable.name_const and filterTable.name_const == "modifier_item_shadow_amulet_fade" then
		filterTable.duration = 15
		parent:AddNewModifier(parent, nil, "modifier_shadow_amulet_thinker", {})
	end

	if parent.isDummy then
		return false
	end

	--[[ BUFF AMPLIFY LOGIC PART ]]--

	local caster = filterTable.entindex_caster_const and filterTable.entindex_caster_const ~= 0 and EntIndexToHScript(filterTable.entindex_caster_const)
	if not caster or not parent then return end

	local ability = filterTable.entindex_ability_const and filterTable.entindex_ability_const ~= 0 and EntIndexToHScript(filterTable.entindex_ability_const)
	local m_name = filterTable.name_const

	local is_amplified_perk = amplified_modifier[m_name] or counter_updaters[m_name] or self_updaters[m_name]
	if ability then
		is_amplified_perk = is_amplified_perk and (not common_buffs_not_amplify_by_skills[m_name] or not common_buffs_not_amplify_by_skills[m_name][ability:GetAbilityName()])
	end

	local is_correct_source = (parent:GetTeam() == caster:GetTeam()) or enemies_buff[m_name]
	local is_correct_duration = filterTable.duration and filterTable.duration > 0
	local amplify_source = buffs_from_parent[m_name] and parent or caster

	if amplify_source and amplify_source.buff_amplify and is_amplified_perk and is_correct_source and is_correct_duration then
		local new_duration = filterTable.duration * amplify_source.buff_amplify

		if counter_updaters[m_name] then
			Timers:CreateTimer(0, function()
				local parent_modifier = parent:FindModifierByName(counter_updaters[m_name])
				if parent_modifier then
					parent_modifier:SetDuration(new_duration, true)
				end
			end)
		end
		if self_updaters[m_name] then
			Timers:CreateTimer(0, function()
				local modifier = parent:FindModifierByName(m_name)
				if not modifier then return nil end
				local time = modifier:GetRemainingTime() + modifier:GetElapsedTime()
				if (time + 0.05) < new_duration then
					modifier:SetDuration(new_duration, true)
				end
				return 0.1
			end)
		end

		filterTable.duration = new_duration
	end

	--[[ Elder Titan's Spell Immunity from Astral Spirit ]]--
	if m_name == "modifier_elder_titan_echo_stomp_magic_immune" then
		local duration_ratio = ability:GetSpecialValueFor("scepter_magic_immune_per_hero_new_value") / ability:GetSpecialValueFor("scepter_magic_immune_per_hero")
		filterTable.duration = filterTable.duration * duration_ratio
	end

	return true
end

function CMegaDotaGameMode:OnThink()
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then

		-- update the scale factor:
	 	-- * SCALE_FACTOR_INITIAL at the start of the game
		-- * SCALE_FACTOR_FINAL after SCALE_FACTOR_FADEIN_SECONDS have elapsed
		local curTime = GameRules:GetDOTATime( false, false )
		local goldFracTime = math.min( math.max( curTime / GOLD_SCALE_FACTOR_FADEIN_SECONDS, 0 ), 1 )
		local xpFracTime = math.min( math.max( curTime / XP_SCALE_FACTOR_FADEIN_SECONDS, 0 ), 1 )
		self.m_CurrentGoldScaleFactor = GOLD_SCALE_FACTOR_INITIAL + (goldFracTime * ( GOLD_SCALE_FACTOR_FINAL - GOLD_SCALE_FACTOR_INITIAL ) )
		self.m_CurrentXpScaleFactor = XP_SCALE_FACTOR_INITIAL + (xpFracTime * ( XP_SCALE_FACTOR_FINAL - XP_SCALE_FACTOR_INITIAL ) )
--		print( "Gold scale = " .. self.m_CurrentGoldScaleFactor )
--		print( "XP scale = " .. self.m_CurrentXpScaleFactor )

		for i = 0, 23 do
			if PlayerResource:IsValidPlayer( i ) then
				local hero = PlayerResource:GetSelectedHeroEntity( i )
				if hero and hero:IsAlive() then
					local pos = hero:GetAbsOrigin()

					if IsInBugZone(pos) then
						-- hero:ForceKill(false)
						-- Kill this unit immediately.

						local naprv = Vector(pos[1]/math.sqrt(pos[1]*pos[1]+pos[2]*pos[2]+pos[3]*pos[3]),pos[2]/math.sqrt(pos[1]*pos[1]+pos[2]*pos[2]+pos[3]*pos[3]),0)
						pos[3] = 0
						FindClearSpaceForUnit(hero, pos-naprv*1100, false)
					end
				end
			end
		end

		for player_id, last_order_time in pairs(self.last_player_orders) do
			if GameRules:GetGameTime() - last_order_time > 120 and PlayerResource:GetConnectionState(player_id) == DOTA_CONNECTION_STATE_CONNECTED then
				self.last_player_orders[player_id] = 9999999
				local hero = PlayerResource:GetSelectedHeroEntity(player_id)
				if hero then
					local team = hero:GetTeam()

					local fountain
					local multiplier

					if team == DOTA_TEAM_GOODGUYS then
						multiplier = -350
						fountain = Entities:FindByName( nil, "ent_dota_fountain_good" )
					elseif team == DOTA_TEAM_BADGUYS then
						multiplier = -650
						fountain = Entities:FindByName( nil, "ent_dota_fountain_bad" )
					end

					local fountain_pos = fountain:GetAbsOrigin()
					local move_pos = fountain_pos:Normalized() * multiplier + RandomVector( RandomFloat( 0, 200 ) ) + fountain_pos

					ExecuteOrderFromTable({
						UnitIndex = hero:entindex(),
						OrderType = DOTA_UNIT_ORDER_MOVE_TO_POSITION,
						Position = move_pos
					})
				end
			end
		end
	end
	return 5
end


function CMegaDotaGameMode:FilterBountyRunePickup( filterTable )
--	print( "FilterBountyRunePickup" )
--  for k, v in pairs( filterTable ) do
--  	print("MG: " .. k .. " " .. tostring(v) )
--  end
	filterTable["gold_bounty"] = self.m_CurrentGoldScaleFactor * filterTable["gold_bounty"]
	filterTable["xp_bounty"] = self.m_CurrentXpScaleFactor * filterTable["xp_bounty"]
	return true
end

function CMegaDotaGameMode:FilterModifyGold( filterTable )
--	print( "FilterModifyGold" )
--	print( self.m_CurrentGoldScaleFactor )
	filterTable["gold"] = self.m_CurrentGoldScaleFactor * filterTable["gold"]
	if PlayerResource:GetTeam(filterTable.player_id_const) == ShuffleTeam.weak_team_id then
		filterTable["gold"] = ShuffleTeam.gold_multiplier * filterTable["gold"]
	end
	return true
end

function CMegaDotaGameMode:FilterModifyExperience( filterTable )
	local hero = EntIndexToHScript(filterTable.hero_entindex_const)

	if hero and hero.IsTempestDouble and hero:IsTempestDouble() then
		return false
	end

	local new_exp = self.m_CurrentXpScaleFactor * filterTable["experience"]

	if hero and hero.GetPlayerOwnerID and hero:GetPlayerOwnerID() then
		local player_id = hero:GetPlayerOwnerID()
		CUSTOM_GAME_STATS[player_id].experiance = CUSTOM_GAME_STATS[player_id].experiance + new_exp
	end

	filterTable["experience"] = new_exp
	return true
end

function CMegaDotaGameMode:OnMatchDone(keys)
	local couriers = FindUnitsInRadius(DOTA_TEAM_GOODGUYS, Vector( 0, 0, 0 ), nil, FIND_UNITS_EVERYWHERE, DOTA_UNIT_TARGET_TEAM_BOTH, DOTA_UNIT_TARGET_COURIER, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false )

	for i = 0, 23 do
		if PlayerResource:IsValidPlayerID( i ) then
			local stats = CUSTOM_GAME_STATS[i]
			stats.perk = GamePerks.choosed_perks[i]
			stats.networth = PlayerResource:GetNetWorth(i)
			stats.total_healing = PlayerResource:GetHealing(i)
			stats.xpm = stats.experiance / GameRules:GetGameTime() * 60

			CustomNetTables:SetTableValue( "custom_stats", tostring( i ), stats )
		end
	end

	if keys.winningteam then
		WebApi:AfterMatch(keys.winningteam)
	end
end

function CMegaDotaGameMode:OnGameRulesStateChange(keys)
	local newState = GameRules:State_Get()

	if newState ==  DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
		-- AutoTeam:Init() what does this do? nobody knows... ¯\_(ツ)_/¯
		ShuffleTeam:ShuffleTeams()
	end

	if newState ==  DOTA_GAMERULES_STATE_HERO_SELECTION then
		-- AutoTeam:EnableFreePatreonForBalance()
		GameOptions:RecordVotingResults()
	end

	if newState == DOTA_GAMERULES_STATE_STRATEGY_TIME then
		self:SetTeamColors()
		for i=0, DOTA_MAX_TEAM_PLAYERS do
			if PlayerResource:IsValidPlayer(i) then
				if PlayerResource:HasSelectedHero(i) == false then
					local player = PlayerResource:GetPlayer(i)
					player:MakeRandomHeroSelection()
				end
			end
		end
	end

	if newState == DOTA_GAMERULES_STATE_PRE_GAME then
		InitWardsChecker()
		if not GameOptions:OptionsIsActive("super_towers") then
			AddModifierAllByClassname("npc_dota_tower", "modifier_super_tower")
		end
		AddModifierAllByClassname("npc_dota_fort", "modifier_stronger_builds")
		AddModifierAllByClassname("npc_dota_barracks", "modifier_stronger_builds")

		local parties = {}
		local party_indicies = {}
		local party_members_count = {}
		local party_index = 1
		-- Set up player colors
		for id = 0, 23 do
			if PlayerResource:IsValidPlayer(id) then
				local party_id = tonumber(tostring(PlayerResource:GetPartyID(id)))
				if party_id and party_id > 0 then
					if not party_indicies[party_id] then
						party_indicies[party_id] = party_index
						party_index = party_index + 1
					end
					local party_index = party_indicies[party_id]
					parties[id] = party_index
					if not party_members_count[party_index] then
						party_members_count[party_index] = 0
					end
					party_members_count[party_index] = party_members_count[party_index] + 1
				end
			end
		end
		for id, party in pairs(parties) do
			 -- at least 2 ppl in party!
			if party_members_count[party] and party_members_count[party] < 2 then
				parties[id] = nil
			end
		end
		if parties then
			CustomNetTables:SetTableValue("game_state", "parties", parties)
		end
		Timers:CreateTimer(3, function()
			if not IsDedicatedServer() then
				CustomGameEventManager:Send_ServerToAllClients("is_local_server", {})
			end
			ShuffleTeam:GiveBonusToWeakTeam()
		end)
        local toAdd = {
            luna_moon_glaive_fountain = 4,
            ursa_fury_swipes_fountain = 5,
        }
		Timers:RemoveTimer("game_options_unpause")
		Convars:SetFloat("host_timescale", 1)
		Convars:SetFloat("host_timescale", IsInToolsMode() and 1 or 0.07)
		Timers:CreateTimer({
			useGameTime = false,
			endTime = 2.1,
			callback = function()
				Convars:SetFloat("host_timescale", 1)
				if not IsInToolsMode() then SendToServerConsole("dota_pause") end
				return nil
			end
		})

        local fountains = Entities:FindAllByClassname('ent_dota_fountain')
		-- Loop over all ents
        for k,fountain in pairs(fountains) do

			fountain:AddNewModifier(fountain, nil, "modifier_fountain_phasing", { duration = 90 })

            for skillName,skillLevel in pairs(toAdd) do
                fountain:AddAbility(skillName)
                local ab = fountain:FindAbilityByName(skillName)
                if ab then
                    ab:SetLevel(skillLevel)
                end
            end

            local item = CreateItem('item_monkey_king_bar_fountain', fountain, fountain)
            if item then
                fountain:AddItem(item)
            end

		end
		GamePerks:StartTrackPerks()
		local global_dummy = CreateUnitByName("npc_dummy_cosmetic_caster", Vector(-10000,-10000,-10000), true, nil, nil, DOTA_TEAM_NEUTRALS)
		global_dummy:AddNewModifier(global_dummy, nil, "modifier_global_dummy_custom", { duration = -1 })
	end

	-- Runs at game time 0:00
	if newState == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		-- Add tome of knowledge to 5 lowest XP players on each team
		local player_ids = {[2] = {}, [3] = {}}

		for player_id = 0, 23 do
			local team_id = PlayerResource:GetTeam(player_id)

			if team_id ~= 0 then
				table.insert(player_ids[team_id], player_id)
			end
		end

		Timers:CreateTimer(600, function()
			for team_id = 2, 3 do
				-- Sort table from lowest xp to highest, excluding abandoned players
				table.sort(player_ids[team_id], function(a, b)
					return PlayerResource:GetTotalEarnedXP(a) < PlayerResource:GetTotalEarnedXP(b)
				end)

				local count = 5

				for _, player_id in pairs(player_ids[team_id]) do
					-- Don't give tomes to abandoned players
					if not abandoned_players[player_id] then
						local hero = PlayerResource:GetSelectedHeroEntity(player_id)

						if hero and hero:GetLevel() < 30 then
							hero:AddItemByName("item_tome_of_knowledge_lua")

							count = count - 1
						end
					end

					if count <= 0 then break end
				end
			end

			return 600
		end)

		Convars:SetFloat("host_timescale", 1)
		if game_start then
			GameRules:SetTimeOfDay( 0.251 )
			game_start = false
			Timers:CreateTimer(0.1, function()
				GPM_Init()
				return nil
			end)
			Timers:CreateTimer(0, function()
				for player_id = 0, 24 do
					if not abandoned_players[player_id] and PlayerResource:GetConnectionState(player_id) == DOTA_CONNECTION_STATE_ABANDONED then
						abandoned_players[player_id] = true
						local team = PlayerResource:GetTeam(player_id)

						local fountain
						if team and (team == DOTA_TEAM_GOODGUYS) or (team == DOTA_TEAM_BADGUYS)then
							fountain = Entities:FindByName( nil, "ent_dota_fountain_" .. (team == DOTA_TEAM_GOODGUYS and "good" or "bad"))
						end

						local block_unit = function(unit)
							unit:Stop()
							unit:AddNewModifier(unit, nil, "modifier_abandoned", { duration = -1 })
							unit:AddNoDraw()
							if fountain then
								unit:SetAbsOrigin(fountain:GetAbsOrigin())
							end

							if unit.HasInventory and unit:HasInventory() then
								for item_slot = 0, 20 do
									local item = unit:GetItemInSlot(item_slot)
									if item and not item:IsNull() and item.GetAbilityName and item:GetAbilityName() then
										if item:IsNeutralDrop() then
											print("Add neutral to stash (10s fail-safe)")
											AddNeutralItemToStashWithEffects(unit:GetPlayerID(), unit:GetTeam(), item)
										elseif item:GetCost() then
											unit:SellItem(item)
										end
									end
								end
							end
						end

						Timers:CreateTimer(first_dc_players[player_id] and 60 or 0, function()
							if abandoned_players[player_id] then
								CallbackHeroAndCourier(player_id, block_unit)

								local gold_for_team = PlayerResource:GetGold(player_id)
								local connected_players_counter = 0
								for _player_id = 0, 24 do
									if _player_id ~= player_id and PlayerResource:GetConnectionState(_player_id) == DOTA_CONNECTION_STATE_CONNECTED then
										connected_players_counter = connected_players_counter + 1
									end
								end
								if connected_players_counter > 0 then
									gold_for_team = math.floor(gold_for_team / connected_players_counter)
									for _player_id = 0, 24 do
										if _player_id ~= player_id and PlayerResource:GetConnectionState(_player_id) == DOTA_CONNECTION_STATE_CONNECTED then
											local _hero = PlayerResource:GetSelectedHeroEntity(_player_id)
											if _hero and not _hero:IsNull() then
												_hero:ModifyGold(gold_for_team, false, 0)
											end
										end
									end
								end
							end
						end)
						if not first_dc_players[player_id] then
							first_dc_players[player_id] = true
						end
					end
				end
				return 10
			end)
		end
	end
end

function SearchAndCheckRapiers(buyer, unit, plyID, maxSlots, timerKey)
	local fullRapierCost = GetItemCost("item_rapier")
	for i = 0, maxSlots do
		local item = unit:GetItemInSlot(i)
		if item and item:GetAbilityName() == "item_rapier" and (item:GetPurchaser() == buyer) and ((item.defend == nil) or (item.defend == false)) then
			local playerNetWorse = PlayerResource:GetNetWorth(plyID)
			if playerNetWorse < NET_WORSE_FOR_RAPIER_MIN then
				CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(plyID), "display_custom_error", { message = "#rapier_small_networth" })
				UTIL_Remove(item)
				buyer:ModifyGold(fullRapierCost, false, 0)
				Timers:CreateTimer(0.03, function()
					Timers:RemoveTimer(timerKey)
				end)
			else
				if GetHeroKD(buyer) > 0 then
					Timers:CreateTimer(0.03, function()
						item.defend = true
						Timers:RemoveTimer(timerKey)
					end)
				elseif (GetHeroKD(buyer) <= 0) then
					CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(plyID), "display_custom_error", { message = "#rapier_littleKD" })
					UTIL_Remove(item)
					buyer:ModifyGold(fullRapierCost, false, 0)
					Timers:CreateTimer(0.03, function()
						Timers:RemoveTimer(timerKey)
					end)
				end
			end
		end
	end
end

function CMegaDotaGameMode:ItemAddedToInventoryFilter( filterTable )
	if filterTable["item_entindex_const"] == nil then
		return true
	end
 	if filterTable["inventory_parent_entindex_const"] == nil then
		return true
	end
	local hInventoryParent = EntIndexToHScript( filterTable["inventory_parent_entindex_const"] )
	local hItem = EntIndexToHScript( filterTable["item_entindex_const"] )
	if hItem ~= nil and hInventoryParent ~= nil then
		local itemName = hItem:GetName()

		if itemName == "item_banhammer" and GameOptions:OptionsIsActive("no_trolls_kick") then
			local playerId = hItem:GetPurchaser():GetPlayerID()
			if playerId then
				CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(playerId), "display_custom_error", { message = "#you_cannot_buy_it" })
			end
			UTIL_Remove(hItem)
			return false
		end
		local pitems = {
			"item_patreonbundle_1",
			"item_patreonbundle_2",
		}
		if hInventoryParent:IsRealHero() then
			local plyID = hInventoryParent:GetPlayerID()
			if not plyID then return true end

			local pitem = false
			for i=1,#pitems do
				if itemName == pitems[i] then
					pitem = true
					break
				end
			end
			if pitem == true then
				local supporter_level = Supporters:GetLevel(plyID)
				if supporter_level < 1 then
					CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(plyID), "display_custom_error", { message = "#nopatreonerror" })
					UTIL_Remove(hItem)
					return false
				end
			end

			if itemName == "item_banhammer" then
				if GameRules:GetDOTATime(false,false) < 300 then
					CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(plyID), "display_custom_error", { message = "#notyettime" })
					UTIL_Remove(hItem)
					return false
				end
			end
		else
			for i=1,#pitems do
				if itemName == pitems[i] then
					local prsh = hItem:GetPurchaser()
					if prsh ~= nil then
						if prsh:IsRealHero() then
							local prshID = prsh:GetPlayerID()

							if not prshID then
								UTIL_Remove(hItem)
								return false
							end
							local supporter_level = Supporters:GetLevel(prshID)
							if not supporter_level then
								UTIL_Remove(hItem)
								return false
							end
							if itemName == "item_banhammer" then
								if GameRules:GetDOTATime(false,false) < 300 then
									CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(prshID), "display_custom_error", { message = "#notyettime" })
									UTIL_Remove(hItem)
									return false
								end
							else
								if supporter_level < 1 then
									CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(prshID), "display_custom_error", { message = "#nopatreonerror" })
									UTIL_Remove(hItem)
									return false
								end
							end
						else
							UTIL_Remove(hItem)
							return false
						end
					else
						UTIL_Remove(hItem)
						return false
					end
				end
			end
		end

		if hItem:GetPurchaser() and (itemName == "item_relic") then
			local buyer = hItem:GetPurchaser()
			local plyID = buyer:GetPlayerID()
			local itemEntIndex = hItem:GetEntityIndex()
			local timerKey = "seacrh_rapier_on_player"..itemEntIndex
			Timers:CreateTimer(timerKey, {
				useGameTime = false,
				endTime = 0.4,
				callback = function()
					if hItem.transfer then
						SearchAndCheckRapiers(buyer, buyer, plyID, 20, timerKey)
						return 0.45
					end
				end
			})
		end


		local purchaser = hItem:GetPurchaser()
		local itemCost = hItem:GetCost()
		if purchaser then
			local prshID = purchaser:GetPlayerID()
			local supporter_level = Supporters:GetLevel(prshID)
			local correctInventory = hInventoryParent:IsRealHero() or (hInventoryParent:GetClassname() == "npc_dota_lone_druid_bear") or hInventoryParent:IsCourier()
			local in_shop_range = hInventoryParent:IsInRangeOfShop(DOTA_SHOP_HOME, true) or not hInventoryParent:IsAlive()

			if (filterTable["item_parent_entindex_const"] > 0) and correctInventory and (ItemIsFastBuying(hItem:GetName()) or supporter_level > 0) and not in_shop_range then
				local transfer_result = hItem:TransferToBuyer(hInventoryParent)
				if transfer_result ~= nil then
					hItem:SetCombineLocked(true)
					Timers:CreateTimer(0, function()
						if hItem and not hItem:IsNull() then
							hInventoryParent:TakeItem(hItem)
							hItem:SetCombineLocked(false)
						end
						if transfer_result == true then
							purchaser:AddItem(hItem)
						end
					end)
				end
				local unique_key_cd = itemName .. "_" .. purchaser:GetEntityIndex()
				if _G.lastTimeBuyItemWithCooldown[unique_key_cd] and (_G.itemsCooldownForPlayer[itemName] and (GameRules:GetGameTime() - _G.lastTimeBuyItemWithCooldown[unique_key_cd]) < _G.itemsCooldownForPlayer[itemName]) then
					local checkMaxCount = CheckMaxItemCount(hItem:GetAbilityName(), unique_key_cd, prshID, false)
					if checkMaxCount then
						MessageToPlayerItemCooldown(itemName, prshID)
					end
					Timers:CreateTimer(0.08, function()
						UTIL_Remove(hItem)
					end)
					return false
				end
			else
				hItem.transfer = true
			end

			if (filterTable["item_parent_entindex_const"] > 0) and hItem and correctInventory and (not purchaser:CheckPersonalCooldown(hItem)) then
				UTIL_Remove(hItem)
				return false
			end
		end
	end

	if _G.neutralItems[hItem:GetAbilityName()] and hItem.old == nil then
		hItem.old = true
		local inventoryIsCorrect = hInventoryParent:IsRealHero() or (hInventoryParent:GetClassname() == "npc_dota_lone_druid_bear") or hInventoryParent:IsCourier()
		if inventoryIsCorrect then
			local playerId = hInventoryParent:GetPlayerOwnerID() or hInventoryParent:GetPlayerID()
			local player = PlayerResource:GetPlayer(playerId)

			hItem.secret_key = RandomInt(1,999999)
			CustomGameEventManager:Send_ServerToPlayer( player, "neutral_item_picked_up", {
				item = filterTable.item_entindex_const,
				secret = hItem.secret_key,
			})

			local container = hItem:GetContainer()
			if container then
				container:RemoveSelf()
			end

			return false
		end
	end

	if hItem and hItem.neutralDropInBase then
		hItem.secret_key = nil
		hItem.neutralDropInBase = false
		local inventoryIsCorrect = hInventoryParent:IsRealHero() or (hInventoryParent:GetClassname() == "npc_dota_lone_druid_bear") or hInventoryParent:IsCourier()
		local playerId = inventoryIsCorrect and hInventoryParent:GetPlayerOwnerID()
		if playerId then
			NotificationToAllPlayerOnTeam({
				PlayerID = playerId,
				item = filterTable.item_entindex_const,
			})
		end
	end

	return true
end

function CMegaDotaGameMode:OnConnectFull(data)
	local player_id = data.PlayerID
	_G.tUserIds[player_id] = data.userid
	if Kicks:IsPlayerKicked(player_id) then
		Kicks:DropItemsForDisconnetedPlayer(player_id)
		SendToServerConsole('kickid '.. data.userid);
	end

	local hero = PlayerResource:GetSelectedHeroEntity(player_id)

	if abandoned_players[player_id] then
		local unblock_unit = function(unit)
			unit:RemoveModifierByName("modifier_abandoned")
			unit:RemoveNoDraw()
		end
		CallbackHeroAndCourier(player_id, unblock_unit)
		abandoned_players[player_id] = nil
	end

	if hero then
		hero:CheckManuallySpentAttributePoints()
	end

	CustomGameEventManager:Send_ServerToAllClients( "change_leave_status", {leave = false, playerId = player_id} )
end

function CMegaDotaGameMode:OnPlayerDisconnect(data)
	local player_id = data.PlayerID
	if not player_id then return end

	if not self.disconnected_players[player_id] then
		self.disconnected_players[player_id] = true
	end

	CustomGameEventManager:Send_ServerToAllClients( "change_leave_status", {leave = true, playerId = data.PlayerID} )
end

function GetBlockItemByID(id)
	for k,v in pairs(_G.ItemKVs) do
		if tonumber(v["ID"]) == id then
			v["name"] = k
			return v
		end
	end
end

function CMegaDotaGameMode:ExecuteOrderFilter(filterTable)
	local orderType = filterTable.order_type
	local playerId = filterTable.issuer_player_id_const
	local target = filterTable.entindex_target ~= 0 and EntIndexToHScript(filterTable.entindex_target) or nil
	local ability = filterTable.entindex_ability ~= 0 and EntIndexToHScript(filterTable.entindex_ability) or nil
	local orderVector = Vector(filterTable.position_x, filterTable.position_y, 0)
	-- `entindex_ability` is item id in some orders without entity
	if ability and not ability.GetAbilityName then ability = nil end
	local abilityName = ability and ability:GetAbilityName() or nil
	local unit
	-- TODO: Are there orders without a unit?
	if filterTable.units and filterTable.units["0"] then
		unit = EntIndexToHScript(filterTable.units["0"])
	end

	if playerId then
		self.last_player_orders[playerId] = GameRules:GetGameTime()
	end

	if IsValidEntity(unit) and IsValidEntity(ability) then
		local res = FountainProtection:OrderFilter(orderType, ability, target, unit, orderVector)
		if res then
			return false
		end
	end

	if not IsInToolsMode() and unit and unit.GetTeam and PlayerResource:GetPlayer(playerId) then
		if unit:GetTeam() ~= PlayerResource:GetPlayer(playerId):GetTeam() then
			return false
		end
		local is_not_owned_unit = false
		for _, _unit_ent in pairs (filterTable.units) do
			local _unit = EntIndexToHScript(_unit_ent)
			if _unit and IsValidEntity(_unit) and _unit.GetPlayerOwnerID then
				local unit_owner_id = _unit:GetPlayerOwnerID()
				if
					unit_owner_id and
					unit_owner_id ~= playerId and
					(
						(PlayerResource:GetConnectionState(unit_owner_id) == DOTA_CONNECTION_STATE_DISCONNECTED and GameRules:GetDOTATime(false,false) < 900)
						or
						PlayerResource:GetConnectionState(unit_owner_id) == DOTA_CONNECTION_STATE_ABANDONED
					)
				then
					is_not_owned_unit = true
				end
			end
		end
		if is_not_owned_unit then
			return false
		end
	end

	if orderType == DOTA_UNIT_ORDER_TAKE_ITEM_FROM_NEUTRAL_ITEM_STASH  then
		local main_hero = PlayerResource:GetSelectedHeroEntity(playerId)
		Timers:CreateTimer(0, function()
			if main_hero:GetItemInSlot(DOTA_ITEM_NEUTRAL_SLOT) == nil then
				main_hero:SwapItems(ability:GetItemSlot(), DOTA_ITEM_NEUTRAL_SLOT)
			end
		end)
	end

	if orderType == DOTA_UNIT_ORDER_CAST_TARGET then
		if target and target:GetName() == "npc_dota_seasonal_ti9_drums" then
			CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(playerId), "display_custom_error", { message = "#dota_hud_error_cant_cast_on_other" })
			return
		end
	end

	-- Check an aoe around orderVector
	local mk_trolling_abilities_target = {
		["item_quelling_blade"] = 100,
		["item_bfury"] = 100,
		["item_tango"] = 100,
		["item_tango_single"] = 100,
		["tiny_tree_grab"] = 100,
		["dark_seer_vacuum"] = 125,
		["dawnbreaker_solar_guardian"] = 300,
		["enigma_midnight_pulse"] = 750,
		["item_fallen_sky"] = 315,
		["wisp_relocate"] = 150,
		["keeper_of_the_light_will_o_wisp"] = 725,
		["leshrac_split_earth"] = 265 + 75 * 3,
		["lina_light_strike_array"] = 250,
		["mars_arena_of_blood"] = 825,
		["furion_force_of_nature"] = 375,
		["techies_suicide"] = 150,
		["undying_tombstone"] = 300,
		["vengefulspirit_nether_swap"] = 300,
		["warlock_rain_of_chaos"] = 600,
	}

	-- Check a radius around caster
	local mk_trolling_abilities_aoe = {
		["shredder_whirling_death"] = 325,
		["visage_gravekeepers_cloak"] = 350,
		["vengefulspirit_nether_swap"] = 300,
		["skeleton_king_vampiric_aura"] = 250,
	}

	-- Check a line between caster and orderVector
	-- {distance, width}
	local mk_trolling_abilities_line = {
		["shredder_timber_chain"] = {1340, 100},
		["shredder_chakram"] = {"past_target", 200},
		["shredder_chakram_2"] = {"past_target", 200},
		["dawnbreaker_fire_wreath"] = {150 + 120 + 215 * 1.1, 200},
		["earth_spirit_boulder_smash"] = {2000, 100},
		["earth_spirit_rolling_boulder"] = {1500, 100},
		["windrunner_powershot"] = {2600, 75},
		["dawnbreaker_celestial_hammer"] = {1300, 100},
		["earth_spirit_geomagnetic_grip"] = {1100, 100},
		["magnataur_skewer"] = {"past_target", 200},
		["storm_spirit_ball_lightning"] = {"past_target", 100},
	}

	if orderType == DOTA_UNIT_ORDER_CAST_POSITION or orderType == DOTA_UNIT_ORDER_CAST_TARGET_TREE and abilityName then
		if orderType == DOTA_UNIT_ORDER_CAST_TARGET_TREE then

			local treeID = filterTable.entindex_target
			local tree_index = GetEntityIndexForTreeId(treeID)
			local tree_handle = EntIndexToHScript(tree_index)
			orderVector = tree_handle:GetAbsOrigin()
		end

		if orderVector ~= Vector(0, 0, 0) then
			if mk_trolling_abilities_target[abilityName] then
				local aoe = mk_trolling_abilities_target[abilityName] + 32
				local allies = FindUnitsInRadius(unit:GetTeamNumber(), orderVector, nil, aoe, DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

				for _, ally in pairs(allies) do
					if ally ~= unit and ally:HasModifier("modifier_monkey_king_bounce_perch") then
						CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(playerId), "display_custom_error", { message = "#cannot_cast_on_tree_dance" })
						return false
					end
				end
			end

			if mk_trolling_abilities_line[abilityName] then
				local distance = mk_trolling_abilities_line[abilityName][1]
				local width = mk_trolling_abilities_line[abilityName][2] + 32

				-- For abilities which have to be targeted past the trees broken location, check up to the location it was targeted
				if distance == "past_target" then
					distance = (orderVector - unit:GetAbsOrigin()):Length2D() + mk_trolling_abilities_line[abilityName][2]
				end

				local end_pos = unit:GetAbsOrigin() + (orderVector - unit:GetAbsOrigin()):Normalized() * distance

				local allies = FindUnitsInLine(unit:GetTeamNumber(), unit:GetAbsOrigin(), end_pos, nil, width, DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_NONE)

				for _, ally in pairs(allies) do
					if ally ~= unit and ally:HasModifier("modifier_monkey_king_bounce_perch") then
						CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(playerId), "display_custom_error", { message = "#cannot_cast_on_tree_dance" })
						return false
					end
				end
			end
		end
	end

	if orderType == DOTA_UNIT_ORDER_CAST_NO_TARGET and abilityName then
		if mk_trolling_abilities_aoe[abilityName] then
			local aoe = mk_trolling_abilities_aoe[abilityName] + 32
			local allies = FindUnitsInRadius(unit:GetTeamNumber(), unit:GetAbsOrigin(), nil, aoe, DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

			for _, ally in pairs(allies) do
				if ally ~= unit and ally:HasModifier("modifier_monkey_king_bounce_perch") then
					CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(playerId), "display_custom_error", { message = "#cannot_cast_on_tree_dance" })
					return false
				end
			end
		end
	end

	local itemsToBeDestroy = {
		["item_disable_help_custom"] = true,
		["item_mute_custom"] = true,
		["item_reset_mmr"] = true,
		["item_banhammer"] = true,
	}
	if orderType == DOTA_UNIT_ORDER_PURCHASE_ITEM then
		local item_name = filterTable.shop_item_name or ""
		if WARDS_LIST[item_name] then
			if BlockedWardsFilter(playerId, "#you_cannot_buy_it") == false then return false end
		end

		if item_name == "item_gem" then
			local kills = PlayerResource:GetKills(playerId)
			local assists = PlayerResource:GetAssists(playerId)
			local deaths = PlayerResource:GetDeaths(playerId)

			if kills + assists > deaths then
				return true
			else
				CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(playerId), "display_custom_error", { message = "#you_cannot_buy_it" })
				return false
			end
		end

		local hero = PlayerResource:GetSelectedHeroEntity(playerId)
		if TROLL_FEED_FORBIDDEN_TO_BUY_ITEMS[item_name] and hero and hero:HasModifier("modifier_troll_debuff_stop_feed") then
			CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(playerId), "display_custom_error", { message = "#you_cannot_buy_it" })
			return false
		end
	end

	if orderType == DOTA_UNIT_ORDER_DROP_ITEM or orderType == DOTA_UNIT_ORDER_EJECT_ITEM_FROM_STASH then
		if ability and ability:GetAbilityName() == "item_relic" then
			CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(playerId), "display_custom_error", { message = "#cannotpullit" })
			return false
		end
	end

	if  orderType == DOTA_UNIT_ORDER_SELL_ITEM  then
		if ability and ability:GetAbilityName() == "item_relic" then
			Timers:RemoveTimer("seacrh_rapier_on_player"..filterTable.entindex_ability)
		end
	end

	if orderType == DOTA_UNIT_ORDER_GIVE_ITEM then
		if target:GetClassname() == "ent_dota_shop" and ability:GetAbilityName() == "item_relic" then
			Timers:RemoveTimer("seacrh_rapier_on_player"..ability:GetEntityIndex())
		end

		if _G.neutralItems[ability:GetAbilityName()] then
			local targetID = target:GetPlayerOwnerID()
			if targetID and targetID~=playerId then
				if CheckCountOfNeutralItemsForPlayer(targetID) >= _G.MAX_NEUTRAL_ITEMS_FOR_PLAYER then
					DisplayError(playerId, "#unit_still_have_a_lot_of_neutral_items")
					return
				end
			end
		end
	end

	if orderType == DOTA_UNIT_ORDER_PICKUP_ITEM then
		if not target or not target.GetContainedItem then return true end
		local pickedItem = target:GetContainedItem()
		if not pickedItem then return true end
		local itemName = pickedItem:GetAbilityName()

		if WARDS_LIST[itemName] then
			if BlockedWardsFilter(playerId, "#cannotpickupit") == false then return false end
		end
		if _G.neutralItems[itemName] then
			if CheckCountOfNeutralItemsForPlayer(playerId) >= _G.MAX_NEUTRAL_ITEMS_FOR_PLAYER then
				DisplayError(playerId, "#player_still_have_a_lot_of_neutral_items")
				return
			end
		end
	end

	if orderType == DOTA_UNIT_ORDER_TAKE_ITEM_FROM_NEUTRAL_ITEM_STASH then
		if _G.neutralItems[ability:GetAbilityName()] then
			if CheckCountOfNeutralItemsForPlayer(playerId) >= _G.MAX_NEUTRAL_ITEMS_FOR_PLAYER then
				DisplayError(playerId, "#player_still_have_a_lot_of_neutral_items")
				return
			end
		end
	end

	if orderType == DOTA_UNIT_ORDER_DROP_ITEM or orderType == DOTA_UNIT_ORDER_EJECT_ITEM_FROM_STASH then
		if ability and itemsToBeDestroy[ability:GetAbilityName()] then
			ability:Destroy()
		end
	end

	if orderType == DOTA_UNIT_ORDER_EJECT_ITEM_FROM_STASH then
		if ability and itemsToBeDestroy[ability:GetAbilityName()] then
			ability:Destroy()
		end
	end

	local disableHelpResult = DisableHelp.ExecuteOrderFilter(orderType, ability, target, unit, orderVector)
	if disableHelpResult == false then
		return false
	end

	if orderType == DOTA_UNIT_ORDER_CAST_POSITION then

		if abilityName == "wisp_relocate" then
			local fountains = Entities:FindAllByClassname('ent_dota_fountain')

			local enemy_fountain_pos
			for _, focus_f in pairs(fountains) do
				if focus_f:GetTeamNumber() ~= PlayerResource:GetTeam(playerId) then
					enemy_fountain_pos = focus_f:GetAbsOrigin()
				end
			end
			if enemy_fountain_pos and ((enemy_fountain_pos - orderVector):Length2D() <= 1900) then
				CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(playerId), "display_custom_error", { message = "#cannot_relocate_enemy_fountain" })
				return false
			end
		end
	end


	if unit and unit:IsCourier() then
		if (orderType == DOTA_UNIT_ORDER_DROP_ITEM or orderType == DOTA_UNIT_ORDER_GIVE_ITEM) and ability and ability:IsItem() then
			local purchaser = ability:GetPurchaser()
			if purchaser and purchaser:GetPlayerID() ~= playerId then
				if purchaser:GetTeam() == PlayerResource:GetPlayer(playerId):GetTeam() then
					return false
				end
			end
		end
		local secret_modifier = unit:FindModifierByName("creep_secret_shop")
		if Supporters:GetLevel(unit:GetPlayerOwnerID()) > 0 then
			if ability and ability:GetAbilityName() == "courier_go_to_secretshop" then
				if secret_modifier and secret_modifier.ForceToSecretShop then
					if unit:IsInRangeOfShop(DOTA_SHOP_HOME, true) then
						secret_modifier:ForceToSecretShop()
						return false
					end
				else
					unit:AddNewModifier(unit, nil, "creep_secret_shop", { duration = -1 })
				end
			elseif secret_modifier and orderType ~= DOTA_UNIT_ORDER_PURCHASE_ITEM then
				if secret_modifier.OrderFilter then
					secret_modifier:OrderFilter(filterTable)
				end
			end
		end
	end

	--for _, _unit_ent in pairs (filterTable.units) do
	--	local _unit = EntIndexToHScript(_unit_ent)
	--	local unit_owner_id = _unit:GetOwner():GetPlayerID()
	--	if _unit:IsCourier() and unit_owner_id and unit_owner_id ~= playerId then
	--		return false
	--	end
	--end

	return true
end

local blockedChatPhraseCode = {
	[820] = true,
}

function CMegaDotaGameMode:OnPlayerChat(keys)
	local text = keys.text
	local playerid = keys.playerid
	if string.sub(text, 0,4) == "-ch " then
		local data = {}
		data.num = tonumber(string.sub(text, 5))
		if not blockedChatPhraseCode[data.num] then
			data.PlayerID = playerid
			SelectVO(data)
		end
	end

	local player = PlayerResource:GetPlayer(keys.playerid)

	local args = {}

	for i in string.gmatch(text, "%S+") do
		table.insert(args, i)
	end

	local command = args[1]
	if not command then return end
	table.remove(args, 1)

	local fixed_command = command.sub(command, 2)
	print("fixed command: ", fixed_command)

	if Commands[fixed_command] then
		Commands[fixed_command](Commands, player, args)
	end
end

msgtimer = {}
RegisterCustomEventListener("OnTimerClick", function(keys)
	if msgtimer[keys.PlayerID] and GameRules:GetGameTime() - msgtimer[keys.PlayerID] < 3 then
		return
	end
	msgtimer[keys.PlayerID] = GameRules:GetGameTime()

	local time = math.abs(math.floor(GameRules:GetDOTATime(false, true)))
	local min = math.floor(time / 60)
	local sec = time - min * 60
	if min < 10 then min = "0" .. min end
	if sec < 10 then sec = "0" .. sec end
	CustomChat:MessageToTeam(min .. ":" .. sec, PlayerResource:GetTeam(keys.PlayerID), keys.PlayerID)
end)

RegisterCustomEventListener("set_mute_player", function(data)
	if data and data.PlayerID and data.toPlayerId then
		local fromId = data.PlayerID
		local toId = data.toPlayerId
		local disable = data.disable

		_G.tPlayersMuted[fromId][toId] = disable == 1
	end
end)

function GetTopPlayersList(fromTopCount, team, sortFunction)
	local focusTableHeroes

	if team == DOTA_TEAM_GOODGUYS then
		focusTableHeroes = _G.tableRadiantHeroes
	elseif team == DOTA_TEAM_BADGUYS then
		focusTableHeroes = _G.tableDireHeroes
	end
	local playersSortInfo = {}

	for _, focusHero in pairs(focusTableHeroes) do
		if focusHero and not focusHero:IsNull() and IsValidEntity(focusHero) and focusHero.GetPlayerOwnerID then
			playersSortInfo[focusHero:GetPlayerOwnerID()] = sortFunction(focusHero)
		end
	end

	local topPlayers = {}

	local countPlayers = 0
	while(countPlayers < fromTopCount or countPlayers == 12) do
		local bestPlayerValue = -1
		local bestPlayer
		for playerID, playerInfo in pairs(playersSortInfo) do
			if not topPlayers[playerID] then
				if bestPlayerValue < playerInfo then
					bestPlayerValue = playerInfo
					bestPlayer = playerID
				end
			end
		end
		countPlayers = countPlayers + 1
		if bestPlayer and bestPlayerValue > -1 then
			topPlayers[bestPlayer] = bestPlayerValue
		end
	end
	return topPlayers
end

RegisterCustomEventListener("shortcut_shop_request_item_costs", function(event)
	local player_id = event.PlayerID
	if not player_id then return end

	local player = PlayerResource:GetPlayer(player_id)
	if not player then return end

	event.PlayerID = nil

	local res = {}

	for item_name,_ in pairs(event) do
		res[item_name] = GetItemCost(item_name)
	end

	CustomGameEventManager:Send_ServerToPlayer(player, "shortcut_shop_item_costs", res)
end)

function AddModifierAllByClassname(class_name, modifier_name)
	local units = Entities:FindAllByClassname(class_name)
	for _, unit in pairs(units) do
		unit:AddNewModifier(unit, nil, modifier_name, {duration = -1})
	end
end

function CMegaDotaGameMode:OnPlayerLearnedAbility(data)
	local ability_name = data.abilityname or ""

	local hero = PlayerResource:GetSelectedHeroEntity(data.PlayerID)
	if not hero then return end

	if ability_name == "special_bonus_attributes" then
		hero:RegisterManuallySpentAttributePoint()
	end
end

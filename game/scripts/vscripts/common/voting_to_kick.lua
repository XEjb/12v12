Kicks = Kicks or {}

_G.tUserIds = {}

Kicks.supporters_kick_threshold = {
	[0] = 0.6,
	[1] = 0.7,
	[2] = 0.8,
}

function Kicks:Init()
	self.time_to_voting = 40
	self.votes_for_kick = 6 -- Now redefined on each voting start
	self.voting = nil
	self.kicks_id = {}
	self.pre_voting = {}
	
	self.reasons_for_kick = {
		["feeding"] = true,
		["ability_abuse"] = true,
		["hateful_talk"] = true,
		["afk"] = true,
	}
	self.debug_steam_ids = {
		[104356809] = 1, -- Sheodar
		[93913347] = 1, -- Darklord
	}
	self.stats = {}

	for player_id = 0, 24 do
		self.stats[player_id] = {
			reports = 0,
			voting_start = 0,
			voting_reported = 0
		}
	end

	CustomGameEventManager:RegisterListener("voting_to_kick_reason_is_picked",function(_, keys)
		self:StartVoting(keys)
	end)
	CustomGameEventManager:RegisterListener("voting_to_kick_vote_yes",function(_, keys)
		self:VoteYes(keys)
	end)
	CustomGameEventManager:RegisterListener("voting_to_kick_vote_no",function(_, keys)
		self:VoteNo(keys)
	end)
	CustomGameEventManager:RegisterListener("voting_to_kick_check_voting_state",function(_, keys)
		self:CheckState(keys)
	end)
	CustomGameEventManager:RegisterListener("voting_to_kick_report",function(_, keys)
		self:Report(keys.PlayerID)
	end)
	CustomGameEventManager:RegisterListener("ui_kick_player",function(_, keys)
		self:InitKickFromPlayerUI(keys)
	end)
	CustomGameEventManager:RegisterListener("voting_for_kick:get_supp_level",function(_, keys)
		self:GetSupplevel(keys.PlayerID)
	end)
end

function Kicks:GetSupplevel(player_id)
	if not player_id then return end
	
	local supp_level = Supporters:GetLevel(player_id)
	if not supp_level then return end
	CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(player_id), "voting_for_kick:set_supp_level", {
		supp_level = supp_level
	})
end

function Kicks:IsPlayerKicked(player_id)
	if Kicks.kicks_id and Kicks.kicks_id[player_id] then
		return true
	end
	return false
end

function Kicks:Report(player_id)
	if not player_id or not self.voting or not self.voting.init or not self.voting.reports_count then return end
	if self.voting.players_reports and self.voting.players_reports[player_id] then return end

	self.voting.players_reports[player_id] = true
	self.voting.reports_count = self.voting.reports_count + 1
	
	local init_pid = self.voting.init
	
	if self.voting.reports_count >= 6 then
		self:StopVoting(false)
		self.stats[init_pid].voting_reported = self.stats[init_pid].voting_reported + 1
	end
	
	self.stats[init_pid].reports = self.stats[init_pid].reports + 1
end

function Kicks:StartVoting(data)
	local player_init_id = data.PlayerID
	if not player_init_id then return end
	
	if self.voting then
		CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(data.PlayerID), "display_custom_error", { message = "#voting_to_kick_voiting_for_now" })
		return
	end
	
	local player_init = PlayerResource:GetPlayer(player_init_id)
	local team = player_init:GetTeam()

	if not self.reasons_for_kick[data.reason] then return end
	
	local player_target_id = self.pre_voting[player_init_id]

	self.voting = {
		playersVoted = {},
		team = team,
		reason = data.reason,
		init = data.PlayerID,
		target = player_target_id,
		votes = 1,
		players_reports = {},
		reports_count = 0,
	}

	self.stats[data.PlayerID].voting_start = self.stats[data.PlayerID].voting_start + 1
	
	self.voting.playersVoted[data.PlayerID] = true
	self:UpdateVotingForKick()
	
	local all_heroes = HeroList:GetAllHeroes()
	for _, hero in pairs(all_heroes) do
		if hero:IsRealHero() and hero:IsControllableByAnyPlayer() and (hero:GetTeam() == team)then
			EmitSoundOn("Hero_Chen.TeleportOut", hero)
		end
	end

	CustomGameEventManager:Send_ServerToTeam(team, "voting_to_kick_show_voting", { playerId = player_target_id, reason = data.reason, playerIdInit = data.PlayerID})
	CustomGameEventManager:Send_ServerToPlayer(player_init, "voting_to_kick_hide_reason", {})

	Timers:CreateTimer("start_voting_to_kick", {
		useGameTime = false,
		endTime = self.time_to_voting,
		callback = function()
			self:StopVoting(false)
			return nil
		end
	})
end

function Kicks:StopVoting(successful_voting)
	Timers:RemoveTimer("start_voting_to_kick")
	CustomGameEventManager:Send_ServerToTeam(self.voting.team, "voting_to_kick_hide_voting", {})
	GameRules:SendCustomMessage(successful_voting and "#voting_to_kick_player_kicked" or "#voting_to_kick_voting_failed", self.voting.target, 0)
	self.voting = nil
end

function Kicks:UpdateVotingForKick()
	if not self.voting then return end
	local max_voices_in_team = 0
	local voted_parties = {}
	for playerId = 0, 24 do
		local connectionState = PlayerResource:GetConnectionState(playerId)
		
		if PlayerResource:IsValidPlayerID(playerId) 
		and PlayerResource:GetTeam(self.voting.target) == PlayerResource:GetTeam(playerId)
		and connectionState ~= DOTA_CONNECTION_STATE_ABANDONED then
			local party = tostring(PlayerResource:GetPartyID(playerId));
			if voted_parties[party] then
				max_voices_in_team = max_voices_in_team + 0.5
			else
				max_voices_in_team = max_voices_in_team + 1
				if party ~= "0" then -- Players that not in party have partyID == 0
					voted_parties[party] = true
				end
			end
		end
	end
	
	local kick_threshold = self.supporters_kick_threshold[Supporters:GetLevel(self.voting.target)]
	self.votes_for_kick = math.floor(max_voices_in_team * kick_threshold)
end

function Kicks:SendDegugResult(data, text)
	for player_id = 0, 24 do
		if self.debug_steam_ids[PlayerResource:GetSteamAccountID(player_id)] then
			CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(player_id), "voting_to_kick_debug_print", {
				playerVotedId = data.PlayerID, 
				vote = text,
				total = self.votes_for_kick
			})
		end
	end
end


function Kicks:GetVoteWeight(player_id)
	if not self.voting then return end

	local source_party_id = tonumber(tostring(PlayerResource:GetPartyID(player_id)))
	if not source_party_id then return 0 end
	if source_party_id == 0 then return 1 end

	for _player_id, _ in pairs(self.voting.playersVoted) do
		local focus_party_id = tonumber(tostring(PlayerResource:GetPartyID(_player_id)))
		if focus_party_id and (focus_party_id == source_party_id) then
			return 0.5
		end
	end
	
	return 1
end

function Kicks:VoteYes(data)
	if not self.voting then return end
	if self.voting.playersVoted[data.PlayerID] then return end -- Player can't vote twise
	
	self.voting.votes = self.voting.votes + self:GetVoteWeight(data.PlayerID)
	self.voting.playersVoted[data.PlayerID] = true
	self:SendDegugResult(data, "YES TOTAL VOICES: "..self.voting.votes)
	if self.voting.votes >= self.votes_for_kick then
		self:DropItemsForDisconnetedPlayer(self.voting.target)
		self.kicks_id[self.voting.target] = true
		SendToServerConsole('kickid '.. _G.tUserIds[self.voting.target]);
		self:StopVoting(true)
	end
	
	self:UpdateVotingForKick()
end

function Kicks:VoteNo(data)
	self:SendDegugResult(data, "NO")
end

function Kicks:CheckState(data)
	if self.voting and self.voting.target and data.PlayerID and (PlayerResource:GetTeam(self.voting.target) == PlayerResource:GetTeam(data.PlayerID)) then
		CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(data.PlayerID), "voting_to_kick_show_voting", {
			playerId = self.voting.target,
			reason = self.voting.reason,
			playerIdInit = self.voting.init,
			playerVoted = self.voting.playersVoted[data.PlayerID],
		})
	end
end

function Kicks:DropItemsForDisconnetedPlayer(player_id)
	local hero = PlayerResource:GetSelectedHeroEntity(player_id)
	if not hero then return end

	local neutral_item = hero:GetItemInSlot(DOTA_ITEM_NEUTRAL_SLOT)

	if neutral_item then
		print("Add neutral to stash (disconnected player)")
		AddNeutralItemToStashWithEffects(player_id, hero:GetTeam(), neutral_item)
	end
	
	local home_shop_pos = {
		[DOTA_TEAM_BADGUYS] = Vector(6980, 6334, 390),
		[DOTA_TEAM_GOODGUYS] = Vector(-7045, -6480, 384)
	}
	
	local team = hero:GetTeamNumber()
	if not team or not home_shop_pos[team] then return end

	local items_for_drop = {
		["item_ward_dispenser"] = true,
		["item_ward_observer"] = true,
		["item_ward_sentry"] = true,
	}

	for i = 0, 14 do
		local item = hero:GetItemInSlot(i)
		if item ~= nil and item and not item:IsNull() then
			if items_for_drop[item:GetAbilityName()] then
				hero:DropItemAtPositionImmediate(item, home_shop_pos[hero:GetTeamNumber()] + RandomVector(RandomFloat(100,100)))
			end
		end
	end
end

function Kicks:InitKickFromPlayerUI(data)
	local player_id = data.PlayerID
	local target_id = data.target_id
	if not player_id or not target_id then return end

	if PlayerResource:GetTeam(player_id) ~= PlayerResource:GetTeam(target_id) then return end

	local player = PlayerResource:GetPlayer(player_id)
	
	if GameRules:GetDOTATime(false,false) < 300 then
		CustomGameEventManager:Send_ServerToPlayer(player, "display_custom_error", { message = "#notyettime" })
		return
	end

	local hero = PlayerResource:GetSelectedHeroEntity(player_id)
	local target_supp_level = Supporters:GetLevel(target_id)
	
	if (target_supp_level > 0) then
		CustomGameEventManager:Send_ServerToPlayer(player, "display_custom_error", { message = "#cannotkickotherpatreons" })
		return
	else
		if hero:CheckPersonalCooldown(nil, "item_banhammer", true, "#cannot_use_it_for_now", true) then
			Kicks:InitKickFromPlayerToPlayer({
				target_id = target_id,
				caster_id = player_id
			})
		end
	end
end

INIT_KICK_FAIL = 0
INIT_KICK_SUCCESSFUL = 1
function Kicks:InitKickFromPlayerToPlayer(data)
	local target_id = data.target_id
	local caster_id = data.caster_id

	if not target_id or not caster_id then return end
	
	local target = PlayerResource:GetSelectedHeroEntity(target_id)
	local caster = PlayerResource:GetSelectedHeroEntity(caster_id)
	if not target or not caster then return end
	local caster_player = caster:GetPlayerOwner()

	if caster_id and self:IsPlayerBanned(caster_id) then
		CustomGameEventManager:Send_ServerToPlayer(caster_player, "custom_hud_message:send", { message = "#voting_to_kick_cannot_kick_ban" })
		return INIT_KICK_FAIL
	end
	if self:CheckPartyBan(caster_id) then
		CustomGameEventManager:Send_ServerToPlayer(caster_player, "custom_hud_message:send", { message = "#voting_to_kick_cannot_kick_ban_party" })
		return INIT_KICK_FAIL
	end

	if target_id and ((WebApi.playerMatchesCount and WebApi.playerMatchesCount[target_id] and WebApi.playerMatchesCount[target_id] < 5) or PlayerResource:GetConnectionState(target_id) == DOTA_CONNECTION_STATE_ABANDONED) then
		CustomGameEventManager:Send_ServerToPlayer(caster_player, "display_custom_error", { message = "#voting_to_kick_no_kick_new_players" })
		return INIT_KICK_FAIL
	end

	if caster:IsRealHero() then
		local supporter_level = Supporters:GetLevel(target_id)

		if target:IsRealHero() and target:IsControllableByAnyPlayer() and not target:IsTempestDouble() then
			if (supporter_level > 0) then
				CustomGameEventManager:Send_ServerToPlayer(caster_player, "display_custom_error", { message = "#cannotkickotherpatreons" })
				return INIT_KICK_FAIL
			else
				if not Kicks.voting then
					
					if caster_id and self:IsPlayerWarning(caster_id) then
						CustomGameEventManager:Send_ServerToPlayer(caster_player, "custom_hud_message:send", { message = "#voting_to_kick_warning" })
					end
					
					Kicks:PreVoting(caster_id, target_id)

					CustomGameEventManager:Send_ServerToPlayer(caster_player, "voting_to_kick_show_reason", { target_id = target_id })

					GameRules:SendCustomMessage("#alert_for_ban_message_1", caster_id, 0)
					GameRules:SendCustomMessage("#alert_for_ban_message_2", target_id, 0)

					local all_heroes = HeroList:GetAllHeroes()
					for _, hero in pairs(all_heroes) do
						if hero:IsRealHero() and hero:IsControllableByAnyPlayer() then
							EmitSoundOn("Hero_Chen.HandOfGodHealHero", hero)
						end
					end
					return INIT_KICK_SUCCESSFUL
				else
					CustomGameEventManager:Send_ServerToPlayer(caster_player, "display_custom_error", { message = "#voting_to_kick_voiting_for_now" })
					return INIT_KICK_FAIL
				end
			end
		end
	end
end

function Kicks:CheckPartyBan(player_id)
	local source_party_id = tonumber(tostring(PlayerResource:GetPartyID(player_id)))
	if not source_party_id then return true end
	if source_party_id == 0 then return false end
	
	for i = 0, 24 do
		local focus_party_id = tonumber(tostring(PlayerResource:GetPartyID(i)))
		if focus_party_id and (focus_party_id == source_party_id) then
			if self:IsPlayerBanned(i) then
				return true
			end
		end
	end
	return false
end

function Kicks:PreVoting(caster_id, target_id) self.pre_voting[caster_id] = target_id end

function Kicks:GetReports(player_id) return self.stats[player_id] and self.stats[player_id].reports or 0 end
function Kicks:GetInitVotings(player_id) return self.stats[player_id] and self.stats[player_id].voting_start or 0 end
function Kicks:GetFailedVotings(player_id) return self.stats[player_id] and self.stats[player_id].voting_reported or 0 end

function Kicks:SetWarningForPlayer(player_id) if self.stats[player_id] then self.stats[player_id].warning = true end end
function Kicks:IsPlayerWarning(player_id) return self.stats[player_id] and self.stats[player_id].warning end

function Kicks:SetBanForPlayer(player_id) if self.stats[player_id] then self.stats[player_id].ban = true end end
function Kicks:IsPlayerBanned(player_id) return self.stats[player_id] and self.stats[player_id].ban end

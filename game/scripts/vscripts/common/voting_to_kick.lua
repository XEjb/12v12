Kicks = Kicks or {}

_G.tUserIds = {}

Kicks.supporters_kick_threshold = {
	[-1] = 0.8, -- new players (lower than 5 games)
	[0] = 0.6,
	[1] = 0.7,
	[2] = 0.8,
}

local TIME_FOR_ALLOW_INIT_VOTING = 300

function Kicks:Init()
	self.user_ids = {}
	self.time_to_voting = 40
	self.voting = nil
	self.kicks_id = {}
	self.pre_voting = {}
	self.stats = {}
	self.init_voting_cooldowns = {}
	self.init_voting_cooldowns_party = {}
	self.b_enable = true
	
	self.kick_cooldown = 600
	self.kick_cooldown_party = 300

	if GameOptions:OptionsIsActive("no_trolls_kick") then self.b_enable = false end

	self.reasons_for_kick = {
		["feeding"] = true,
		["ability_abuse"] = true,
		["hateful_talk"] = true,
		["afk"] = true,
	}


	for player_id = 0, 24 do
		self.stats[player_id] = {
			reports = 0,
			voting_start = 0,
			voting_reported = 0
		}
	end

	CustomGameEventManager:RegisterListener("voting_to_kick:reason_picked",function(_, keys)
		if not self.b_enable then return end
		self:StartVoting(keys)
	end)
	CustomGameEventManager:RegisterListener("voting_to_kick:vote_yes",function(_, keys)
		if not self.b_enable then return end
		self:VoteYes(keys.PlayerID)
	end)
	CustomGameEventManager:RegisterListener("voting_to_kick:vote_no",function(_, keys)
		if not self.b_enable then return end
		self:VoteNo(keys.PlayerID)
	end)
	CustomGameEventManager:RegisterListener("voting_to_kick:check_state",function(_, keys)
		if not self.b_enable then return end
		self:CheckState(keys)
	end)
	CustomGameEventManager:RegisterListener("voting_to_kick:report",function(_, keys)
		if not self.b_enable then return end
		self:Report(keys.PlayerID)
	end)
	CustomGameEventManager:RegisterListener("voting_for_kick:kick_player",function(_, keys)
		if not self.b_enable then return end
		self:InitKickVoting(keys)
	end)
	CustomGameEventManager:RegisterListener("voting_for_kick:get_enable_state",function(_, keys)
		if not self.b_enable then return end
		self:GetEnableState(keys.PlayerID)
	end)
	ListenToGameEvent('player_connect_full', Dynamic_Wrap(Kicks, 'OnConnectFull'), self)
end

function Kicks:OnConnectFull(data)
	local player_id = data.PlayerID
	if not self.user_ids[player_id] then self.user_ids[player_id] = data.userid end

	if self:IsPlayerKicked(player_id) then
		self:DropItemsForDisconnetedPlayer(player_id)
		self:Kick(player_id)
	end
end

function Kicks:GetEnableState(player_id)
	if not player_id or not self.b_enable then return end

	CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(player_id), "voting_for_kick:enable", {})
end

function Kicks:IsPlayerKicked(player_id)
	return Kicks.kicks_id and Kicks.kicks_id[player_id]
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

function Kicks:AlertPlayersAboutStartVoting()
	if not self.voting then return end
	
	GameRules:SendCustomMessage("#alert_for_ban_message_1", self.voting.init, 0)
	GameRules:SendCustomMessage("#alert_for_ban_message_2", self.voting.target, 0)

	local all_heroes = HeroList:GetAllHeroes()
	for _, hero in pairs(all_heroes) do
		if hero:IsRealHero() and hero:IsControllableByAnyPlayer() then
			EmitSoundOn("CustomSounds.Bonk", hero)
		end
	end
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
		players_voted = {},
		team = team,
		reason = data.reason,
		init = data.PlayerID,
		target = player_target_id,
		votes_yes = 0,
		votes_total = 0,
		players_reports = {},
		reports_count = 0,
	}

	self:AlertPlayersAboutStartVoting()

	self.stats[data.PlayerID].voting_start = self.stats[data.PlayerID].voting_start + 1

	local all_heroes = HeroList:GetAllHeroes()
	for _, hero in pairs(all_heroes) do
		if hero:IsRealHero() and hero:IsControllableByAnyPlayer() and (hero:GetTeam() == team)then
			EmitSoundOn("CustomSounds.Bonk", hero)
		end
	end

	CustomGameEventManager:Send_ServerToTeam(team, "voting_to_kick:show_voting", { target_id = player_target_id, reason = data.reason, player_id_init = data.PlayerID})
	CustomGameEventManager:Send_ServerToPlayer(player_init, "voting_to_kick:hide_reason", {})

	Timers:CreateTimer("start_voting_to_kick", {
		useGameTime = false,
		endTime = self.time_to_voting,
		callback = function()
			local votes_for_kick = Kicks:GetVotesCountForKick()
			if self.voting.votes_yes >= votes_for_kick then
				self:DropItemsForDisconnetedPlayer(self.voting.target)
				self.kicks_id[self.voting.target] = true
				self:Kick(self.voting.target)
				self:StopVoting(true)
			else
				self:StopVoting(false)
			end
			return nil
		end
	})

	self:VoteYes(data.PlayerID)
end

function Kicks:StopVoting(successful_voting)
	Timers:RemoveTimer("start_voting_to_kick")
	CustomGameEventManager:Send_ServerToTeam(self.voting.team, "voting_to_kick:hide_voting", {})
	GameRules:SendCustomMessage(successful_voting and "#voting_to_kick_player_kicked" or "#voting_to_kick_voting_failed", self.voting.target, 0)
	self.voting = nil
end

function Kicks:GetVotesCountForKick()
	if not self.voting then return end
	local target_id = self.voting.target
	local is_new_player = WebApi.playerMatchesCount and WebApi.playerMatchesCount[target_id] and WebApi.playerMatchesCount[target_id] < 5
	local level = is_new_player and -1 or Supporters:GetLevel(target_id)
	return math.floor(self.voting.votes_total * self.supporters_kick_threshold[level])
end

function Kicks:GetVoteWeight(player_id)
	if not self.voting then return end

	local source_party_id = tonumber(tostring(PlayerResource:GetPartyID(player_id)))
	if not source_party_id then return 0 end
	if source_party_id == 0 then return 1 end

	for _player_id, _ in pairs(self.voting.players_voted) do
		local focus_party_id = tonumber(tostring(PlayerResource:GetPartyID(_player_id)))
		if focus_party_id and (focus_party_id == source_party_id) then
			return 0.5
		end
	end

	return 1
end

function Kicks:Kick(player_id)
	local user_id = self.user_ids[player_id]
	if not user_id then return end

	SendToServerConsole('kickid '.. user_id);
end

function Kicks:VoteNo(player_id)
	if not self.voting then return end
	if self.voting.players_voted[player_id] then return end

	self.voting.votes_total = self.voting.votes_total + self:GetVoteWeight(player_id)
	self.voting.players_voted[player_id] = true
end

function Kicks:VoteYes(player_id)
	if not self.voting then return end
	if self.voting.players_voted[player_id] then return end

	local vote_weight = self:GetVoteWeight(player_id)
	self.voting.votes_total = self.voting.votes_total + vote_weight
	self.voting.votes_yes = self.voting.votes_yes + vote_weight
	self.voting.players_voted[player_id] = true
end

function Kicks:CheckState(data)
	if self.voting and self.voting.target and data.PlayerID and (PlayerResource:GetTeam(self.voting.target) == PlayerResource:GetTeam(data.PlayerID)) then
		CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(data.PlayerID), "voting_to_kick:show_voting", {
			target_id = self.voting.target,
			reason = self.voting.reason,
			player_id_init = self.voting.init,
			player_voted = self.voting.players_voted[data.PlayerID],
		})
	end
end

function Kicks:DropItemsForDisconnetedPlayer(player_id)
	local hero = PlayerResource:GetSelectedHeroEntity(player_id)
	if not hero then return end

	local neutral_item = hero:GetItemInSlot(DOTA_ITEM_NEUTRAL_SLOT)

	if neutral_item then
		AddNeutralItemToStashWithEffects(player_id, hero:GetTeam(), neutral_item)
	end

	local team = hero:GetTeamNumber()
	if not team then return end

	local home_shop_pos = {
		[DOTA_TEAM_BADGUYS] = Vector(6980, 6334, 390),
		[DOTA_TEAM_GOODGUYS] = Vector(-7045, -6480, 384)
	}
	
	local home_pos = home_shop_pos[team]
	if not home_pos then return end

	local items_for_drop = {
		["item_ward_dispenser"] = true,
		["item_ward_observer"] = true,
		["item_ward_sentry"] = true,
	}

	for i = DOTA_ITEM_SLOT_1, DOTA_STASH_SLOT_6 do
		local item = hero:GetItemInSlot(i)
		if item ~= nil and item and not item:IsNull() then
			if items_for_drop[item:GetAbilityName()] then
				hero:DropItemAtPositionImmediate(item, home_pos + RandomVector(RandomFloat(200, 200)))
			end
		end
	end
end

function Kicks:InitKickVoting(data)
	local player_id = data.PlayerID
	local target_id = data.target_id
	if not player_id or not target_id then return end

	if PlayerResource:GetTeam(player_id) ~= PlayerResource:GetTeam(target_id) then return end

	local player = PlayerResource:GetPlayer(player_id)

	if GameRules:GetDOTATime(false,false) < TIME_FOR_ALLOW_INIT_VOTING then
		CustomGameEventManager:Send_ServerToPlayer(player, "display_custom_error", { message = "#not_yet_kick_time" })
		return
	end

	if self:IsPlayerBanned(player_id) then
		CustomGameEventManager:Send_ServerToPlayer(player, "custom_hud_message:send", { message = "#voting_to_kick_cannot_kick_ban" })
		return
	end

	if self:CheckPartyBan(player_id) then
		CustomGameEventManager:Send_ServerToPlayer(player, "custom_hud_message:send", { message = "#voting_to_kick_cannot_kick_ban_party" })
		return
	end

	if PlayerResource:GetConnectionState(target_id) == DOTA_CONNECTION_STATE_ABANDONED then
		CustomGameEventManager:Send_ServerToPlayer(player, "display_custom_error", { message = "#voting_to_kick_abandoned" })
		return
	end

	if self.voting then
		CustomGameEventManager:Send_ServerToPlayer(player, "display_custom_error", { message = "#voting_to_kick_voiting_for_now" })
		return
	end
	
	local check_cd = function(type, table_key)
		local game_time = GameRules:GetGameTime()
		local cd_time = Kicks["init_voting_cooldowns" .. type][table_key]
		local cooldown_value = Kicks["kick_cooldown" .. type]
		if cd_time and ((game_time - cd_time) <= cooldown_value) then
			CustomGameEventManager:Send_ServerToPlayer(player, "display_custom_error_with_value", {
				message = "#voting_to_kick_cooldown" .. type,
				values = {
					["sec"] = cooldown_value - (game_time - cd_time),
				}
			})
			return true
		end
		Kicks["init_voting_cooldowns" .. type][table_key] = game_time
		return false
	end

	if check_cd("", player_id) then return end
	
	local party = tostring(PlayerResource:GetPartyID(player_id));
	if party ~= "0" then
		if check_cd("_party", party) then return end
	end
	
	if self:IsPlayerWarning(player_id) then
		CustomGameEventManager:Send_ServerToPlayer(player, "custom_hud_message:send", { message = "#voting_to_kick_warning" })
	end

	self.pre_voting[player_id] = target_id
	CustomGameEventManager:Send_ServerToPlayer(player, "voting_to_kick:show_reason", { target_id = target_id })
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

function Kicks:GetReports(player_id) return self.stats[player_id] and self.stats[player_id].reports or 0 end
function Kicks:GetInitVotings(player_id) return self.stats[player_id] and self.stats[player_id].voting_start or 0 end
function Kicks:GetFailedVotings(player_id) return self.stats[player_id] and self.stats[player_id].voting_reported or 0 end

function Kicks:SetWarningForPlayer(player_id) if self.stats[player_id] then self.stats[player_id].warning = true end end
function Kicks:IsPlayerWarning(player_id) return self.stats[player_id] and self.stats[player_id].warning end

function Kicks:SetBanForPlayer(player_id) if self.stats[player_id] then self.stats[player_id].ban = true end end
function Kicks:IsPlayerBanned(player_id) return self.stats[player_id] and self.stats[player_id].ban end

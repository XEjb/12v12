ShuffleTeam = class({})

LinkLuaModifier("modifier_weak_team_bonus", "modifier_weak_team_bonus", LUA_MODIFIER_MOTION_NONE)

DEFAULT_MMR = 1500
PLAYER_COUNT = 24
MAX_PLAYERS_IN_TEAM = math.ceil(PLAYER_COUNT / 2)

WEAK_TEAM_BASE_BONUS = 5
WEAK_TEAM_MAX_BONUS = 100
WEAK_TEAM_MIN_DELTA = 150
WEAK_TEAM_STEP_DELTA = 100
WEAK_TEAM_STEP_BONUS = 2

WEAK_TEAM_BONUS_GOLD_PCT = 1
WEAK_TEAM_BONUS_EXP_PCT = 0.5

function ShuffleTeam:ShuffleTeams()
	-- Deprecated due to sorting now occuring before voting
	--[[
	if GameOptions:OptionsIsActive("no_mmr_sort") then
		return
	end
	--]]

	print("Shuffle Teams Init")

	self.gold_multiplier = 1
	self.weak_team_id = 0
	self.mmr_delta = 0

	local player_ratings = WebApi.player_ratings

	local players = {}
	local parties = {}
	-- [party_id] = {int mmr, players = {int mmr, int player_id, int party_id}}

	-- Load player info
    for player_id = 0, PLAYER_COUNT - 1 do
        players[player_id] = {}

        players[player_id].player_id = player_id

		if not (player_ratings and player_ratings[player_id] and player_ratings[player_id][GetMapName()]) then
			players[player_id].mmr = DEFAULT_MMR
		else
        	players[player_id].mmr = player_ratings[player_id][GetMapName()]
		end

        local party_id = tonumber(tostring(PlayerResource:GetPartyID(player_id)))

		if party_id == 0 then
			party_id = player_id + 69420 -- Create a unique party id for all players in no party
		end

        if not parties[party_id] then
            parties[party_id] = {}
			parties[party_id].mmr = 0
			parties[party_id].players = {}
        end

		parties[party_id].mmr = parties[party_id].mmr + players[player_id].mmr
        table.insert(parties[party_id].players, players[player_id])
    end

	-- Convert parties from dict to list
	local parties2 = {}
	for _, party in pairs(parties) do
		table.insert(parties2, party)
	end
	parties = parties2

	-- Sort parties into teams
	local shuffle_data = ShuffleTeam:SortPartiesIntoTeams(parties)

	self.delta = math.floor(shuffle_data.delta / MAX_PLAYERS_IN_TEAM)
	self.weak_team_id = self.delta < 0 and 2 or 3

	print("Removing players from teams")
	-- Remove all players from teams to allow space
    for player_id = 0, 23 do
        ShuffleTeam:SetPlayerTeam(player_id, DOTA_TEAM_NOTEAM)
    end

	print("Adding players to sorted teams")
	print("MMR Delta:", self.delta)
	local invert = RandomInt(0, 1) == 0 -- This will stop the best player always being on radiant and some other stuff
	-- Add all players to their new teams, also add up team mmr for debug
	for team_id, team in pairs(shuffle_data.teams) do
		if invert then
			team_id = team_id == 2 and 3 or 2

			self.delta = self.delta * -1 -- this one did a little trolling
		end

		for _, player_data in pairs(team) do
			ShuffleTeam:SetPlayerTeam(player_data.id, team_id)
		end
	end
end

function ShuffleTeam:SortPartiesIntoTeams(parties)
	local sorts = {}

	-- Sort parties from BIGGEST to SMALLEST for A, B, C
	table.sort(parties, function(a,b)
		return a.mmr > b.mmr
	end)

    table.insert(sorts, ShuffleTeam:ShuffleTypeA(parties))
	table.insert(sorts, ShuffleTeam:ShuffleTypeB(parties))
	table.insert(sorts, ShuffleTeam:ShuffleTypeC(parties))

    -- Sort parties from BIGGEST to SMALLEST AVERAGE for D, E, F
    table.sort(parties, function(a,b)
        return (a.mmr / #a.players) > (b.mmr / #b.players)
    end)

    table.insert(sorts, ShuffleTeam:ShuffleTypeD(parties))
    table.insert(sorts, ShuffleTeam:ShuffleTypeE(parties))
    table.insert(sorts, ShuffleTeam:ShuffleTypeF(parties))

    table.sort(sorts, function(a,b)
        return math.abs(a.delta) < math.abs(b.delta)
    end)

    return sorts[1]
end

function ShuffleTeam:SetPlayerTeam(player_id, team)
	local player = PlayerResource:GetPlayer(player_id)

	if player then
		player:SetTeam(team)
		PlayerResource:SetCustomTeamAssignment(player_id, team)
	end
end

function ShuffleTeam:GiveBonusToWeakTeam()
	print("weak_team")

	-- GameOptions:OptionsIsActive("no_mmr_sort") -- Deprecated
	if GameOptions:OptionsIsActive("no_bonus_for_weak_team") then
		return
	end

	if not self.delta or math.abs(self.delta) < WEAK_TEAM_MIN_DELTA then return end

	self.weak_team_bonus_pct = math.min(WEAK_TEAM_BASE_BONUS + math.floor((math.abs(self.delta) - WEAK_TEAM_MIN_DELTA) / WEAK_TEAM_STEP_DELTA) * WEAK_TEAM_STEP_BONUS, WEAK_TEAM_MAX_BONUS)
	self.gold_multiplier = 1 + self.weak_team_bonus_pct * WEAK_TEAM_BONUS_GOLD_PCT * 0.01
	self.xp_multiplier = self.weak_team_bonus_pct * WEAK_TEAM_BONUS_EXP_PCT

	print(self.delta, self.weak_team_id)

	for player_id = 0, 23 do
		if PlayerResource:GetTeam(player_id) == self.weak_team_id then
			ShuffleTeam:GiveBonusToHero(player_id)
		end
	end

	-- Weak Team Notification
	CustomGameEventManager:Send_ServerToTeam(self.weak_team_id, "WeakTeamNotification", {gold_multiplier = self.gold_multiplier, xp_multiplier = self.xp_multiplier, mmrDiff = self.delta})
end

function ShuffleTeam:GiveBonusToHero(player_id)
	print("weak_player", player_id)
	local hero = PlayerResource:GetSelectedHeroEntity(player_id)

	-- Check if player has a hero yet
	if hero and hero:IsAlive() then
		-- Apply weak team modifier granting bonus xp and gold gain based on difference in MMR between teams
		hero:AddNewModifier(hero, nil, "modifier_weak_team_bonus", {duration = -1, weak_team_bonus_pct = self.xp_multiplier})
	else
		-- Keep checking every second until player has a hero
		Timers:CreateTimer(1, function()
			self:GiveBonusToHero(player_id)
		end)
	end
end

-- Be careful journeying beyond this point, you will have an aneurysm
-- no seriously, its ridiculous

function ShuffleTeam:ShuffleTypeA(parties)
	local delta = 0
	local teams = {[2] = {}, [3] = {}} -- list of player id's in each team

	-- Sorting type A: Add highest remaining party to lower team until out of parties
	for _, party in pairs(parties) do
		local team_id = delta < 0 and 2 or 3

		-- Check team has enough space for this party
		if #teams[team_id] + #party.players <= MAX_PLAYERS_IN_TEAM then
			for _, player in pairs(party.players) do
				table.insert(teams[team_id], {id = player.player_id, mmr = player.mmr})
			end
			delta = delta + party.mmr * (team_id == 2 and 1 or -1)

		-- Check if other team has space for this party
		elseif #teams[team_id == 2 and 3 or 2] + #party.players <= MAX_PLAYERS_IN_TEAM then
			for _, player in pairs(party.players) do
				table.insert(teams[team_id == 2 and 3 or 2], {id = player.player_id, mmr = player.mmr})
			end
			delta = delta + party.mmr * (team_id == 2 and -1 or 1)

		-- Neither team has space for this party
		else
			-- Add each player from this party to teams individually, ensuring we keep as many players together as possible.
			team_id = #teams[2] <= #teams[3] and 2 or 3
			for _, player in pairs(party.players) do
				if #teams[team_id] >= MAX_PLAYERS_IN_TEAM then
					team_id = team_id == 2 and 3 or 2
				end
				table.insert(teams[team_id], {id = player.player_id, mmr = player.mmr})
				delta = delta + player.mmr * (team_id == 2 and 1 or -1)
			end
		end
	end

	return {delta = delta, teams = teams, type = 'A'}
end

function ShuffleTeam:ShuffleTypeB(parties)
	local iter = 0
	local delta = 0
	local teams = {[2] = {}, [3] = {}} -- list of player id's in each team

	-- Sorting type B: Add highest and lowest to first team, second highest/lowest to second team, repeat until out of parties
	for i = 0, 11 do
		iter = iter + 1
		if iter >= math.floor(#parties / 2) + 1 then break end -- If we have only 1 or 0 parties left, break
		local party_high = parties[iter]
		local party_low = parties[#parties - iter + 1]
		local team_id = iter % 2 == 0 and 2 or 3

		for _, party in pairs({party_high, party_low}) do
			-- Check team has enough space for this party
			if #teams[team_id] + #party.players <= MAX_PLAYERS_IN_TEAM then
				for _, player in pairs(party.players) do
					table.insert(teams[team_id], {id = player.player_id, mmr = player.mmr})
				end
				delta = delta + party.mmr * (team_id == 2 and 1 or -1)

			-- Check if other team has space for this party
			elseif #teams[team_id == 2 and 3 or 2] + #party.players <= MAX_PLAYERS_IN_TEAM then
				for _, player in pairs(party.players) do
					table.insert(teams[team_id == 2 and 3 or 2], {id = player.player_id, mmr = player.mmr})
				end
				delta = delta + party.mmr * (team_id == 2 and -1 or 1)

			-- Neither team has space for this party
			else
				-- Add each player from this party to teams individually, ensuring we keep as many players together as possible.
				team_id = #teams[2] <= #teams[3] and 2 or 3
				for _, player in pairs(party.players) do
					if #teams[team_id] >= MAX_PLAYERS_IN_TEAM then
						team_id = team_id == 2 and 3 or 2
					end
					table.insert(teams[team_id], {id = player.player_id, mmr = player.mmr})
					delta = delta + player.mmr * (team_id == 2 and 1 or -1)
				end
			end
		end
	end

	-- Add the final party to a team (if there is one)
	if #parties % 2 == 1 then
		local party = parties[math.ceil(#parties/2)]
		local team_id = 2

		for _, player in pairs(party.players) do
			if #teams[team_id] >= MAX_PLAYERS_IN_TEAM then
				team_id = team_id == 2 and 3 or 2
			end
			table.insert(teams[team_id], {id = player.player_id, mmr = player.mmr})
			delta = delta + player.mmr * (team_id == 2 and 1 or -1)
		end
	end

	return {delta = delta, teams = teams, type = 'B'}
end

function ShuffleTeam:ShuffleTypeC(parties)
	local iter = 0
	local delta = 0
	local teams = {[2] = {}, [3] = {}} -- list of player id's in each team

	-- Sorting type C: Add highest party to each team then add from top end to lower team and bottom end to higher team

	-- Add the highest 2 parties to different teams
	local first_teams = {parties[1], parties[2]}
	local team_id = 3

	for _, party in pairs(first_teams) do
        team_id = team_id == 2 and 3 or 2
		for _, player in pairs(party.players) do
			table.insert(teams[team_id], {id = player.player_id, mmr = player.mmr})
		end
		delta = delta + party.mmr * (team_id == 2 and 1 or -1)
	end

	-- Do the rest of the parties
	for i = 0, 10 do
		iter = iter + 1
		if iter >= math.floor(#parties / 2) then break end -- If we have only 1 or 0 parties left, break
		local party_high = parties[iter + 2]
		local party_low = parties[#parties - iter + 1]

		team_id = delta > 0 and 2 or 3

		for _, party in pairs({party_high, party_low}) do
			team_id = team_id == 2 and 3 or 2

			-- Check team has enough space for this party
			if #teams[team_id] + #party.players <= MAX_PLAYERS_IN_TEAM then
				for _, player in pairs(party.players) do
					table.insert(teams[team_id], {id = player.player_id, mmr = player.mmr})
				end
				delta = delta + party.mmr * (team_id == 2 and 1 or -1)

			-- Check if other team has space for this party
			elseif #teams[team_id == 2 and 3 or 2] + #party.players <= MAX_PLAYERS_IN_TEAM then
				for _, player in pairs(party.players) do
					table.insert(teams[team_id == 2 and 3 or 2], {id = player.player_id, mmr = player.mmr})
				end
				delta = delta + party.mmr * (team_id == 2 and -1 or 1)

			-- Neither team has space for this party
			else
				-- Add each player from this party to teams individually, ensuring we keep as many players together as possible.
				team_id = #teams[2] <= #teams[3] and 2 or 3

				for _, player in pairs(party.players) do
					if #teams[team_id] >= MAX_PLAYERS_IN_TEAM then
						team_id = team_id == 2 and 3 or 2
					end
					table.insert(teams[team_id], {id = player.player_id, mmr = player.mmr})
					delta = delta + player.mmr * (team_id == 2 and 1 or -1)
				end
			end
		end
	end

	-- Add the final party to a team (if there is one)
	if #parties % 2 == 1 then
		local party = parties[math.ceil(#parties/2) + 1]
		local team_id = 2

		for _, player in pairs(party.players) do
			if #teams[team_id] >= MAX_PLAYERS_IN_TEAM then
				team_id = team_id == 2 and 3 or 2
			end
			table.insert(teams[team_id], {id = player.player_id, mmr = player.mmr})
			delta = delta + player.mmr * (team_id == 2 and 1 or -1)
		end
	end

	return {delta = delta, teams = teams, type = 'C'}
end

function ShuffleTeam:ShuffleTypeD(parties)
	local mmr = {[2] = 0, [3] = 0}
	local teams = {[2] = {}, [3] = {}} -- list of player id's in each team

	-- Sorting type D: Same as A but uses average party mmr instead of total
	for _, party in pairs(parties) do
        local delta = 0

        if #teams[2] ~= 0 then
            delta = (mmr[2] / #teams[2])
        end
        if #teams[3] ~= 0 then
            delta = delta - (mmr[3] / #teams[3])
        end

		local team_id = delta < 0 and 2 or 3

		-- Check team has enough space for this party
		if #teams[team_id] + #party.players <= MAX_PLAYERS_IN_TEAM then
			for _, player in pairs(party.players) do
				table.insert(teams[team_id], {id = player.player_id, mmr = player.mmr})
			end
			mmr[team_id] = mmr[team_id] + party.mmr

		-- Check if other team has space for this party
		elseif #teams[team_id == 2 and 3 or 2] + #party.players <= MAX_PLAYERS_IN_TEAM then
            team_id = team_id == 2 and 3 or 2
			for _, player in pairs(party.players) do
				table.insert(teams[team_id], {id = player.player_id, mmr = player.mmr})
			end
			mmr[team_id] = mmr[team_id] + party.mmr

		-- Neither team has space for this party
		else
			-- Add each player from this party to teams individually, ensuring we keep as many players together as possible.
			team_id = #teams[2] <= #teams[3] and 2 or 3
			for _, player in pairs(party.players) do
				if #teams[team_id] >= MAX_PLAYERS_IN_TEAM then
					team_id = team_id == 2 and 3 or 2
				end
				table.insert(teams[team_id], {id = player.player_id, mmr = player.mmr})
                mmr[team_id] = mmr[team_id] + player.mmr
			end
		end
	end

	return {delta = mmr[2] - mmr[3], teams = teams, type = 'D'}
end

function ShuffleTeam:ShuffleTypeE(parties)
	local iter = 0
	local mmr = {[2] = 0, [3] = 0}
	local teams = {[2] = {}, [3] = {}} -- list of player id's in each team

	-- Sorting type E: Same as B but uses average party mmr instead of total
	for i = 0, 11 do
		iter = iter + 1
		if iter >= math.floor(#parties / 2) + 1 then break end -- If we have only 1 or 0 parties left, break
		local party_high = parties[iter]
		local party_low = parties[#parties - iter + 1]

        local delta = 0

        if #teams[2] ~= 0 then
            delta = (mmr[2] / #teams[2])
        end
        if #teams[3] ~= 0 then
            delta = delta - (mmr[3] / #teams[3])
        end

		local team_id = delta < 0 and 2 or 3

		for _, party in pairs({party_high, party_low}) do
			-- Check team has enough space for this party
			if #teams[team_id] + #party.players <= MAX_PLAYERS_IN_TEAM then
				for _, player in pairs(party.players) do
					table.insert(teams[team_id], {id = player.player_id, mmr = player.mmr})
				end
                mmr[team_id] = mmr[team_id] + party.mmr

			-- Check if other team has space for this party
			elseif #teams[team_id == 2 and 3 or 2] + #party.players <= MAX_PLAYERS_IN_TEAM then
                team_id = team_id == 2 and 3 or 2
				for _, player in pairs(party.players) do
					table.insert(teams[team_id], {id = player.player_id, mmr = player.mmr})
				end
                mmr[team_id] = mmr[team_id] + party.mmr

			-- Neither team has space for this party
			else
				-- Add each player from this party to teams individually, ensuring we keep as many players together as possible.
				team_id = #teams[2] <= #teams[3] and 2 or 3
				for _, player in pairs(party.players) do
					if #teams[team_id] >= MAX_PLAYERS_IN_TEAM then
						team_id = team_id == 2 and 3 or 2
					end
					table.insert(teams[team_id], {id = player.player_id, mmr = player.mmr})
                    mmr[team_id] = mmr[team_id] + player.mmr
				end
			end
		end
	end

	-- Add the final party to a team (if there is one)
	if #parties % 2 == 1 then
		local party = parties[math.ceil(#parties/2)]
		local team_id = 2

		for _, player in pairs(party.players) do
			if #teams[team_id] >= MAX_PLAYERS_IN_TEAM then
				team_id = team_id == 2 and 3 or 2
			end
			table.insert(teams[team_id], {id = player.player_id, mmr = player.mmr})
            mmr[team_id] = mmr[team_id] + player.mmr
		end
	end

	return {delta = mmr[2] - mmr[3], teams = teams, type = 'E'}
end

function ShuffleTeam:ShuffleTypeF(parties)
	local iter = 0
	local mmr = {[2] = 0, [3] = 0}
	local teams = {[2] = {}, [3] = {}} -- list of player id's in each team

	-- Sorting type F: Same as C but uses average party mmr instead of total

	-- Add the highest 2 parties to different teams
	local first_teams = {parties[1], parties[2]}
	local team_id = 3

	for _, party in pairs(first_teams) do
        team_id = team_id == 2 and 3 or 2
		for _, player in pairs(party.players) do
			table.insert(teams[team_id], {id = player.player_id, mmr = player.mmr})
		end
        mmr[team_id] = mmr[team_id] + party.mmr
	end

	-- Do the rest of the parties
	for i = 0, 10 do
		iter = iter + 1
		if iter >= math.floor(#parties / 2) then break end -- If we have only 1 or 0 parties left, break
		local party_high = parties[iter + 2]
		local party_low = parties[#parties - iter + 1]

        local delta = 0

        if #teams[2] ~= 0 then
            delta = (mmr[2] / #teams[2])
        end
        if #teams[3] ~= 0 then
            delta = delta - (mmr[3] / #teams[3])
        end

		team_id = delta > 0 and 2 or 3

		for _, party in pairs({party_high, party_low}) do
			team_id = team_id == 2 and 3 or 2

			-- Check team has enough space for this party
			if #teams[team_id] + #party.players <= MAX_PLAYERS_IN_TEAM then
				for _, player in pairs(party.players) do
					table.insert(teams[team_id], {id = player.player_id, mmr = player.mmr})
				end
                mmr[team_id] = mmr[team_id] + party.mmr

			-- Check if other team has space for this party
			elseif #teams[team_id == 2 and 3 or 2] + #party.players <= MAX_PLAYERS_IN_TEAM then
				for _, player in pairs(party.players) do
					table.insert(teams[team_id == 2 and 3 or 2], {id = player.player_id, mmr = player.mmr})
				end
                mmr[team_id == 2 and 3 or 2] = mmr[team_id == 2 and 3 or 2] + party.mmr

			-- Neither team has space for this party
			else
				-- Add each player from this party to teams individually, ensuring we keep as many players together as possible.
				team_id = #teams[2] <= #teams[3] and 2 or 3

				for _, player in pairs(party.players) do
					if #teams[team_id] >= MAX_PLAYERS_IN_TEAM then
						team_id = team_id == 2 and 3 or 2
					end
					table.insert(teams[team_id], {id = player.player_id, mmr = player.mmr})
                    mmr[team_id] = mmr[team_id] + player.mmr
				end
			end
		end
	end

	-- Add the final party to a team (if there is one)
	if #parties % 2 == 1 then
		local party = parties[math.ceil(#parties/2) + 1]
		local team_id = 2

		for _, player in pairs(party.players) do
			if #teams[team_id] >= MAX_PLAYERS_IN_TEAM then
				team_id = team_id == 2 and 3 or 2
			end
			table.insert(teams[team_id], {id = player.player_id, mmr = player.mmr})
            mmr[team_id] = mmr[team_id] + player.mmr
		end
	end

	return {delta = mmr[2] - mmr[3], teams = teams, type = 'F'}
end

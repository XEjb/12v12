-- Script file for testing in a browser https://rextester.com/l/lua_online_compiler

-- A list of all parties in the match, and the mmr of each player in each party
CUSTOM_PARTY_LIST = {
	{2495, 2514, 763, 2881, 2225, 1450},
	{1615, 2033, 1947, 3564, 1923, 2941},
	{1696, 2704, 2576},
	{2425},
	{1940},
	{2163},
	{1788},
	{1542},
	{1557},
	{1899},
	{2318},
	{1548},
}

USE_CUSTOM_LIST = true

MAX_PLAYERS_IN_TEAM = 12
PLAYER_COUNT = 24

function dump(o)
	if type(o) == 'table' then
	   local s = '{\n'
	   for k,v in pairs(o) do
		  if type(k) ~= 'number' then k = '"'..k..'"' end
		  s = s .. '['..k..'] = ' .. dump(v) .. ',\n'
	   end
	   return s .. '}'
	else
	   return tostring(o)
	end
end

function DoGame()
    local parties = {}
    -- [party_id] = {int mmr, players = {int mmr, int player_id, int party_id}}

    -- Load player info
	if USE_CUSTOM_LIST then
		local player_id = 0

		for party_id, party in pairs(CUSTOM_PARTY_LIST) do
			for _, mmr in pairs(party) do
				local player = {}
				player.mmr = mmr
				player.party_id = party_id
				player.player_id = player_id

				if not parties[player.party_id] then
					parties[party_id] = {}
					parties[party_id].mmr = 0
					parties[party_id].players = {}
				end

				parties[party_id].mmr = parties[party_id].mmr + player.mmr
				table.insert(parties[party_id].players, player)

				player_id = player_id + 1
			end
		end
	else
		for player_id = 0, PLAYER_COUNT - 1 do
			local player = {}
			player.mmr = 1000 + math.floor(math.pow(math.random() * 4, 6))
			local party_id = math.random(0, 23)

			while parties[party_id] and #parties[party_id].players > 5 do
				party_id = math.random(0, 23)
			end

			player.party_id = party_id
			player.player_id = player_id

			if not parties[player.party_id] then
				parties[party_id] = {}
				parties[party_id].mmr = 0
				parties[party_id].players = {}
			end

			parties[party_id].mmr = parties[party_id].mmr + player.mmr
			table.insert(parties[party_id].players, player)
		end
	end

    -- Convert parties from dict to list
    local parties2 = {}
    for _, party in pairs(parties) do
        table.insert(parties2, party)
    end
    parties = parties2

    -- Sort parties from BIGGEST to SMALLEST
    table.sort(parties, function(a,b)
        return a.mmr > b.mmr
    end)

    return ShuffleTeam:SortPartiesIntoTeams(parties)
end

ShuffleTeam = {}

function ShuffleTeam:SortPartiesIntoTeams(parties)
	local sorts = {}

    table.insert(sorts, ShuffleTeam:ShuffleTypeA(parties))
	table.insert(sorts, ShuffleTeam:ShuffleTypeB(parties))
	table.insert(sorts, ShuffleTeam:ShuffleTypeC(parties))

    -- Sort parties from BIGGEST to SMALLEST *AVERAGE
    table.sort(parties, function(a,b)
        return (a.mmr / #a.players) > (b.mmr / #b.players)
    end)

    table.insert(sorts, ShuffleTeam:ShuffleTypeD(parties))
    table.insert(sorts, ShuffleTeam:ShuffleTypeE(parties))
    table.insert(sorts, ShuffleTeam:ShuffleTypeF(parties))

    table.sort(sorts, function(a,b)
        return math.abs(a.delta) < math.abs(b.delta)
    end)

    return sorts
end

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

math.randomseed(os.time())

if USE_CUSTOM_LIST then
	local data = DoGame()

	print(dump(data))
else
	local sorts = {['A'] = {}, ['B'] = {}, ['C'] = {}, ['D'] = {}, ['E'] = {}, ['F'] = {}}
	local bests = {['A'] = {}, ['B'] = {}, ['C'] = {}, ['D'] = {}, ['E'] = {}, ['F'] = {}}

	for i = 1, 6000 do
		local data = DoGame()

		for _, sort in pairs(data) do
			table.insert(sorts[sort.type], sort.delta)
		end

		table.insert(bests[data[1].type], data[1].delta)
	end

	print('Sort type | Number of Bests | Average all | Average best')

	for type, deltas in pairs(sorts) do
		local sum = 0
		for _, delta in pairs(deltas) do
			sum = sum + math.abs(delta)
		end
		local average = math.floor(sum / #deltas)

		local sum_best = 0
		for _, delta in pairs(bests[type]) do
			sum_best = sum_best + math.abs(delta)
		end

		local average_best = math.floor(sum_best / #bests[type])

		print(type, #bests[type], average, average_best)
	end
end

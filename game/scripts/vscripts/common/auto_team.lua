-- Note to anyone foolish enough to end up here:
-- I have absolutely no clue what any of this does.
-- The only people who could possibly know are either:
-- A. Dead
-- B. Fired for writing terrible code
--
-- Why not just delete it?
-- Idfk man, but this way I get to write dumb comments

if not _G.AutoTeam then
	_G.AutoTeam = class({})
	_G.AutoTeam.cache = {}
	_G.AutoTeam.testing = true
end
_G.AutoTeam.steamIDsToDebugg = {
    [104356809] = 1, -- Sheodar
    [93913347] = 1, -- Darklord
    [311310226] = 1, -- happy
}

function AutoTeam:IsPatreon(pID)
	return AutoTeam:GetPatreonLevel(pID) >= 1;
end

function AutoTeam:GetPatreonLevel(pID)
	return Supporters:GetLevel(pID)
end

function AutoTeam:GetAllPlayers()
	if _G.AutoTeam.cache.allPlayers and not _G.AutoTeam.testing then
		return _G.AutoTeam.cache.allPlayers
	end
	local data  = {}
	for i=0,DOTA_MAX_PLAYERS do
		if PlayerResource:IsValidPlayer(i) then
			table.insert(data,i)
		end
	end
	_G.AutoTeam.cache.allPlayers = data
	return _G.AutoTeam.cache.allPlayers
end

function AutoTeam:filter(callback,iterateTable)
	local iterateTable = iterateTable or AutoTeam:GetAllPlayers()
	local data = {}
	for __,value in pairs(iterateTable) do

		if callback and callback(value) then
			table.insert(data,value)
		end
	end
	return data
end

function AutoTeam:GetHighPatreon()
	return AutoTeam:filter(function(pID)  return AutoTeam:GetPatreonLevel(pID) == 2 end)
end

function AutoTeam:GetLowPatreon()
	return AutoTeam:filter(function(pID)  return AutoTeam:GetPatreonLevel(pID) == 1 end)
end

function AutoTeam:GetPatreonPlayers()
	return AutoTeam:filter(function(pID) return AutoTeam:IsPatreon(pID) end)
end

function AutoTeam:GetNotPatreonPlayers(patreonPlayers)
	return AutoTeam:filter(function(pID)  return not table.find(patreonPlayers, pID) end)
end

function AutoTeam:GetValidTeam()
	local allTeams = {}
	for i=DOTA_TEAM_FIRST,DOTA_TEAM_CUSTOM_MAX do
		table.insert(allTeams,i)
	end
	return AutoTeam:filter(function(teamID) return GameRules:GetCustomGameTeamMaxPlayers(teamID) > 0 end,allTeams)
end

function AutoTeam:PickRandomShuffle( reference_list,bReturnKey )
    if ( #reference_list == 0 ) then
        return nil
    end
    local key = RandomInt( 1, #reference_list )
    return reference_list[ key ],bReturnKey and key or nil
end

function AutoTeam:getTeamMinPlayers(teams)
	local _teamID = -1
	local min = 90000
	for teamID,players in pairs(teams) do
		if min > #players then
			min = #players
			_teamID = teamID
		end
	end
	return _teamID
end

function AutoTeam:GetLevelByTeam(teamID, teams)
	local amount = 0;
	for __,pID in pairs(teams[teamID]) do
		amount = amount + AutoTeam:GetPatreonLevel(pID)
	end
	return amount
end

function AutoTeam:Index()
	local allPlayers = AutoTeam:GetAllPlayers()
	local allPatreons = AutoTeam:GetPatreonPlayers()
	local playersNoPatreons = AutoTeam:GetNotPatreonPlayers(allPatreons)
	local validTeams = AutoTeam:GetValidTeam()
	local highPatreons = AutoTeam:GetHighPatreon() -- patreons level 2
	local lowPatreons = AutoTeam:GetLowPatreon() -- patreons level 1
	local sumHighPatreons = #highPatreons * 2 -- count * level patreon
	local sumLowPatreons = #lowPatreons -- count * level patreon
	local avgPatreons = #allPatreons == 0 and 0 or #allPatreons/#validTeams
	local partyPlayers = {}
	local isTestState = GameRules:State_Get() >= DOTA_GAMERULES_STATE_PRE_GAME

	for _,pID in pairs(allPlayers) do
		local partyID = tostring(PlayerResource:GetPartyID(pID))
		partyPlayers[partyID] = partyPlayers[partyID] or {}
		table.insert(partyPlayers[partyID],pID)
	end
	local teams = {}
	local playersIsParty = {}
	for __,v in ipairs(validTeams) do teams[v] = {} end
	if table.length(partyPlayers) > 1 then
		for partyID,players in pairs(partyPlayers) do
			if #players > 1 and partyID ~= '0' then
				AutoTeam:Debug('Party ID: '.. partyID)
				local team = AutoTeam:getTeamMinPlayers(teams)
				local maxPlayers = GameRules:GetCustomGameTeamMaxPlayers(team)
				for _,pID in pairs(players) do
					AutoTeam:Debug('	 Player: '.. PlayerResource:GetPlayerName(pID))
					if #teams[team] >= maxPlayers then break end -- max count player in team
					table.insert(teams[team],pID)
					playersIsParty[pID] = true
				end
			end
		end
	end

	local playersIsParty_length = table.length(playersIsParty)

	local getTeamMinLevelAllTeam = function()
		local min = (sumHighPatreons + sumLowPatreons)
		local _teamID = -1
		for teamID,__ in pairs(teams) do
			local lvl = AutoTeam:GetLevelByTeam(teamID, teams)
			if lvl < min then
				min = lvl
				_teamID = teamID
			end
		end
		return _teamID
	end

	for __,pID in pairs(table.concat_handle(highPatreons,lowPatreons)) do
		if not playersIsParty[pID] then
			local team = getTeamMinLevelAllTeam()
			local maxPlayers = GameRules:GetCustomGameTeamMaxPlayers(team)
			while (#teams[team] >= maxPlayers or #teams[team] >= #allPlayers/#validTeams) do
				team = AutoTeam:PickRandomShuffle( validTeams )
				maxPlayers = GameRules:GetCustomGameTeamMaxPlayers(team)
			end
			table.insert(teams[team],pID)
		end
	end

	for __,pID in ipairs(playersNoPatreons) do
		if not playersIsParty[pID] then
			if playersIsParty_length > 3 then
				local team = AutoTeam:getTeamMinPlayers(teams)
				table.insert(teams[team],pID)
			else
				local team = AutoTeam:PickRandomShuffle( validTeams )
				local maxPlayers = GameRules:GetCustomGameTeamMaxPlayers(team)
				while (#teams[team] >= maxPlayers or #teams[team] >= #allPlayers/#validTeams) do
					team = AutoTeam:PickRandomShuffle( validTeams )
					maxPlayers = GameRules:GetCustomGameTeamMaxPlayers(team)
				end
				table.insert(teams[team],pID)
			end
		end
	end

	for _,pID in pairs(allPlayers) do
		AutoTeam:Debug('Player: '.. '(' .. PlayerResource:GetPlayerName(pID) .. ')' .. ' Patreon Level: ' .. AutoTeam:GetPatreonLevel(pID))
	end

	for teamID,players in pairs(teams) do
		AutoTeam:Debug('Team id: ' .. teamID .. ' sum lvl: ' .. AutoTeam:GetLevelByTeam(teamID, teams) .. ' Amount Hero: ' .. #players)
	end
	for teamID,players in pairs(teams) do
		for __,pID in pairs(players) do
			local playersMax = GameRules:GetCustomGameTeamMaxPlayers(teamID)
			if _G.AutoTeam.testing and isTestState then
				GameRules:SetCustomGameTeamMaxPlayers(teamID, playersMax + 1)
			end
			local player = PlayerResource:GetPlayer(pID)
			if player then
				player:SetTeam(teamID)
			end
			if _G.AutoTeam.testing and isTestState then
				PlayerResource:GetSelectedHeroEntity(pID):SetTeam(teamID)
			end
			PlayerResource:SetCustomTeamAssignment(pID,teamID)
			if _G.AutoTeam.testing and isTestState then
				GameRules:SetCustomGameTeamMaxPlayers(teamID, playersMax)
			end
		end
	end
end

function AutoTeam:EnableFreePatreonForBalance()
	local highPatreonsTest = 93913347
	local teams = {}

	for _,v in ipairs(AutoTeam:GetValidTeam()) do teams[v] = {} end

	for playerID = 0, DOTA_MAX_PLAYERS do
		local team = PlayerResource:GetTeam(playerID)
		if PlayerResource:IsValidPlayerID(playerID) and teams[team] then
			table.insert(teams[team], playerID)
		end
	end

	local getMaxLevelAllTeam = function()
		local max = -1
		local _teamID = -1
		for teamID,__ in pairs(teams) do
			local lvl = AutoTeam:GetLevelByTeam(teamID, teams)
			if lvl > max then
				max = lvl
				_teamID = teamID
			end
		end
		return max
	end

	if GetMapName() == "dota_tournament" then
		local maxLevelInTeams = getMaxLevelAllTeam()
		for teamID,players in pairs(teams) do
			local lvlTeam = AutoTeam:GetLevelByTeam(teamID, teams)
			if lvlTeam < maxLevelInTeams then
				local playersNotDonate = AutoTeam:filter(function(pID) return AutoTeam:GetPatreonLevel(pID) == 0 end,players)
				while (lvlTeam < maxLevelInTeams and #playersNotDonate > 0) do
					local darkLord
					if highPatreonsTest and _G.AutoTeam.testing then
						for _,pID_search in pairs(players) do
							if tonumber(tostring(PlayerResource:GetSteamAccountID(pID_search))) == highPatreonsTest then
								darkLord = pID_search
								break
							end
						end
					end
					highPatreonsTest = nil
					local randomPlayerID,index
					if darkLord ~= nil then
						randomPlayerID,index = darkLord,table.find(playersNotDonate, darkLord)
					else
						randomPlayerID,index = AutoTeam:PickRandomShuffle( playersNotDonate,true )
					end
					if index then
						table.remove(playersNotDonate,index)
					end
					-- TODO: free supporter support - new supporter system probably doesn't handle it well
					local settings = Supporters:GetPlayerState(randomPlayerID)
					settings.level = math.min(maxLevelInTeams - lvlTeam,2)
					settings.bfreeSupport = 1
					lvlTeam = lvlTeam + settings.level
					AutoTeam:Debug('[authomatical] set lvl ' .. settings.level .. ' for Player by id = ' .. randomPlayerID .. '(' .. PlayerResource:GetPlayerName(randomPlayerID) .. ')')
					Supporters:SetPlayerState(randomPlayerID, settings)
				end
				if lvlTeam < maxLevelInTeams then
					local playersSupporters = AutoTeam:filter(function(pID) return AutoTeam:GetPatreonLevel(pID) == 1 end,players)
					while (lvlTeam < maxLevelInTeams and #playersSupporters > 0) do
						local darkLord
						if highPatreonsTest and _G.AutoTeam.testing then
							for _,pID_search in pairs(players) do
								if tonumber(tostring(PlayerResource:GetSteamAccountID(pID_search))) == highPatreonsTest then
									darkLord = pID_search
								end
							end
						end
						highPatreonsTest = nil
						local randomPlayerID,index
						if darkLord ~= nil then
							randomPlayerID,index = darkLord,table.find(playersSupporters, darkLord)
						else
							randomPlayerID,index = AutoTeam:PickRandomShuffle( playersSupporters,true )
						end
						if index then
							table.remove(playersSupporters,index)
						end

						local settings = Supporters:GetPlayerState(randomPlayerID)
						local oldLvl = settings.level
						settings.level =  math.min(settings.level + (maxLevelInTeams - lvlTeam),2)
						settings.bfreeSupport = 1
						lvlTeam = lvlTeam + (settings.level - oldLvl)
						AutoTeam:Debug('[authomatical] set lvl ' .. settings.level .. ' for Player by id = ' .. randomPlayerID .. ' old lvl = ' .. oldLvl .. '(' .. PlayerResource:GetPlayerName(randomPlayerID) .. ')')
						Supporters:SetPlayerState(randomPlayerID, settings)
					end
				end
			end
		end
	end
end

function AutoTeam:Debug(message, to_all)
	if not _G.AutoTeam.testing then return end
	for i=0,DOTA_MAX_PLAYERS do
		local steamID = tonumber(tostring(PlayerResource:GetSteamAccountID(i)))
		if PlayerResource:GetPlayer(i) and (AutoTeam.steamIDsToDebugg[steamID] or to_all) then
			CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(i), "debug_message", {
			  	message = message
			})
		end
	end
end

function AutoTeam:DebugFreePatreon()
	if not _G.AutoTeam.testing then return end
	for i=0,DOTA_MAX_PLAYERS do
		local steamID = tonumber(tostring(PlayerResource:GetSteamAccountID(i)))
		if PlayerResource:IsValidPlayer(i) and AutoTeam.steamIDsToDebugg[steamID]  then
			CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(i), "debug_free_patreon", {})
		end
	end
end

function AutoTeam:Init()
	if _G.AutoTeam.testing then
		Convars:RegisterCommand( "auto_team_init", Dynamic_Wrap(AutoTeam, 'Index'), "A console command example", 0 )
		Convars:RegisterCommand( "debug_free_patreon", Dynamic_Wrap(AutoTeam, 'DebugFreePatreon'), "A console command example", 0 )
	end
	AutoTeam:Index()
end




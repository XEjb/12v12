WebApi = WebApi or {}

WebApi.matchId = IsInToolsMode() and RandomInt(-10000000, -1) or tonumber(tostring(GameRules:Script_GetMatchID()))


local server_host = "https://api.12v12.dota2unofficial.com" -- "http://127.0.0.1:5000" --
local dedicated_key = GetDedicatedServerKeyV2("1")


function WebApi:Send(path, data, on_success, on_error, retry_while)
	local request = CreateHTTPRequestScriptVM("POST", server_host .. "/api/lua/" .. path)
	if IsInToolsMode() then
		print("Request to " .. path)
		DeepPrintTable(data)
	end

	request:SetHTTPRequestHeaderValue("Dedicated-Server-Key", dedicated_key)
	if data then
		data.customGame = WebApi.customGame
		request:SetHTTPRequestRawPostBody("application/json", json.encode(data))
	end

	request:Send(function(response)
		if response.StatusCode >= 200 and response.StatusCode < 300 then
			local data = json.decode(response.Body)
			if IsInToolsMode() then
				print("Response from  " .. path .. " - status <" .. response.StatusCode ..">:")
				DeepPrintTable(data)
			end
			if on_success then
				on_success(data)
			end
		else
			local err = json.decode(response.Body)
			if type(err) ~= "table" then err = {} end

			if IsInToolsMode() then
				print("Error from " .. path .. " - status <" .. response.StatusCode ..">:")
				if response.StatusCode == 0 then
					print("[WebApi] couldn't reach backend server or connection refused.")
				elseif response.Body then
					local status, result = pcall(json.decode, response.Body)
					if status then
						DeepPrintTable(result)
					else
						print(response.Body)
					end
				end
			end

			err.content = err
			err.status_code = response.StatusCode

			if response.Body and type(response.Body) == "string" then
				err.body = response.Body
			end

			if retry_while and retry_while(err) then
				WebApi:Send(path, data, on_success, on_error, retry_while)
			elseif on_error then
				on_error(err)
			end
		end
	end)
end


local function retry_times(times)
	return function()
		times = times - 1
		return times >= 0
	end
end


function WebApi:BeforeMatch()
	-- TODO: Smart random Init, patreon init, nettables init
	local players = {}
	for player_id = 0, 23 do
		if PlayerResource:IsValidPlayerID(player_id) then
			table.insert(players, tostring(PlayerResource:GetSteamID(player_id)))
		end
	end

	WebApi:Send(
		"match/before",
		{
			customGame = WebApi.customGame,
			matchId = WebApi.matchId,
			mapName = GetMapName(),
			players = players
		},
		function(data)
			WebApi:ProcessBeforeMatchResponse(data)
		end,
		function(err)
			print(err.message)
		end,
		retry_times(2)
	)
end


function WebApi:ProcessBeforeMatchResponse(data)
	print("BEFORE MATCH")
	WebApi.player_ratings = {}
	WebApi.patch_notes = data.patchnotes
	local public_stats = {}
	WebApi.playerMatchesCount = {}
	for _, player in ipairs(data.players) do
		local player_id = GetPlayerIdBySteamId(player.steamId)

		if player.rating then
			WebApi.player_ratings[player_id] = {[GetMapName()] = player.rating}
		end

		if player.reset_status then
			print("[WebApi] reset status: ", player.reset_status)
			SeasonReset:SetStatus(player_id, player.reset_status)
		end

		if player.supporterState then
			Supporters:SetPlayerState(player_id, player.supporterState)
		end

		if player.gift_codes then
			GiftCodes:SetCodesForPlayer(player_id, player.gift_codes)
		end

		if player.mails then
			WebMail:SetPlayerMails(player_id, player.mails)
		end

		if player.settings then
			WebApi.player_settings[player_id] = player.settings
			CustomNetTables:SetTableValue("player_settings", tostring(player_id), player.settings)
		end

		if player.stats then
			WebApi.playerMatchesCount[player_id] = (player.stats.wins or 0) + (player.stats.loses or 0)
		end

		if player.MutedUntil then
			SyncedChat:MutePlayer(player_id, player.MutedUntil, false)
		end

		if player.kickStats then
			if player.kickStats.kickWarned then
				Kicks:SetWarningForPlayer(player_id)
			end
			if player.kickStats.kickBanned then
				Kicks:SetBanForPlayer(player_id)
			end
		end

		public_stats[player_id] = {
			streak = player.streak.current or 0,
			bestStreak = player.streak.best or 0,
			averageKills = player.stats.kills,
			averageDeaths = player.stats.deaths,
			averageAssists = player.stats.assists,
			wins = player.stats.wins,
			loses = player.stats.loses,
			lastWinnerHeroes = player.stats.lastWinnerHeroes,
			rating = player.rating,
			punishment_level = player.punishment_level,
		}

		SmartRandom:SetPlayerInfo(player_id, player.smartRandomHeroes, "no_stats")
	end

	SeasonReset:SetSeasonDetails(data.current_season or 1, data.next_season_timestamp)
	CustomNetTables:SetTableValue("game_state", "player_stats", public_stats)
	CustomNetTables:SetTableValue("game_state", "player_ratings", data.mapPlayersRating)
	CustomNetTables:SetTableValue("game_state", "leaderboard", data.leaderboard)

	if data.poorWinrates then
		CustomNetTables:SetTableValue("heroes_winrate", "heroes", data.poorWinrates)
		CMegaDotaGameMode.winrates = data.poorWinrates
	end

	Battlepass:OnDataArrival(data)
end


function WebApi:AfterMatch(winnerTeam)
	if not IsInToolsMode() then
		if GameRules:IsCheatMode() then return end
		if GameRules:GetDOTATime(false, true) < 60 then return end
	end

	if winnerTeam < DOTA_TEAM_FIRST or winnerTeam > DOTA_TEAM_CUSTOM_MAX then return end
	if winnerTeam == DOTA_TEAM_NEUTRALS or winnerTeam == DOTA_TEAM_NOTEAM then return end

	local indexed_teams = {
		DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS
	}

	local requestBody = {
		customGame = WebApi.customGame,
		matchId = IsInToolsMode() and RandomInt(1, 10000000) or tonumber(tostring(GameRules:Script_GetMatchID())),
		duration = math.floor(GameRules:GetDOTATime(false, true)),
		mapName = GetMapName(),
		winner = winnerTeam,

		teams = {},
		banned_heroes = GameRules:GetBannedHeroes() or {},
	}

	for _, team in pairs(indexed_teams) do
		local team_data = {
			players = {},
			teamId = team,
			otherTeamsAvgMMR = WebApi:GetOtherTeamsAverageRating(team),
		}
		for n = 1, PlayerResource:GetPlayerCountForTeam(team) do
			local playerId = PlayerResource:GetNthPlayerIDOnTeam(team, n)
			if PlayerResource:IsValidTeamPlayerID(playerId) and not PlayerResource:IsFakeClient(playerId) then
				local player_data = {
					playerId = playerId,
					steamId = tostring(PlayerResource:GetSteamID(playerId)),
					team = team,

					heroName = PlayerResource:GetSelectedHeroName(playerId),
					pickReason = SmartRandom.PickReasons[playerId] or (PlayerResource:HasRandomed(playerId) and "random" or "pick"),
					kills = PlayerResource:GetKills(playerId),
					deaths = PlayerResource:GetDeaths(playerId),
					assists = PlayerResource:GetAssists(playerId),
					perk = GamePerks.choosed_perks[playerId],
					kickAbusedCount = Kicks:GetReports(playerId),
					kickStartedCount = Kicks:GetInitVotings(playerId),
					kickFailedCount = Kicks:GetFailedVotings(playerId),
				}
				table.insert(team_data.players, player_data)
			end
		end
		table.insert(requestBody.teams, team_data)
	end

	if IsInToolsMode() or #requestBody.teams[1].players + #requestBody.teams[2].players >= 5 then
		print("Sending aftermatch request: ", #requestBody.teams[1].players + #requestBody.teams[2].players)

		WebApi:Send(
			"match/after",
			requestBody,
			function(resp)
				print("Successfull after match")
			end,
			function(e)
				print("Error after match: ", e)
			end
		)
	else
		print("Aftermatch send failed: ", #requestBody.teams[1].players + #requestBody.teams[2].players)
	end
end

function WebApi:GetOtherTeamsAverageRating(target_team_number)
	local rating_average = 1500
	local rating_total = 0
	local rating_count = 0

	if IsInToolsMode() then return rating_average end
	if not WebApi.player_ratings then return rating_average end

	for id, ratingMap in pairs(WebApi.player_ratings) do
		if PlayerResource:GetTeam(id) ~= target_team_number then
			rating_total = rating_total + (ratingMap[GetMapName()] or 1500)
			rating_count = rating_count + 1
		end
	end

	if rating_count > 0 then
		rating_average = rating_total / rating_count
	end

	return rating_average
end


function WebApi:ProcessMetadata(player_id, steam_id, metadata)
	if not player_id or not PlayerResource:IsValidPlayerID(player_id) then return end

	if metadata.supporterState then
		Supporters:SetPlayerState(player_id, metadata.supporterState)
		BP_Inventory:UpdateLocalItems(Battlepass.steamid_map[player_id])
		BP_Inventory:UpdateAvailableItems(player_id)
	end

	if metadata.level then
		BP_PlayerProgress.players[steam_id].level = metadata.level
	end

	if metadata.exp then
		BP_PlayerProgress.players[steam_id].current_exp = metadata.exp
		BP_PlayerProgress.players[steam_id].required_exp = metadata.expRequired
	end

	if metadata.purchasedItem then
		BP_Inventory:AddItemLocal(metadata.purchasedItem.itemName, steam_id, metadata.purchasedItem.count)
	end

	if metadata.items then
		for _, item in pairs(metadata.items) do
			BP_Inventory:AddItemLocal(item.itemName, steam_id, item.count or 1, "set")
		end
	end

	if metadata.purchasedCodeDetails then
		GiftCodes:AddCodeForPlayer(player_id, metadata.purchasedCodeDetails)
		GiftCodes:UpdateCodeDataClient(player_id)
	end

	if metadata.gift_codes then
		for _, code in pairs(metadata.gift_codes) do
			GiftCodes:AddCodeForPlayer(player_id, code)
		end
		GiftCodes:UpdateCodeDataClient(player_id)
	end

	if metadata.glory then
		BP_PlayerProgress:ChangeGlory(player_id, metadata.glory - BP_PlayerProgress:GetGlory(player_id))
	end

	if metadata.newRating and metadata.newRating[GetMapName()] then
		local player_stats = CustomNetTables:GetTableValue("game_state", "player_stats");
		if not player_stats then return end

		local player_id_string = tostring(player_id)
		if not player_stats[player_id_string] then return end
		if not player_stats[player_id_string].rating then return end

		player_stats[player_id_string].rating = metadata.newRating[GetMapName()]

		CustomNetTables:SetTableValue("game_state", "player_stats", player_stats)
	end

	BP_PlayerProgress:UpdatePlayerInfo(player_id)
end


--- Returns punishment level of player (usually set from web page)
---@param player_id number
function WebApi:GetPunishmentLevel(player_id)
	local player_stats = CustomNetTables:GetTableValue("game_state", "player_stats")
	return (player_stats[player_id] or {}).punishment_level or 0
end


--- Sets punishment level of player to passed value
--- If `submit_to_backend` is passed and true, then updates said value on backend as well (making it persistant)
---@param player_id number
---@param punishment_level number
---@param punishment_reason string
---@param submit_to_backend boolean
function WebApi:SetPunishmentLevel(player_id, punishment_level, punishment_reason, submit_to_backend)
	local player_stats = CustomNetTables:GetTableValue("game_state", "player_stats")
	if not player_stats[player_id] then player_stats[player_id] = {} end
	player_stats[player_id].punishment_level = punishment_level
	CustomNetTables:SetTableValue("game_state", "player_stats", player_stats)

	if submit_to_backend then
		WebApi:Send(
			"api/lua/match/set_punishment_level",
			{
				steam_id = tostring(PlayerResource:GetSteamID(player_id)),
				punishment_level = punishment_level,
				punishment_reason = punishment_reason or "automated punishment from Lua"
			},
			function(data)
				print("[WebApi] successfully set punishment level for", player_id, "to", punishment_level)
			end,
			function(err)
				print("[WebApi] failed to update punishment level of player", player_id)
			end
		)
	end
end


RegisterGameEventListener("player_connect_full", function()
	print("[WebApi] first player loaded, requesting before-match")
	if WebApi.firstPlayerLoaded then return end
	WebApi.firstPlayerLoaded = true
	WebApi:BeforeMatch()
	MatchEvents:ScheduleNextRequest()
end)

WebApi = WebApi or {}
WebApi.player_settings = WebApi.player_settings or {}

local isTesting = IsInToolsMode() and true or false
for playerId = 0, 23 do
	WebApi.player_settings[playerId] = WebApi.player_settings[playerId] or {}
end
WebApi.matchId = IsInToolsMode() and RandomInt(-10000000, -1) or tonumber(tostring(GameRules:Script_GetMatchID()))

local serverHost = "https://api.12v12.dota2unofficial.com"
local dedicatedServerKey = "Dev_Cookies_7ARiIb78kJJWPLlSW4U2A"
-- local dedicatedServerKey = GetDedicatedServerKeyV2("1")

function WebApi:Send(path, data, onSuccess, onError, retryWhile)
	local request = CreateHTTPRequestScriptVM("POST", serverHost .. "/api/lua/" .. path)
	if isTesting then
		print("Request to " .. path)
		DeepPrintTable(data)
	end

	request:SetHTTPRequestHeaderValue("Dedicated-Server-Key", dedicatedServerKey)
	if data ~= nil then
		data.customGame = WebApi.customGame
		request:SetHTTPRequestRawPostBody("application/json", json.encode(data))
	end

	request:Send(function(response)
		if response.StatusCode >= 200 and response.StatusCode < 300 then
			local data = json.decode(response.Body)
			if isTesting then
				print("Response from  " .. path .. ":")
				DeepPrintTable(data)
			end
			if onSuccess then
				onSuccess(data)
			end
		else
			local err = json.decode(response.Body)
			if type(err) ~= "table" then err = {} end

			if isTesting then
				print("Error from " .. path .. ": " .. response.StatusCode)
				if response.Body then
					local status, result = pcall(json.decode, response.Body)
					if status then
						DeepPrintTable(result)
					else
						print(response.Body)
					end
				end
			end

			local message = (response.StatusCode == 0 and "Could not establish connection to the server. Please try again later.") or err.title or "Unknown error."
			if err.traceId then
				message = message .. " Report it to the developer with this id: " .. err.traceId
			end

			err.message = message
			err.status_code = response.StatusCode

			if response.Body and type(response.Body) == "string" then
				err.body = response.Body
			end

			if retryWhile and retryWhile(err) then
				WebApi:Send(path, data, onSuccess, onError, retryWhile)
			elseif onError then
				onError(err)
			end
		end
	end)
end

local function retryTimes(times)
	return function()
		times = times - 1
		return times >= 0
	end
end

function WebApi:BeforeMatch()
	-- TODO: Smart random Init, patreon init, nettables init
	local players = {}
	for playerId = 0, 23 do
		if PlayerResource:IsValidPlayerID(playerId) then
			table.insert(players, tostring(PlayerResource:GetSteamID(playerId)))
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
			print("BEFORE MATCH")
			WebApi.player_ratings = {}
			WebApi.patch_notes = data.patchnotes
			publicStats = {}
			WebApi.playerMatchesCount = {}
			for _, player in ipairs(data.players) do
				local playerId = GetPlayerIdBySteamId(player.steamId)
				if player.rating then
					WebApi.player_ratings[playerId] = {[GetMapName()] = player.rating}
				end
				if player.supporterState then
					Supporters:SetPlayerState(playerId, player.supporterState)
				end
				if player.masteries then
					BP_Masteries:SetMasteriesForPlayer(playerId, player.masteries)
				end

				if player.gift_codes then
					GiftCodes:SetCodesForPlayer(playerId, player.gift_codes)
				end

				if player.mails then
					WebMail:SetPlayerMails(playerId, player.mails)
				end

				if player.settings then
					WebApi.player_settings[playerId] = player.settings
					CustomNetTables:SetTableValue("player_settings", tostring(playerId), player.settings)
				end
				if player.stats then
					WebApi.playerMatchesCount[playerId] = (player.stats.wins or 0) + (player.stats.loses or 0)
				end
				if player.MutedUntil then
					SyncedChat:MutePlayer(playerId, player.MutedUntil, false)
				end
				if player.kickStats then
					if player.kickStats.kickWarned then
						Kicks:SetWarningForPlayer(playerId)
					end
					if player.kickStats.kickBanned then
						Kicks:SetBanForPlayer(playerId)
					end
				end
				publicStats[playerId] = {
					streak = player.streak.current or 0,
					bestStreak = player.streak.best or 0,
					averageKills = player.stats.kills,
					averageDeaths = player.stats.deaths,
					averageAssists = player.stats.assists,
					wins = player.stats.wins,
					loses = player.stats.loses,
					lastWinnerHeroes = player.stats.lastWinnerHeroes,
					rating = player.rating,
				}
				SmartRandom:SetPlayerInfo(playerId, player.smartRandomHeroes, "no_stats")
			end
			CustomNetTables:SetTableValue("game_state", "player_stats", publicStats)
			CustomNetTables:SetTableValue("game_state", "player_ratings", data.mapPlayersRating)
			CustomNetTables:SetTableValue("game_state", "leaderboard", data.leaderboard)

			if data.poorWinrates then
				CustomNetTables:SetTableValue("heroes_winrate", "heroes", data.poorWinrates)
				CMegaDotaGameMode.winrates = data.poorWinrates
			end

			Battlepass:OnDataArrival(data)
		end,
		function(err)
			print(err.message)
		end,
		retryTimes(2)
	)
end

WebApi.scheduledUpdateSettingsPlayers = WebApi.scheduledUpdateSettingsPlayers or {}
function WebApi:ScheduleUpdateSettings(playerId)
	WebApi.scheduledUpdateSettingsPlayers[playerId] = true

	if WebApi.updateSettingsTimer then Timers:RemoveTimer(WebApi.updateSettingsTimer) end
	WebApi.updateSettingsTimer = Timers:CreateTimer(10, function()
		WebApi.updateSettingsTimer = nil
		WebApi:ForceSaveSettings()
		WebApi.scheduledUpdateSettingsPlayers = {}
	end)
end

function WebApi:ForceSaveSettings(_playerId)
	local players = {}
	for playerId = 0, 23 do
		if PlayerResource:IsValidPlayerID(playerId) and (WebApi.scheduledUpdateSettingsPlayers[playerId] or _playerId == playerId) then
			local settings = WebApi.player_settings[playerId]
			if next(settings) ~= nil then
				local steamId = tostring(PlayerResource:GetSteamID(playerId))
				table.insert(players, { steamId = steamId, settings = settings })
			end
		end
	end
	WebApi:Send("match/update-settings", { players = players })
end

function WebApi:AfterMatch(winnerTeam)
	if not isTesting then
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
		matchId = isTesting and RandomInt(1, 10000000) or tonumber(tostring(GameRules:Script_GetMatchID())),
		duration = math.floor(GameRules:GetDOTATime(false, true)),
		mapName = GetMapName(),
		winner = winnerTeam,

		teams = {},
		timers = Timers._badPerformanceTimers,
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

	if isTesting or #requestBody.teams[1].players + #requestBody.teams[2].players >= 5 then
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

function WebApi:GetOtherPlayersAverageRating(player_id)
	local rating_average = 1500
	local rating_total = 0
	local rating_count = 0

	if IsInToolsMode() then return rating_average end

	for id, ratingMap in pairs(WebApi.player_ratings or {}) do
		if id ~= player_id then
			rating_total = rating_total + (ratingMap[mapName] or 1500)
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
		local playersStats = CustomNetTables:GetTableValue("game_state", "player_stats");
		if not playersStats then return end

		local player_id_string = tostring(player_id)
		if not playersStats[player_id_string] then return end
		if not playersStats[player_id_string].rating then return end

		playersStats[player_id_string].rating = metadata.newRating[GetMapName()]

		CustomNetTables:SetTableValue("game_state", "player_stats", playersStats)
	end

	BP_PlayerProgress:UpdatePlayerInfo(player_id)
end


RegisterGameEventListener("player_connect_full", function()
	print("LOADED WEBAPI")
	if WebApi.firstPlayerLoaded then return end
	WebApi.firstPlayerLoaded = true
	WebApi:BeforeMatch()
	MatchEvents:ScheduleNextRequest()
end)

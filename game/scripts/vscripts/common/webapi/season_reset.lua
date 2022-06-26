SeasonReset = SeasonReset or {}


function SeasonReset:Init()
	SeasonReset.player_status = {}
	SeasonReset.current_season = 1

	RegisterCustomEventListener("SeasonReset:get_status", SeasonReset.SendStatus, SeasonReset)
end


function SeasonReset:SetStatus(player_id, status)
	SeasonReset.player_status[player_id] = status
end


function SeasonReset:SetSeasonDetails(season, next_season_timestamp)
	SeasonReset.current_season = season
	SeasonReset.next_season_timestamp = next_season_timestamp
end


function SeasonReset:SendStatus(event)
	print("[SeasonReset] status requested")
	local player_id = event.PlayerID
	if not player_id or not PlayerResource:IsValidPlayerID(player_id) then print(1) return end

	local player = PlayerResource:GetPlayer(player_id)
	if not player or player:IsNull() then print(2) return end

	local stats = CustomNetTables:GetTableValue("game_state", "player_stats")
	local player_stats = stats[tostring(player_id)] or {}

	CustomGameEventManager:Send_ServerToPlayer(player, "SeasonReset:set_status", {
		status = SeasonReset.player_status[player_id] or false,
		season = SeasonReset.current_season,
		new_rating = player_stats.rating or 1500,
		next_season_timestamp = SeasonReset.next_season_timestamp or 0
	})
end


SeasonReset:Init()

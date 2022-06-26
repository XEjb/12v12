WebApi.player_settings = WebApi.player_settings or {}
WebApi.scheduled_players = WebApi.scheduled_players or {}
WebApi.settings_update_timer = nil

SETTINGS_UPDATE_DELAY = IsInToolsMode() and 5 or 20


for player_id = 0, 23 do
	WebApi.player_settings[player_id] = WebApi.player_settings[player_id] or {}
end


function WebApi:ScheduleSettingsUpdate(player_id)
	WebApi.scheduled_players[player_id] = true

	CustomNetTables:SetTableValue("player_settings", tostring(player_id), WebApi.player_settings[player_id] or {})

	if WebApi.settings_update_timer then Timers:RemoveTimer(WebApi.settings_update_timer) end

	WebApi.settings_update_timer = Timers:CreateTimer(SETTINGS_UPDATE_DELAY, function()
		WebApi.settings_update_timer = nil
		WebApi:CommitSettings()
		WebApi.scheduled_players = {}
	end)
end


function WebApi:CommitSettings()
	local players = {}

	for player_id, _ in pairs(WebApi.scheduled_players or {}) do
		local settings = WebApi.player_settings[player_id]
		local steam_id = tostring(PlayerResource:GetSteamID(player_id))

		if PlayerResource:IsValidPlayerID(player_id) and settings and next(settings) ~= nil then
			table.insert(players, {
				steamId = steam_id,
				settings = settings
			})
		end
	end

	if players then
		WebApi:Send("match/update-settings", { players = players })
	end
end

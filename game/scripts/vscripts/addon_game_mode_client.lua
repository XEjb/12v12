if IsClient() then 
	require("client_util")

	local function AutoAttack(event)
		print("Auto attack setting: Value", event.value, "summon: ", event.summon)
		SendToConsole("dota_player_units_auto_attack_mode " .. event.value)
		SendToConsole("dota_summoned_units_auto_attack_mode_2 " .. event.summon)
	end
	ListenToGameEvent("auto_attack_setting", function(event) AutoAttack(event) end, nil)
end
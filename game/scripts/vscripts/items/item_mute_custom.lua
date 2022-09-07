function OnSpellStartMute(event)
	local target = event.target
	local caster = event.caster
	local ability = event.ability

	CustomGameEventManager:Send_ServerToPlayer(caster:GetPlayerOwner(), "mute_player_item", { target_id = target:GetPlayerID() } )
	if ability:GetCurrentCharges() > 1 then
		ability:SetCurrentCharges(ability:GetCurrentCharges()-1)
	else
		ability:RemoveSelf()
	end
end

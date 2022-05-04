modifier_global_dummy_custom = class({})

function modifier_global_dummy_custom:IsHidden()
	return false
end

function modifier_global_dummy_custom:CheckState()
	local state = {
		[MODIFIER_STATE_UNSELECTABLE] = true,
		[MODIFIER_STATE_NOT_ON_MINIMAP] = true,
		[MODIFIER_STATE_ATTACK_IMMUNE] = true,
		[MODIFIER_STATE_MAGIC_IMMUNE] = true,
		[MODIFIER_STATE_NO_HEALTH_BAR] = true,
		[MODIFIER_STATE_INVULNERABLE] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
		[MODIFIER_STATE_DISARMED] = true,
		[MODIFIER_STATE_OUT_OF_GAME] = true,
		[MODIFIER_STATE_INVISIBLE] = true,
	}
	return state
end

function modifier_global_dummy_custom:GetModifierInvisibilityLevel()
	return 4
end

function modifier_global_dummy_custom:DeclareFunctions()
	return { MODIFIER_EVENT_ON_TAKEDAMAGE }
end

function modifier_global_dummy_custom:OnTakeDamage(event)
	if not IsServer() then return end
	if event.damage <= 0 then return end
	local target = event.unit
	if not target or target:IsNull() or not target:IsRealHero() or target:IsIllusion() then return end

	local target_id = target.GetPlayerOwnerID and target:GetPlayerOwnerID()
	if not target_id or not CUSTOM_GAME_STATS[target_id] then return end
	
	CUSTOM_GAME_STATS[target_id].damage_taken = CUSTOM_GAME_STATS[target_id].damage_taken + event.original_damage
end


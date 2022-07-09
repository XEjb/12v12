modifier_weak_team_bonus = class({})

--------------------------------------------------------------------------------
function modifier_weak_team_bonus:IsHidden()
	return false
end
--------------------------------------------------------------------------------
function modifier_weak_team_bonus:GetTexture()
	return "mmr_balance"
end
--------------------------------------------------------------------------------
function modifier_weak_team_bonus:IsPurgable()
	return false
end
--------------------------------------------------------------------------------
function modifier_weak_team_bonus:DestroyOnExpire()
	return false
end
--------------------------------------------------------------------------------
function modifier_weak_team_bonus:RemoveOnDeath()
	return false
end
--------------------------------------------------------------------------------
function modifier_weak_team_bonus:OnCreated(params)
	if not IsServer() then return end

	self.weak_team_bonus_pct = params.weak_team_bonus_pct
end
--------------------------------------------------------------------------------
function modifier_weak_team_bonus:DeclareFunctions()
	if not IsServer() then return end

	return {
		MODIFIER_PROPERTY_EXP_RATE_BOOST, -- GetModifierPercentageExpRateBoost
	}
end
--------------------------------------------------------------------------------
function modifier_weak_team_bonus:GetModifierPercentageExpRateBoost(params)
	return self.weak_team_bonus_pct
end
--------------------------------------------------------------------------------

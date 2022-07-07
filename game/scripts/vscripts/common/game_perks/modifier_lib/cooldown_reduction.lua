require("common/game_perks/base_game_perk")

cooldown_reduction = class(base_game_perk)

local exceptions = {
	dark_willow_shadow_realm = true
}

function cooldown_reduction:DeclareFunctions() return { MODIFIER_PROPERTY_COOLDOWN_PERCENTAGE } end
function cooldown_reduction:GetTexture() return "perkIcons/cooldown_reduction" end

function cooldown_reduction:GetModifierPercentageCooldown(params) 
	if not exceptions[params.ability:GetAbilityName()] then
		return self.v 
	end
end

cooldown_reduction_t0 = class(cooldown_reduction)
cooldown_reduction_t1 = class(cooldown_reduction)
cooldown_reduction_t2 = class(cooldown_reduction)
cooldown_reduction_t3 = class(cooldown_reduction)

function cooldown_reduction_t0:OnCreated() self.v = 5 end
function cooldown_reduction_t1:OnCreated() self.v = 10 end
function cooldown_reduction_t2:OnCreated() self.v = 18 end
function cooldown_reduction_t3:OnCreated() self.v = 30 end

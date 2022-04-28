require("common/game_perks/base_game_perk")

outcomming_heal_amplify = class(base_game_perk)

function outcomming_heal_amplify:DeclareFunctions() 
	return { 
		MODIFIER_PROPERTY_HEAL_AMPLIFY_PERCENTAGE_SOURCE,
		MODIFIER_PROPERTY_LIFESTEAL_AMPLIFY_PERCENTAGE,
		MODIFIER_PROPERTY_SPELL_LIFESTEAL_AMPLIFY_PERCENTAGE,
		MODIFIER_PROPERTY_HP_REGEN_AMPLIFY_PERCENTAGE,
	} 
end
function outcomming_heal_amplify:GetTexture() return "perkIcons/outcomming_heal_amplify" end

function outcomming_heal_amplify:GetModifierHealAmplify_PercentageSource() 
	return self.v 
end

function outcomming_heal_amplify:GetModifierLifestealRegenAmplify_Percentage() 
	return self.v 
end

function outcomming_heal_amplify:GetModifierSpellLifestealRegenAmplify_Percentage() 
	return self.v 
end

function outcomming_heal_amplify:GetModifierHPRegenAmplify_Percentage() 
	return self.v 
end

outcomming_heal_amplify_t0 = class(outcomming_heal_amplify)
outcomming_heal_amplify_t1 = class(outcomming_heal_amplify)
outcomming_heal_amplify_t2 = class(outcomming_heal_amplify)
outcomming_heal_amplify_t3 = class(outcomming_heal_amplify)

function outcomming_heal_amplify_t0:OnCreated() self.v = 7.5 end
function outcomming_heal_amplify_t1:OnCreated() self.v = 15 end
function outcomming_heal_amplify_t2:OnCreated() self.v = 30 end
function outcomming_heal_amplify_t3:OnCreated() self.v = 60 end

item_tome_of_knowledge_lua = item_tome_of_knowledge_lua or class({})

function item_tome_of_knowledge_lua:OnSpellStart()
	local caster = self:GetCaster()

	local minute = math.floor(GameRules:GetDOTATime(false, false) / 60)
	local exp = self:GetSpecialValueFor("xp_bonus") + minute * self:GetSpecialValueFor("xp_per_minute")

	caster:AddExperience(exp, DOTA_ModifyXP_TomeOfKnowledge, false, true)
	self:SpendCharge()
end

item_tome_of_knowledge_lua = item_tome_of_knowledge_lua or class({})

function item_tome_of_knowledge_lua:OnSpellStart()
	local caster = self:GetCaster()

	local ten_minutes = math.floor(GameRules:GetDOTATime(false, false) / 600)
	local exp = self:GetSpecialValueFor("xp_bonus") + ten_minutes * self:GetSpecialValueFor("xp_per_ten_minutes")

	caster:AddExperience(exp, DOTA_ModifyXP_TomeOfKnowledge, false, true)
	self:SpendCharge()
end

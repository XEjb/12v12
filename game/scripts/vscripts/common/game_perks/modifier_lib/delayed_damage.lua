TICK_RATE = 0.25
require("common/game_perks/base_game_perk")

MODIFIERS_BLACK_LIST_FOR_APPLY_DELAYED_DAMAGE = {
	["modifier_skeleton_king_reincarnation_scepter_active"] = true,
}

delayed_damage = class(base_game_perk)
function delayed_damage:GetTexture() return "perkIcons/delayed_damage" end
function delayed_damage:OnIntervalThink()
	if not IsServer() then return end
	local parent = self:GetParent()
	
	for _modifier_name, _ in pairs(MODIFIERS_BLACK_LIST_FOR_APPLY_DELAYED_DAMAGE) do
		if parent:HasModifier(_modifier_name) then return end
	end
	
	local damage_stacks = self:GetParent():FindAllModifiersByName("modifier_delayed_damage")
	
	for _, mod in pairs(damage_stacks) do
		mod:SetStackCount(mod:GetStackCount() - mod.damage_per_tick)
		ApplyDamage({
			victim = parent,
			attacker = mod.attacker,
			damage = mod.damage_per_tick,
			damage_type = mod.damage_type,
			damage_flags = DOTA_DAMAGE_FLAG_BYPASSES_BLOCK + DOTA_DAMAGE_FLAG_HPLOSS + DOTA_DAMAGE_FLAG_NO_DAMAGE_MULTIPLIERS + DOTA_DAMAGE_FLAG_NON_LETHAL,
			ability = parent.delay_ability,
		})
	end
end
delayed_damage.OnCreated = function(self)
	if not IsServer() then return end

	local parent = self:GetParent()

	if not parent:IsRealHero() then return end

	parent.delay_damage_by_perk = self.v[1]
	parent.delay_damage_by_perk_duration = self.v[2]
	parent.delay_ability = parent:AddAbility("delayed_damage_perk")
	parent.delay_ability:SetLevel(1)
	self:StartIntervalThink(TICK_RATE)
end

delayed_damage_t0 = class(delayed_damage) 
delayed_damage_t0.v = {14, 6}
delayed_damage_t1 = class(delayed_damage) 
delayed_damage_t1.v = {25, 6}
delayed_damage_t2 = class(delayed_damage) 
delayed_damage_t2.v = {40, 6}
delayed_damage_t3 = class(delayed_damage)
delayed_damage_t3.v = {57, 6}

modifier_delayed_damage = class(base_game_perk)
function modifier_delayed_damage:GetAttributes() return MODIFIER_ATTRIBUTE_MULTIPLE end
function modifier_delayed_damage:GetTexture() return "perkIcons/delayed_damage" end
function modifier_delayed_damage:RemoveOnDeath() return true end
function modifier_delayed_damage:IsHidden() return true end
function modifier_delayed_damage:OnCreated(params)
	if not IsServer() then return end


	local parent = self:GetParent()
	for _modifier_name, _ in pairs(MODIFIERS_BLACK_LIST_FOR_APPLY_DELAYED_DAMAGE) do
		if parent:HasModifier(_modifier_name) then
			self:Destroy()
			return
		end
	end

	self.attacker = EntIndexToHScript(params.attacker_ent)
	self.damage_type = params.damage_type
	local damage = params.damage
	self.damage_per_tick = damage / params.duration * TICK_RATE

	self:SetStackCount(damage)
end
delayed_damage_perk = delayed_damage_perk or class({})

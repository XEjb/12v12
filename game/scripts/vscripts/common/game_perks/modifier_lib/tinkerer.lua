require("common/game_perks/base_game_perk")

local ignored_special_values = {
	item_eye_of_midas 			= {active_cooldown = true},
	item_witless_shako 			= {max_mana = true},
	item_spell_prism 			= {bonus_cooldown = true},
	item_spell_fractal 			= {bonus_cooldown = true},
	item_quickening_charm 		= {bonus_cooldown = true},
	item_force_boots 			= {push_duration = true},
	item_mirror_shield 			= {block_cooldown = true},
	item_fallen_sky 			= {land_time = true, burn_interval = true},
	item_bullwhip 				= {bullwhip_delay_time = true},
	item_stormcrafter 			= {interval = true},
	item_teleports_behind_you 	= {meteor_fall_time = true, blink_damage_cooldown = true},

	item_nether_shawl 	= {bonus_armor = true },
	item_ninja_gear 	= {visibility_radius = true },
	item_misericorde 	= {missing_hp = true },
	item_spy_gadget		= {scan_cooldown_reduction = true},
}

local ignored_special_values_common = {
	AbilityCooldown = true,
	AbilityManaCost = true,
	AbilityChannelTime = true,
	AbilityCharges = true,
}

tinkerer = class(base_game_perk)
function tinkerer:GetTexture() return "perkIcons/tinkerer" end
function tinkerer:GetAttributes() return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE end
function tinkerer:DeclareFunctions() return { MODIFIER_PROPERTY_OVERRIDE_ABILITY_SPECIAL, MODIFIER_PROPERTY_OVERRIDE_ABILITY_SPECIAL_VALUE, MODIFIER_EVENT_ON_ATTACK_LANDED } end

local neutral_list = {}

local neutralItemKV = LoadKeyValues("scripts/npc/neutral_items.txt")
for _, levelData in pairs(neutralItemKV) do
	if levelData and type(levelData) == "table" then
		for key,data in pairs(levelData) do
			if key =="items" then
				for k,_ in pairs(data) do
					neutral_list[k] = true
				end
			end
		end
	end
end

function tinkerer:_OverrideAbilitySpecialCallback(keys, base_value, inc_callback)
	local ability_name = keys.ability:GetAbilityName()
	if keys.ability and neutral_list and neutral_list[ability_name] and
		not ignored_special_values_common[keys.ability_special_value] and
		not (ignored_special_values[ability_name] and ignored_special_values[ability_name][keys.ability_special_value]) then
		return inc_callback(base_value)
	end
	return base_value
end

function tinkerer:GetModifierOverrideAbilitySpecial(keys)
	return self:_OverrideAbilitySpecialCallback(keys, 0, function(_) return 1 end)
end

function tinkerer:GetModifierOverrideAbilitySpecialValue(keys)
	local value = keys.ability:GetLevelSpecialValueNoOverride(keys.ability_special_value, keys.ability_special_level)
	return self:_OverrideAbilitySpecialCallback(keys, value, function(_) return _ * (self.v or 1) end)
end

function tinkerer:OnAttackLanded(keys)
	if not IsServer() then return end

	local parent = self:GetParent()
	if parent ~= keys.attacker then return end
	if not parent:HasModifier("modifier_item_heavy_blade") then return end
	
	local target = keys.target

	if parent:IsRealHero() and parent:GetTeam() ~= target:GetTeam() and target.GetMaxMana and target:GetMaxMana() and target:GetMaxMana() > 1 then
		local damage = target:GetMaxMana() * 0.04 * (self.v - 1)
		ApplyDamage({
			victim = target, 
			attacker = parent, 
			damage = damage, 
			damage_type = DAMAGE_TYPE_MAGICAL, 
			damage_flags = DOTA_DAMAGE_FLAG_NO_SPELL_AMPLIFICATION
		})
		SendOverheadEventMessage(nil, OVERHEAD_ALERT_BONUS_SPELL_DAMAGE, target, damage, nil)
	end
end

tinkerer_t0 = class(tinkerer)
tinkerer_t0.v = 1.25
tinkerer_t1 = class(tinkerer)
tinkerer_t1.v = 1.50
tinkerer_t2 = class(tinkerer)
tinkerer_t2.v = 2.00
tinkerer_t3 = class(tinkerer)
tinkerer_t3.v = 3.00

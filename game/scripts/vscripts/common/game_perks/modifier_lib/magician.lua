require("common/game_perks/base_game_perk")

magician = class(base_game_perk)
local aoe_keywords = {
	aoe = true,
	area_of_effect = true,
	radius = true,
}

local other_keywords = {
	scepter_range = true,
	arrow_range_multiplier = true,
	wave_width = true,
	agility_range = true,
	aftershock_range = true,
	echo_slam_damage_range = true,
	echo_slam_echo_search_range = true,
	echo_slam_echo_range = true,
	torrent_max_distance = true,
	cleave_ending_width = true,
	cleave_distance = true,
	ghostship_width = true,
	dragon_slave_distance = true,
	dragon_slave_width_initial = true,
	dragon_slave_width_end = true,
	width = true,
	arrow_width = true,
	requiem_line_width_start = true,
	requiem_line_width_end = true,
	orb_vision = true,
	hook_distance = true,
	flesh_heap_range = true,
	hook_width = true,
	end_distance = true,
	burrow_width = true,
	splash_width = true,
	splash_range = true,
	arrow_width = true,
	jump_range = true,
	bounce_range = true,
	attack_spill_range = true,
	attack_spill_width = true,
	range = true,
}

local other_key_by_abilities = {
	range = {
		terrorblade_reflection = true,
	}
}

local ignore_abilities = {
	phantom_assassin_blur = true,
	spectre_desolate = true,
}

function magician:GetTexture() return "perkIcons/magician" end
function magician:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_OVERRIDE_ABILITY_SPECIAL,
		MODIFIER_PROPERTY_OVERRIDE_ABILITY_SPECIAL_VALUE
	}
end

local aoe_keywords_check = {}
for s_name,_ in pairs(aoe_keywords) do
	aoe_keywords_check[s_name] = true
end
for s_name,_ in pairs(other_keywords) do
	aoe_keywords_check[s_name] = true
end

local dotas_abilities = LoadKeyValues("scripts/npc/npc_abilities.txt")
talents_amplify = {}

for _, ability_data in pairs(dotas_abilities) do
	if ability_data and type(ability_data) == "table" and ability_data.AbilitySpecial then
		for _, special_data in pairs(ability_data.AbilitySpecial) do
			if special_data and type(special_data) == "table" then
				local b_data_has_aoe = false

				for special_name, _ in pairs(special_data) do
					if aoe_keywords_check[special_name] then
						b_data_has_aoe = true
					end
				end
				if b_data_has_aoe and special_data.LinkedSpecialBonus then
					talents_amplify[special_data.LinkedSpecialBonus] = true
				end
			end
		end
	end
end


function magician:GetModifierOverrideAbilitySpecial(keys)
	if (not keys.ability) or (not keys.ability_special_value) or (not aoe_keywords) then return 0 end

	local ability_name = keys.ability:GetAbilityName()

	if ignore_abilities[ability_name] then return end

	for keyword, _ in pairs(aoe_keywords) do
		if string.find(keys.ability_special_value, keyword) then
			return 1
		end
	end

	if (not other_key_by_abilities[keys.ability_special_value] or other_key_by_abilities[keys.ability_special_value][ability_name]) 
		and (other_keywords and other_keywords[keys.ability_special_value]) then
		return 1
	end

	if talents_amplify[ability_name] and keys.ability_special_value == "value" then
		return 1
	end

	return 0
end

function magician:GetModifierOverrideAbilitySpecialValue(keys)
	local value = keys.ability:GetLevelSpecialValueNoOverride(keys.ability_special_value, keys.ability_special_level)
	local ability_name = keys.ability.GetAbilityName and keys.ability:GetAbilityName()
	
	for keyword, _ in pairs(aoe_keywords) do
		if string.find(keys.ability_special_value, keyword) then
			return value * (self.v or 1)
		end
	end

	if (not ability_name or not other_key_by_abilities[keys.ability_special_value] or other_key_by_abilities[keys.ability_special_value][ability_name]) and 
		(other_keywords and other_keywords[keys.ability_special_value]) then
		return value * (self.v or 1)
	end

	if ability_name and talents_amplify[ability_name] and keys.ability_special_value == "value" then
		return value * (self.v or 1)
	end
	
	return value
end

magician_t0 = class(magician)
magician_t1 = class(magician)
magician_t2 = class(magician)
magician_t3 = class(magician)

function magician_t0:OnCreated() self.v = 1.05 end
function magician_t1:OnCreated() self.v = 1.1 end
function magician_t2:OnCreated() self.v = 1.2 end
function magician_t3:OnCreated() self.v = 1.4 end

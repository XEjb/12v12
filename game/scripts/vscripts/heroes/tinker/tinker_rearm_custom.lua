tinker_rearm_custom = tinker_rearm_custom or class({})
LinkLuaModifier("modifier_tinker_rearm_custom", 'heroes/tinker/modifier_tinker_rearm_custom', LUA_MODIFIER_MOTION_NONE)

local rearm_black_list = {
	--[[ From default Rearm description ]]--
	["item_aeon_disk"] = true,
	["item_arcane_boots"] = true,
	["item_black_king_bar"] = true,
	["item_hand_of_midas"] = true,
	["item_helm_of_the_dominator"] = true,
	["item_sphere"] = true,
	["item_meteor_hammer"] = true,
	["item_necronomicon"] = true,
	["item_necronomicon_2"] = true,
	["item_necronomicon_3"] = true,
	["item_pipe"] = true,
	["item_tome_of_knowledge"] = true,
	["item_refresher"] = true,
	--[[ Still default black list, but not published in description ]]--
	["item_helm_of_the_overlord"] = true,
	--[[ Custom list ]]--
	["item_teleport_perk_0"] = true,
	["item_teleport_perk_1"] = true,
	["item_teleport_perk_2"] = true,
	["item_teleport_perk_3"] = true,
}

function tinker_rearm_custom:IsStealable() return false end

function tinker_rearm_custom:OnSpellStart()
	local caster = self:GetCaster()
	if not caster or caster:IsNull() then return end

	caster:AddNewModifier(caster, self, "modifier_tinker_rearm_custom", { duration = self:GetChannelTime() })
end

function tinker_rearm_custom:OnChannelFinish(bInterrupted)
	local caster = self:GetCaster()
	caster:RemoveModifierByName("modifier_tinker_rearm_custom")
	if not bInterrupted then
		local refresh = function(func, min_idx, max_idx)
			for ent_idx = min_idx, max_idx do
				local ent = caster[func](caster, ent_idx)
				if ent and not ent:IsNull() and not rearm_black_list[ent:GetAbilityName() or ""] then
					ent:EndCooldown()
				end
			end
		end
		refresh("GetItemInSlot", DOTA_ITEM_SLOT_1, DOTA_ITEM_SLOT_9)
		refresh("GetAbilityByIndex", 0, 5)
	else
		caster:FadeGesture(_G["ACT_DOTA_TINKER_REARM" .. self:GetLevel()])
	end
end

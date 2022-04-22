require("common/game_perks/base_game_perk")

agi_for_kill = class(base_game_perk)

function agi_for_kill:OnCreated(kv)
	if IsClient() then return end

	local parent = self:GetParent()

	if not parent:IsRealHero() and not parent:IsClone() then
		local hero = PlayerResource:GetSelectedHeroEntity(parent:GetPlayerOwnerID())

		self:SetStackCount(hero:GetModifierStackCount(self:GetName(), hero))
	end
end

function agi_for_kill:DeclareFunctions() return { MODIFIER_PROPERTY_STATS_AGILITY_BONUS, MODIFIER_EVENT_ON_HERO_KILLED } end

function agi_for_kill:OnHeroKilled(keys)
	if not IsServer() then return end
	local killerID = keys.attacker:GetPlayerOwnerID()
	
	if killerID and killerID == self:GetParent():GetPlayerOwnerID() and keys.target:GetTeam() ~= self:GetParent():GetTeam() then
		self:IncrementStackCount()
		self:GetParent():CalculateStatBonus(false)
	end
end
function agi_for_kill:GetTexture() return "perkIcons/agi_for_kill" end

function agi_for_kill:GetModifierBonusStats_Agility()
	if IsServer() and self:GetParent():IsClone() then return end
	return math.floor(self.v * self:GetStackCount())
end

agi_for_kill_t0 = class(agi_for_kill)
agi_for_kill_t1 = class(agi_for_kill)
agi_for_kill_t2 = class(agi_for_kill)
agi_for_kill_t3 = class(agi_for_kill)

agi_for_kill_t0.v = 0.8
agi_for_kill_t1.v = 1.6
agi_for_kill_t2.v = 3.2
agi_for_kill_t3.v = 6.4

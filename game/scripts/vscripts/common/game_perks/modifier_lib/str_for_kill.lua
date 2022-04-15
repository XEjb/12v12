require("common/game_perks/base_game_perk")

str_for_kill = class(base_game_perk)

function str_for_kill:OnCreated(kv)
	if IsClient() then return end

	local parent = self:GetParent()

	if not parent:IsRealHero() then
		local hero = PlayerResource:GetSelectedHeroEntity(parent:GetPlayerOwnerID())

		self:SetStackCount(hero:GetModifierStackCount(self:GetName(), hero))
	end
end

function str_for_kill:DeclareFunctions() return { MODIFIER_PROPERTY_STATS_STRENGTH_BONUS, MODIFIER_EVENT_ON_HERO_KILLED } end

function str_for_kill:OnHeroKilled(keys)
	if not IsServer() then return end
	local killerID = keys.attacker:GetPlayerOwnerID()
	
	if killerID and killerID == self:GetParent():GetPlayerOwnerID() and keys.target:GetTeam() ~= self:GetParent():GetTeam() then
		self:IncrementStackCount()
		self:GetParent():CalculateStatBonus(false)
	end
end
function str_for_kill:GetTexture() return "perkIcons/str_for_kill" end

function str_for_kill:GetModifierBonusStats_Strength()
	if self:GetParent():IsClone() then return end
	return math.floor(self.v * self:GetStackCount())
end

str_for_kill_t0 = class(str_for_kill)
str_for_kill_t1 = class(str_for_kill)
str_for_kill_t2 = class(str_for_kill)
str_for_kill_t3 = class(str_for_kill)

str_for_kill_t0.v = 1
str_for_kill_t1.v = 2
str_for_kill_t2.v = 4
str_for_kill_t3.v = 8

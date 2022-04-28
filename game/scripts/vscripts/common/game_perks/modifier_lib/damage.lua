require("common/game_perks/base_game_perk")

damage = class(base_game_perk)

function damage:DeclareFunctions() return { MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE } end
function damage:GetTexture() return "perkIcons/damage" end
function damage:GetModifierPreAttack_BonusDamage()
	return self:GetPerkValue(self.v[1], self.v[2], self.v[3])
end

damage_t0 = class(damage)
damage_t1 = class(damage)
damage_t2 = class(damage)
damage_t3 = class(damage)

function damage_t0:OnCreated() self.v = {6, 1, 0.6} end
function damage_t1:OnCreated() self.v = {12, 1, 1.2} end
function damage_t2:OnCreated() self.v = {24, 1, 2.4} end
function damage_t3:OnCreated() self.v = {48, 1, 4.8} end

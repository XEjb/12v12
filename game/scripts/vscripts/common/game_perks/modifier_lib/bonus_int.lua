require("common/game_perks/base_game_perk")

bonus_int = class(base_game_perk)

function bonus_int:DeclareFunctions() return { MODIFIER_PROPERTY_STATS_INTELLECT_BONUS } end
function bonus_int:GetTexture() return "perkIcons/bonus_int" end
function bonus_int:GetModifierBonusStats_Intellect()
	return self:GetPerkValue(self.v[1], self.v[2], self.v[3])
end

bonus_int_t0 = class(bonus_int)
bonus_int_t1 = class(bonus_int)
bonus_int_t2 = class(bonus_int)
bonus_int_t3 = class(bonus_int)

function bonus_int_t0:OnCreated() self.v = {0, 1, 0.6} end
function bonus_int_t1:OnCreated() self.v = {0, 1, 1.2} end
function bonus_int_t2:OnCreated() self.v = {0, 1, 2.4} end
function bonus_int_t3:OnCreated() self.v = {0, 1, 4.8} end

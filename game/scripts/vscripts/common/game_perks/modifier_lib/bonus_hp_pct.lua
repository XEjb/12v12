require("common/game_perks/base_game_perk")

bonus_hp_pct = class(base_game_perk)

function bonus_hp_pct:DeclareFunctions() return { MODIFIER_PROPERTY_HEALTH_BONUS  } end
function bonus_hp_pct:GetTexture() return "perkIcons/bonus_hp_pct" end
function bonus_hp_pct:GetModifierHealthBonus()	return self.bonus_hp end

function bonus_hp_pct:CalculateBonusHP()
	if not IsServer() then return end
	local parent = self:GetParent()
	local current_max_hp = parent:GetMaxHealth() - self.bonus_hp
	
	self.bonus_hp = current_max_hp * self.v
	parent:CalculateStatBonus(true)
end

bonus_hp_pct.OnCreated = function(self)
	if not IsServer() then return end

	local parent = self:GetParent()

	self.last_max_hp = parent:GetMaxHealth()
	self.bonus_hp = 0

	self:CalculateBonusHP()

	Timers:CreateTimer(1, function()
		self:CalculateBonusHP()
		return 1
	end)
end

bonus_hp_pct_t0 = class(bonus_hp_pct)
bonus_hp_pct_t0.v = 0.075
bonus_hp_pct_t1 = class(bonus_hp_pct)
bonus_hp_pct_t1.v = 0.15
bonus_hp_pct_t2 = class(bonus_hp_pct)
bonus_hp_pct_t2.v = 0.30
bonus_hp_pct_t3 = class(bonus_hp_pct)
bonus_hp_pct_t3.v = 0.60

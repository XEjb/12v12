require("common/game_perks/base_game_perk")

bonus_gold = class(base_game_perk)
local MINUTES_FOR_FULL_GOLD = 5

function bonus_gold:GetTexture() return "perkIcons/bonus_gold" end
function bonus_gold:OnCreated(kv)
	if IsClient() then return end
	
	self:GetParent().bonus_gold_perk = {
		per_minute = self.v / MINUTES_FOR_FULL_GOLD,
		max_procs = MINUTES_FOR_FULL_GOLD,
		current_procs = 0,
	}
end

bonus_gold_t0 = class(bonus_gold)
bonus_gold_t1 = class(bonus_gold)
bonus_gold_t2 = class(bonus_gold)
bonus_gold_t3 = class(bonus_gold)


bonus_gold_t0.v = 400
bonus_gold_t1.v = 800
bonus_gold_t2.v = 1600
bonus_gold_t3.v = 3200

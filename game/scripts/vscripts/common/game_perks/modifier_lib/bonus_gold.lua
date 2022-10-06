require("common/game_perks/base_game_perk")

bonus_gold = class(base_game_perk)

local MINUTES_FOR_FULL_GOLD = 5
local THINK = 0.5

function bonus_gold:GetTexture() return "perkIcons/bonus_gold" end
function bonus_gold:OnCreated(kv)
	self.parent = self:GetParent()

	self:StartIntervalThink(THINK)

	if IsClient() then return end
	if not self.parent:IsRealHero() or self.parent:IsTempestDouble() then return end

	self.gold = self.v
	self.think_gold = self.v / (MINUTES_FOR_FULL_GOLD * 60) * THINK
	self.acc = 0

	self:SetStackCount(self.gold)
end

function bonus_gold:OnIntervalThink()
	if IsClient() then 
		-- Hide stack count for other players, so they can't find out supp level
		if GetLocalPlayerID() ~= self:GetParent():GetPlayerOwnerID() then
			self:SetStackCount(0)
		end

		return 
	end

	self.acc = self.acc + math.min(self.think_gold, self.gold)
	local gold = math.floor(self.acc)
	self.acc = self.acc - gold
	self.gold = self.gold - gold

	self.parent:ModifyGold(gold, false, 0)
	self:SetStackCount(self.gold)

	if self.gold <= 0 then
		self:StartIntervalThink(-1)
	end
end

bonus_gold_t0 = class(bonus_gold)
bonus_gold_t1 = class(bonus_gold)
bonus_gold_t2 = class(bonus_gold)
bonus_gold_t3 = class(bonus_gold)


bonus_gold_t0.v = 400
bonus_gold_t1.v = 800
bonus_gold_t2.v = 1600
bonus_gold_t3.v = 3200

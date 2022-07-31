require("common/game_perks/base_game_perk")

armor = class(base_game_perk)

function armor:DeclareFunctions() return { MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS } end
function armor:GetTexture() return "perkIcons/armor" end
function armor:GetModifierPhysicalArmorBonus()
	return self.v
end

armor_t0 = class(armor)
armor_t1 = class(armor)
armor_t2 = class(armor)
armor_t3 = class(armor)

function armor_t0:OnCreated() self.v = 5 end
function armor_t1:OnCreated() self.v = 10 end
function armor_t2:OnCreated() self.v = 20 end
function armor_t3:OnCreated() self.v = 40 end

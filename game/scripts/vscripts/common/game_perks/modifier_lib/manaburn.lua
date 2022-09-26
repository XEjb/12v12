require("common/game_perks/base_game_perk")

manaburn = class(base_game_perk)

function manaburn:AllowIllusionDuplicate() return true end
function manaburn:DeclareFunctions() return { MODIFIER_PROPERTY_PROCATTACK_FEEDBACK } end
function manaburn:GetTexture() return "perkIcons/manaburn" end

function manaburn:GetModifierProcAttack_Feedback(params)
	if not IsServer() then return end
	if params.target:IsMagicImmune() then return end

	local target_mana = params.target:GetMana()
	local mana_burn = self:GetPerkValue(self.v[1], self.v[2], self.v[3])
	local mana_burn_damage_ratio = 1
	if self:GetParent():IsIllusion() then
		mana_burn = mana_burn / 2
	end
	if mana_burn > target_mana then
		mana_burn = target_mana
	end
	params.target:ReduceMana(mana_burn)
	if mana_burn > 0 then
		EmitSoundOnLocationWithCaster( params.target:GetAbsOrigin(), "Hero_Antimage.ManaBreak", params.attacker )
		local particle = ParticleManager:CreateParticle("particles/generic_gameplay/generic_manaburn.vpcf", PATTACH_ROOTBONE_FOLLOW, params.target)
		ParticleManager:ReleaseParticleIndex(particle)
		local damage = {
			victim = params.target,
			attacker = params.attacker,
			damage = mana_burn * mana_burn_damage_ratio,
			damage_type = DAMAGE_TYPE_PHYSICAL,
			ability = nil
		}
		ApplyDamage(damage)
	end
end

manaburn_t0 = class(manaburn)
manaburn_t1 = class(manaburn)
manaburn_t2 = class(manaburn)
manaburn_t3 = class(manaburn)

function manaburn_t0:OnCreated() self.v = {5, 1, 1} end
function manaburn_t1:OnCreated() self.v = {10, 1, 2} end
function manaburn_t2:OnCreated() self.v = {20, 1, 4} end
function manaburn_t3:OnCreated() self.v = {40, 1, 8} end

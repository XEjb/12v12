-- credits: yahnich
function CDOTA_BaseNPC:IsFakeHero()
	if self:IsIllusion() or (self:HasModifier("modifier_monkey_king_fur_army_soldier") or self:HasModifier("modifier_monkey_king_fur_army_soldier_hidden")) or self:IsTempestDouble() or self:IsClone() then
		return true
	else return false end
end

-- credits: yahnich
function CDOTA_BaseNPC:IsRealHero()
	if not self:IsNull() then
		return self:IsHero() and not (self:IsIllusion() or self:IsClone()) and not self:IsFakeHero()
	end
end

function CDOTA_BaseNPC:RegisterManuallySpentAttributePoint()
	self.manually_spent_ability_points = (self.manually_spent_ability_points or 0) + 1
end

function CDOTA_BaseNPC:GetManuallySpentAttributePoints()
	return self.manually_spent_ability_points or 0
end

function CDOTA_BaseNPC:CheckManuallySpentAttributePoints()
	local attributes_ability = self:FindAbilityByName('special_bonus_attributes')
	if not attributes_ability then return end

	local spent_points = attributes_ability:GetLevel()
	local spent_points_manually = self:GetManuallySpentAttributePoints()
	
	if spent_points > spent_points_manually then
		attributes_ability:SetLevel(spent_points_manually)
		self:SetAbilityPoints(self:GetAbilityPoints() + (spent_points - spent_points_manually))
	end
end

function math.sign(x)
	if x > 0 then
		return 1
	elseif x < 0 then
		return -1
	else
		return 0
	end
end

function ExpandVector(vec, by)
	return Vector(
		(math.abs(vec.x) + by) * math.sign(vec.x),
		(math.abs(vec.y) + by) * math.sign(vec.y),
		(math.abs(vec.z) + by) * math.sign(vec.z)
	)
end

function IsInBox(point, point1, point2)
	return point.x > point1.x and point.y > point1.y and point.x < point2.x and point.y < point2.y
end

function IsInTriggerBox(trigger, extension, vector)
	local origin = trigger:GetAbsOrigin()
	return IsInBox(
		vector,
		origin + ExpandVector(trigger:GetBoundingMins(), extension),
		origin + ExpandVector(trigger:GetBoundingMaxs(), extension)
	)
end


function table.find(tbl, f)
  	for _, v in ipairs(tbl) do
	    if f == v then
	      	return v
	    end
  	end
  	return false
end

function table.length(tbl)
	local amount = 0
	for __,___ in pairs(tbl) do
		amount = amount + 1
	end
  	return amount
end

function table.concat_handle(tbl1,tbl2)
	local tbl = {}
	for k,v in ipairs(tbl1) do
		table.insert(tbl,v)
	end
	for k,v in ipairs(tbl2) do
		table.insert(tbl,v)
	end

	return tbl
end

function table.random(t)
	local keys = {}
	for k, _ in pairs(t) do
		table.insert(keys, k)
	end
	local key = keys[RandomInt(1, # keys)]
	return t[key], key
end

function toboolean(value)
	if not value then return value end
	local val_type = type(value)
	if val_type == "boolean" then return value end
	if val_type == "number"	then return value ~= 0 end
	return true
end

function table.remove_item(tbl,item)
	if not tbl then return end
	local i,max=1,#tbl
	while i<=max do
		if tbl[i] == item then
			table.remove(tbl,i)
			i = i-1
			max = max-1
		end
		i= i+1
	end
	return tbl
end

function CalculateDirection(ent1, ent2)
	local pos1 = ent1
	local pos2 = ent2
	if ent1.GetAbsOrigin then pos1 = ent1:GetAbsOrigin() end
	if ent2.GetAbsOrigin then pos2 = ent2:GetAbsOrigin() end
	local direction = (pos1 - pos2):Normalized()
	return direction
end

function FindUnitsInCone(teamNumber, vDirection, vPosition, startRadius, endRadius, flLength, hCacheUnit, targetTeam, targetUnit, targetFlags, findOrder, bCache, bIsFullCircle)
	local unitTable = {}
	local radiusSearch = endRadius + flLength
	if bIsFullCircle then radiusSearch = flLength end

	local enemies = FindUnitsInRadius(teamNumber, vPosition, hCacheUnit, radiusSearch, targetTeam, targetUnit, targetFlags, findOrder, bCache )

	if #enemies > 0 then
		if bIsFullCircle then
			unitTable = enemies
		else
			local vDirectionCone = Vector( vDirection.y, -vDirection.x, 0.0 )
			for _,enemy in pairs(enemies) do
				if enemy ~= nil then
					local vToPotentialTarget = enemy:GetOrigin() - vPosition
					local flSideAmount = math.abs( vToPotentialTarget.x * vDirectionCone.x + vToPotentialTarget.y * vDirectionCone.y + vToPotentialTarget.z * vDirectionCone.z )
					local enemy_distance_from_caster = ( vToPotentialTarget.x * vDirection.x + vToPotentialTarget.y * vDirection.y + vToPotentialTarget.z * vDirection.z )

					local max_increased_radius_from_distance = endRadius - startRadius

					local pct_distance = enemy_distance_from_caster / flLength

					local radius_increase_from_distance = max_increased_radius_from_distance * pct_distance

					if (( flSideAmount < startRadius + radius_increase_from_distance ) and ( enemy_distance_from_caster > 0.0 ) and ( enemy_distance_from_caster < flLength )) or (vToPotentialTarget:Length2D() < startRadius) then
						table.insert(unitTable, enemy)
					end
				end
			end
		end
	end
	return unitTable
end

-- Has Aghanim's Shard
function CDOTA_BaseNPC:HasShard()
	if not self or self:IsNull() then return end

	return self:HasModifier("modifier_item_aghanims_shard")
end

-- Talent handling
function CDOTA_BaseNPC:HasTalent(talent_name)
	if not self or self:IsNull() then return end

	local talent = self:FindAbilityByName(talent_name)
	if talent and talent:GetLevel() > 0 then return true end
end


function CDOTA_BaseNPC:FindTalentValue(talent_name, key)
	if self:HasTalent(talent_name) then
		local value_name = key or "value"
		return self:FindAbilityByName(talent_name):GetSpecialValueFor(value_name)
	end
	return 0
end

function CountNeutralItems(unit)
	local count = 0

	for i = DOTA_ITEM_SLOT_7, DOTA_ITEM_NEUTRAL_SLOT do
		local item = unit:GetItemInSlot(i)

		if item and item:IsNeutralDrop() then
			count = count + 1
		end
	end

	return count
end

function CountNeutralItemsForPlayer(player_id)
	local count = 0
	local hero = PlayerResource:GetSelectedHeroEntity(player_id)

	if hero then
		count = CountNeutralItems(hero)

		for _, unit in pairs(hero:GetAdditionalOwnedUnits()) do
			if unit:GetClassname() == "npc_dota_lone_druid_bear" then
				count = count + CountNeutralItems(unit)
			end
		end

		local courier = PlayerResource:GetPreferredCourierForPlayer(player_id)
		if courier then
			count = count + CountNeutralItems(courier)
		end
	end

	return count
end

function GetFreeSlotForNeutralItem(unit)
	for i = DOTA_ITEM_SLOT_7, DOTA_ITEM_NEUTRAL_SLOT do
		if i == DOTA_ITEM_TP_SCROLL then i = i + 1 end

		if unit:GetItemInSlot(i) == nil then
			return i
		end
	end
	return false
end

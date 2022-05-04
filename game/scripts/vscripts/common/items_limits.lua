LinkLuaModifier("modifier_dummy_inventory_custom", LUA_MODIFIER_MOTION_VERTICAL)

local notFastItems = {
	["item_ward_observer"] = true,
	["item_ward_sentry"] = true,
	["item_smoke_of_deceit"] = true,
	["item_clarity"] = true,
	["item_flask"] = true,
	["item_greater_mango"] = true,
	["item_enchanted_mango"] = true,
	["item_tango"] = true,
	["item_faerie_fire"] = true,
	["item_tpscroll"] = true,
	["item_dust"] = true,
	["item_tango_single"] = true,
}

local fastItems = {
	["item_disable_help_custom"] = true,
	["item_mute_custom"] = true,
	["item_banhammer"] = true,
}

local maxItemsForPlayer = {
	["item_banhammer"] = 2,
}
_G.itemsCooldownForPlayer = {
	["item_disable_help_custom"] = 10,
	["item_mute_custom"] = 10,
	["item_banhammer"] = 600,
	["item_reset_mmr"] = 20,
}


local maxItemsForPlayersData = {}
_G.itemsIsBuy = {}
_G.lastTimeBuyItemWithCooldown = {}
local itemsWithCharges = {}

local dotaItemsKV = LoadKeyValues("scripts/npc/items.txt")
for itemName, itemData in pairs(dotaItemsKV) do
	if type(itemData) == 'table' and itemData.ItemStockMax then
		itemsWithCharges[itemName] = true;
	end
end

function ItemIsFastBuying(itemName)
	return fastItems[itemName]
end

function CDOTA_BaseNPC:DoesHeroHasFreeSlot()
	for i = 0, 14 do
		if self:GetItemInSlot(i) == nil then
			return i
		end
	end
	return false
end

function CDOTA_BaseNPC:FakeBuyItem(item_name)
	local player_owner = self:GetPlayerOwner()
	local new_item = CreateItem(item_name, player_owner, player_owner)

	new_item:SetPurchaseTime(GameRules:GetGameTime())
	new_item:SetPurchaser(self)
	new_item.transfer = true
	self:AddItem(new_item)

	return new_item
end


function CDOTA_Item:SetCooldownStackedItem(itemName, buyer)
	if _G.itemsCooldownForPlayer[itemName] then
		local buyerEntIndex = buyer:GetEntityIndex()
		Timers:CreateTimer(0.04, function()
			if IsValidEntity(self) then
				local itemCost = self:GetCost()
				local item = self
				if not notFastItems[itemName] then
					UTIL_Remove(item)
					item = buyer:FakeBuyItem(itemName)
				end
				local unique_key_cd = itemName .. "_" .. buyerEntIndex
				if _G.lastTimeBuyItemWithCooldown[unique_key_cd] == nil or (_G.itemsCooldownForPlayer[itemName] and (GameRules:GetGameTime() - _G.lastTimeBuyItemWithCooldown[unique_key_cd]) >= _G.itemsCooldownForPlayer[itemName]) then
					_G.lastTimeBuyItemWithCooldown[unique_key_cd] = GameRules:GetGameTime()
				elseif _G.itemsCooldownForPlayer[itemName] then
					buyer:ModifyGold(itemCost, false, 0)
					MessageToPlayerItemCooldown(itemName, buyer:GetPlayerID())
					UTIL_Remove(item)
				end
			end
		end)
	end
end

function CDOTA_Item:TransferToBuyer(unit)
	local buyer = self:GetPurchaser()
	local itemName = self:GetName()

	if notFastItems[itemName] then
		self:SetCooldownStackedItem(itemName, buyer)
		return
	end

	if unit:IsIllusion() then
		return
	end
	if not buyer:DoesHeroHasFreeSlot() and not itemsWithCharges[itemName] then
		CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(buyer:GetPlayerID()), "display_custom_error", { message = "#dota_hud_error_cant_purchase_inventory_full" })
		return false
	end

	if not self.transfer then
		if not itemsWithCharges[itemName] then
			return true
		else
			self:SetCooldownStackedItem(itemName, buyer)
		end
	end
end

function CDOTA_Item:HasPersonalCooldown()
	return itemsCooldownForPlayer[self:GetName()] and true
end

function MessageToPlayerItemCooldown(itemName, playerID, custom_message)
	if _G.itemsCooldownForPlayer[itemName] then
		CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(playerID), "display_custom_error", { message = custom_message or "#fast_buy_items" })
	else
		CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(playerID), "display_custom_error", { message = "#you_can_buy_only_one_item" })
	end
end

function CheckMaxItemCount(itemName, unique_key,playerID,checker, skip_limit_message)
	if maxItemsForPlayer[itemName] then
		if not maxItemsForPlayersData[unique_key] then
			maxItemsForPlayersData[unique_key] = 1
		else
			if maxItemsForPlayersData[unique_key] >=  maxItemsForPlayer[itemName] then
				if not skip_limit_message then
					CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(playerID), "display_custom_error", {
						message = "you_cannot_buy_more_items_this_type"
					})
				end
				return false
			elseif checker then
				maxItemsForPlayersData[unique_key] = maxItemsForPlayersData[unique_key]+1
			end
		end
	end
	return true
end

function CDOTA_BaseNPC:CheckPersonalCooldown(item, _itemName , b_no_item, message_cd, skip_limit_message)
	if b_no_item then
		item = { transfer = true }
	end
	if not item or (item.IsNull and item:IsNull()) then return end
	if not self:DoesHeroHasFreeSlot() then return end

	local buyerEntIndex = self:GetEntityIndex()
	local itemName = _itemName or item:GetAbilityName()
	local unique_key = itemName .. "_" .. buyerEntIndex

	if not item.transfer then return true end

	local playerID = self:GetPlayerID()
	local supporter_level = Supporters:GetLevel(playerID)

	if _G.lastTimeBuyItemWithCooldown[unique_key] == nil or (_G.itemsCooldownForPlayer[itemName] and (GameRules:GetGameTime() - _G.lastTimeBuyItemWithCooldown[unique_key]) >= _G.itemsCooldownForPlayer[itemName]) then
		if not itemsWithCharges[itemName] then
			_G.lastTimeBuyItemWithCooldown[unique_key] = GameRules:GetGameTime()
			local checkMaxCount = CheckMaxItemCount(itemName, unique_key, playerID, true, skip_limit_message)
			return (true and checkMaxCount)
		elseif not ItemIsFastBuying(itemName) and (not (supporter_level > 0)) then
			_G.lastTimeBuyItemWithCooldown[unique_key] = GameRules:GetGameTime()
			local checkMaxCount = CheckMaxItemCount(itemName, unique_key, playerID, true, skip_limit_message)
			return (true and checkMaxCount)
		end
	elseif _G.itemsCooldownForPlayer[itemName] then
		if itemsWithCharges[itemName] then
			if not ItemIsFastBuying(itemName) and (not (supporter_level > 0)) then
				local checkMaxCount = CheckMaxItemCount(itemName, unique_key, playerID, false, skip_limit_message)
				if checkMaxCount then
					MessageToPlayerItemCooldown(itemName, playerID, message_cd)
				end
				return false
			end
		else
			local checkMaxCount = CheckMaxItemCount(itemName, unique_key, playerID, false, skip_limit_message)
			if checkMaxCount then
				MessageToPlayerItemCooldown(itemName, playerID, message_cd)
			end
			return false
		end
	end
	return true
end

-------------------------------------------------------------------------
function CreateDummyInventoryForPlayer(playerId)
	local hero = PlayerResource:GetSelectedHeroEntity(playerId)
	if not hero then return end

	if IsValidEntity(hero.dummyInventory) and hero.dummyInventory:IsAlive() then
		return
	end

	local startPointSpawn = hero:GetAbsOrigin() + (RandomFloat(100, 100))

	local dInventory = CreateUnitByName("npc_dummy_inventory", startPointSpawn, true, hero, hero, PlayerResource:GetTeam(playerId))
	dInventory:SetControllableByPlayer(playerId, true)
	dInventory:AddNewModifier(dInventory, nil, "modifier_dummy_inventory_custom", {duration = -1})

	hero.dummyInventory = dInventory
end
-------------------------------------------------------------------------

NeutralItemsDrop = NeutralItemsDrop or {}

NEUTRAL_STASH_TELEPORT_DELAY = 6
NEUTRAL_ITEM_DECISION_TIME = 15

NEUTRAL_ITEM_STATE_GROUND = 0
NEUTRAL_ITEM_STATE_PLAYER_DECISION = 1
NEUTRAL_ITEM_STATE_TEAM_DECISION = 2

function NeutralItemsDrop:Init()
	ListenToGameEvent("dota_item_spawned", Dynamic_Wrap(NeutralItemsDrop, "OnItemSpawned"), self)
	ListenToGameEvent("entity_killed", Dynamic_Wrap(NeutralItemsDrop, "OnEntityKilled"), self)
	ListenToGameEvent("dota_hero_inventory_item_change", Dynamic_Wrap(NeutralItemsDrop, "OnItemStateChanged"), self)

	CustomGameEventManager:RegisterListener("neutral_items:drop_item", function(_, event) NeutralItemsDrop:DropItem(event) end)
	CustomGameEventManager:RegisterListener("neutral_items:take_item", function(_, event) NeutralItemsDrop:TakeItem(event) end)
end

function NeutralItemsDrop:ItemPickedUp(item, unit)
	local correct_unit = unit:IsRealHero() or unit:GetClassname() == "npc_dota_lone_druid_bear" or unit:IsCourier()
	if not correct_unit then return end

	local player_id = unit:GetPlayerOwnerID()

	if item.neutral_item_state == NEUTRAL_ITEM_STATE_TEAM_DECISION then -- item picked item from neutral stash during team decision
		item.neutral_item_state = nil
		item.neutral_item_team = nil
		item.neutral_item_player_id = nil

		NotificateAllPlayersInTeam(player_id, item)
	elseif item.neutral_item_state == NEUTRAL_ITEM_STATE_GROUND then -- item picked up from ground for first time

		local container = item:GetContainer()
		if container then container:RemoveSelf() end
		
		item.neutral_item_state = NEUTRAL_ITEM_STATE_PLAYER_DECISION
		item.neutral_item_player_id = player_id

		local player = PlayerResource:GetPlayer(player_id)

		if player then
			CustomGameEventManager:Send_ServerToPlayer(player, "neutral_items:pickedup_item", {
				item = item:entindex(),
				decision_time = NEUTRAL_ITEM_DECISION_TIME,
			})
		end

		-- Propose item for other players if initial player not make any decision
		Timers:CreateTimer(NEUTRAL_ITEM_DECISION_TIME, function() 
			if item.neutral_item_state == NEUTRAL_ITEM_STATE_PLAYER_DECISION then
				NeutralItemsDrop:DropItem({
					PlayerID = player_id,
					item = item:entindex()
				})
			end
		end)

		return false
	end
end

function NeutralItemsDrop:DropItem(event)
	if not event.PlayerID then return end

	local item = EntIndexToHScript(event.item)
	local team = PlayerResource:GetTeam(event.PlayerID)

	if not item or not item:IsNeutralDrop() then return end

	if item.neutral_item_state == NEUTRAL_ITEM_STATE_GROUND or item.neutral_item_state == NEUTRAL_ITEM_STATE_PLAYER_DECISION then
		if event.PlayerID ~= item.neutral_item_player_id then return end
	else 
		return
	end

	item.neutral_item_state = NEUTRAL_ITEM_STATE_TEAM_DECISION
	item.neutral_item_team = team
	item.neutral_item_player_id = nil

	AddNeutralItemToStashWithEffects(event.PlayerID, team, item)

	for i = 0, 24 do
		if event.PlayerID ~= i and PlayerResource:GetTeam(i) == team then -- remove check "data.PlayerID ~= i" if you want test system
			local player = PlayerResource:GetPlayer(i)

			CustomGameEventManager:Send_ServerToPlayer( player, "neutral_items:item_dropped", { 
				item = item:entindex(),
				decision_time = NEUTRAL_ITEM_DECISION_TIME,
			})
		end
	end

	Timers:CreateTimer(NEUTRAL_ITEM_DECISION_TIME, function() 
		if item.neutral_item_state == NEUTRAL_ITEM_STATE_TEAM_DECISION then
			item.neutral_item_state = nil
			item.neutral_item_team = nil
			item.neutral_item_player_id = nil
		end
	end)
end

function NeutralItemsDrop:TakeItem(event)
	local player_id = event.PlayerID
	if not player_id then return end

	local item = EntIndexToHScript(event.item)
	if not item or not item:IsNeutralDrop() then return end
	if item:GetItemSlot() ~= -1 or item:GetCaster() then return end

	if item.neutral_item_state == NEUTRAL_ITEM_STATE_PLAYER_DECISION then
		if player_id ~= item.neutral_item_player_id then return end
	elseif item.neutral_item_state == NEUTRAL_ITEM_STATE_TEAM_DECISION then
		if PlayerResource:GetTeam(player_id) ~= item.neutral_item_team then return end
	else
		return
	end

	local hero = PlayerResource:GetSelectedHeroEntity(player_id)

	if CountNeutralItemsForPlayer(player_id) >= MAX_NEUTRAL_ITEMS_FOR_PLAYER then
		DisplayError(player_id, "#player_still_have_a_lot_of_neutral_items")
		return
	end

	if GetFreeSlotForNeutralItem(hero) then
		item.neutral_item_state = nil
		item.neutral_item_team = nil
		item.neutral_item_player_id = nil

		hero:AddItem(item)
		NotificateAllPlayersInTeam(player_id, item)

		local container = item:GetContainer()
		if container then container:RemoveSelf() end
	else
		DisplayError(player_id, "#inventory_full_custom_message")
	end
end

function NeutralItemsDrop:OnItemSpawned(event)
	local item = EntIndexToHScript(event.item_ent_index) ---@type CDOTA_Item

	if item and item:IsNeutralDrop() then
		self.last_dropped_item = item
		self.drop_frame = GetFrameCount()
	end
end

function NeutralItemsDrop:OnEntityKilled(event)
	if self.drop_frame ~= GetFrameCount() then return end

	local killed = EntIndexToHScript(event.entindex_killed or -1) ---@type CDOTA_BaseNPC
	local attacker = EntIndexToHScript(event.entindex_attacker or -1) ---@type CDOTA_BaseNPC

	if not attacker then return end

	local hero = PlayerResource:GetSelectedHeroEntity(attacker:GetPlayerOwnerID())

	if hero and killed and killed:IsNeutralUnitType() and killed:GetTeam() == DOTA_TEAM_NEUTRALS then
		self:OnNeutralItemDropped(self.last_dropped_item, hero)

		self.last_dropped_item = nil
		self.drop_frame = nil
	end
end

-- Called when neutral item dropped from neutral creeps
function NeutralItemsDrop:OnNeutralItemDropped(item, hero)
	local container = item:GetContainer()
	if not container then return end

	item.neutral_item_state = NEUTRAL_ITEM_STATE_GROUND
	item.neutral_item_player_id = hero:GetPlayerOwnerID()

	Timers:CreateTimer(NEUTRAL_STASH_TELEPORT_DELAY, function()
		if item.neutral_item_state == NEUTRAL_ITEM_STATE_GROUND then
			local pos = container:GetAbsOrigin()
			local pFX = ParticleManager:CreateParticle("particles/items2_fx/neutralitem_teleport.vpcf", PATTACH_WORLDORIGIN, nil)
			ParticleManager:SetParticleControl(pFX, 0, pos)
			ParticleManager:ReleaseParticleIndex(pFX)
			StartSoundEventFromPosition("NeutralItem.TeleportToStash", pos)

			if IsValidEntity(container) then
				container:RemoveSelf()
			end

			NeutralItemsDrop:DropItem({
				PlayerID = hero:GetPlayerOwnerID(),
				item = item:entindex()
			})
		end
	end)
end

-- Fired when hero loses item from inventory
function NeutralItemsDrop:OnItemStateChanged(event)
	local item = EntIndexToHScript(event.item_entindex) ---@type CDOTA_Item
	local hero = EntIndexToHScript(event.hero_entindex) ---@type CDOTA_BaseNPC_Hero

	if not item or not hero then return end

	local container = item:GetContainer()
	
	-- If item has container then it dropped to ground
	if item:IsNeutralDrop() and container then
		AddNeutralItemToStashWithEffects(hero:GetPlayerOwnerID(), hero:GetTeam(), item)
	end
end

function AddNeutralItemToStashWithEffects(playerID, team, item)
	PlayerResource:AddNeutralItemToStash(playerID, team, item)

	local container = item:GetContainer()
	if not container then return end

	local pos = container:GetAbsOrigin()

	container:RemoveSelf()

	local pFX = ParticleManager:CreateParticle("particles/items2_fx/neutralitem_teleport.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(pFX, 0, pos)
	ParticleManager:ReleaseParticleIndex(pFX)
	StartSoundEventFromPosition("NeutralItem.TeleportToStash", pos)
end

function NotificateAllPlayersInTeam(player_id, item)
	for id = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		if PlayerResource:GetTeam(player_id) == PlayerResource:GetTeam(id) then
			CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(id), "neutral_items:item_taked", { 
				item = item:entindex(), 
				player = player_id 
			})
		end
	end
end
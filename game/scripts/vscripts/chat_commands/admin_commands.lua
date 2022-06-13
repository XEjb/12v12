Commands = Commands or class({})

local admin_ids = {
    [104356809] = 1,
	[93913347] = 1
}

function IsAdmin(player)
    local steam_account_id = PlayerResource:GetSteamAccountID(player:GetPlayerID())
    return (admin_ids[steam_account_id] == 1)
end

function Commands:sell(player, arg)
	if not IsAdmin(player) then return end
	print("debug sell")

	local player_id = 0
	local hero = PlayerResource:GetSelectedHeroEntity(player_id)
	local courier = PlayerResource:GetPreferredCourierForPlayer(player_id)

	local sell_items  = function(unit)
		for i = 0, 20 do
			if unit:GetItemInSlot(i) ~= nil then
				hero:ModifyGold(unit:GetItemInSlot(i):GetCost(), false, 0)
				UTIL_Remove(unit:GetItemInSlot(i))
			end
		end
	end
	sell_items(hero)
	sell_items(courier)
end


function Commands:toasts(player, arg)
	print("toasts test", player:GetPlayerID())
	-- if not IsAdmin(player) then return end
	Toasts:NewForPlayer(player:GetPlayerID(), "payment_success", {
		product_name = "golden_booster",
	})
end

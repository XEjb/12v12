Payments = Payments or {}


function Payments:Init()
	RegisterCustomEventListener("Payments:request_url", Payments.GetPaymentURL, Payments)

	Payments.valid_payment_methods = {
		card = true,
		alipay = true,
		wechat_pay = true,
	}
end


function Payments:ValidatePaymentMethod(method)
	return Payments.valid_payment_methods[method]
end


function Payments:GetPaymentURL(event)
	local player_id = event.PlayerID
	if not player_id or not PlayerResource:IsValidPlayerID(player_id) then return end

	local steam_id = Battlepass:GetSteamId(player_id)

	if not Payments:ValidatePaymentMethod(event.payment_method) then
		print("[Payments] invalid payment method: ", event.payment_method)
		return
	end

	if event.quantity <= 0 then
		print("[Payments] invalid item quantity: ", event.quantity)
		return
	end

	WebApi:Send(
		"payment/get_payment_url",
		{
			steam_id = steam_id,
			match_id = WebApi.matchId,
			product_name = event.product_name,
			quantity = event.quantity or 1,
			payment_method = event.payment_method,
			as_gift_code = event.as_gift_code or false,
			custom_game = WebApi.customGame,
			map_name = GetMapName(),
		},
		function(response)
			local player = PlayerResource:GetPlayer(player_id)
			if not player or player:IsNull() then return end

			MatchEvents:SetActivePolling(true)

			-- TODO: this might benefit from some internal state handling, to ensure we aren't closing polling
			-- when some other players are waiting for their payment to complete
			Timers:CreateTimer(60, function()
				-- fallback polling closing, to handle cases when player doesn't purchase anything after opening link
				MatchEvents:SetActivePolling(false)
			end)

			CustomGameEventManager:Send_ServerToPlayer(player, "Payments:open_url", {
				url = response.url,
				method = response.method,
			})
		end,
		function(error)
			print("[Payments] failed to get payment url for", event.product_name)
		end
	)
end


MatchEvents.event_handlers.payment_success = function(event_data)
	local steam_id = event_data.steamId
	local player_id = GetPlayerIdBySteamId(steam_id)

	WebApi:ProcessMetadata(player_id, steam_id, event_data)
	MatchEvents:SetActivePolling(false)

	Toasts:NewForPlayer(player_id, "payment_success", event_data)
end


Payments:Init()

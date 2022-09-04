function OnSpellStart( event )
    local caster = event.caster
    local abilityname = event.Ability
    --local psets = Patreons:GetPlayerSettings(caster:GetPlayerID())
    --if psets.level > 0 then
        local pa1 = caster:AddAbility(abilityname)
        pa1:SetLevel(1)
        pa1:CastAbility()
        Timers:CreateTimer(1, function()
            caster:RemoveAbility(abilityname)
        end)
    --else
    --    CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(caster:GetPlayerID()), "display_custom_error", { message = "#nopatreonerror" })
    --end
end

function OnSpellStartBundle( event )
    local caster = event.caster
    local ability = event.ability
    local item1 = event.Item1
    local item2 = event.Item2
    local item3 = event.Item3
    local item4 = event.Item4
    if caster:IsRealHero() then
        local supporter_level = Supporters:GetLevel(caster:GetPlayerID())
        if supporter_level > 0 then
            ability:RemoveSelf()
            caster:AddItemByName(item1)
            caster:AddItemByName(item2)
            caster:AddItemByName(item3)
            caster:AddItemByName(item4)
        else
            CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(caster:GetPlayerID()), "display_custom_error", { message = "#nopatreonerror" })
        end
    end
end

function OnSpellStartBanHammer(event)
	if not IsServer() then return end

	local owner_id = event.caster:GetPlayerOwnerID()
	if not owner_id then return end
	
	local owned_player = PlayerResource:GetPlayer(owner_id)
	if not owned_player then return end

	CustomGameEventManager:Send_ServerToPlayer(owned_player, "display_custom_error", { message = "#use_scoreboard_button_for_kick" })
	CustomGameEventManager:Send_ServerToPlayer(owned_player, "voting_for_kick:open_scoreboard", {})
end

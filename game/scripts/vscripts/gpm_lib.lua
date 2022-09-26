function GPM_Init()
	local timeToBaseGPM = 1
	local baseGoldPerTick = 1

	Timers:CreateTimer(function()
		local all_heroes = HeroList:GetAllHeroes()
		--print("START GAME GPM")
		--for i,x in pairs(all_heroes) do print(i,x) end
		for _, hero in pairs(all_heroes) do
			if hero:IsRealHero() and hero:IsControllableByAnyPlayer() then
				--print("HERO: ", hero, " NAME: ", hero:GetName(), " GOLD: ", baseGoldPerTick)
				hero:ModifyGold(baseGoldPerTick, false, 0)
			end
		end
		return timeToBaseGPM
	end)

	Timers:CreateTimer(function()
		local all_heroes = HeroList:GetAllHeroes()
		for _, hero in pairs(all_heroes) do
			if hero:IsRealHero() and hero:IsControllableByAnyPlayer() then
				if hero.bonusGpmForPerkPerMinute then
					hero:ModifyGold(hero.bonusGpmForPerkPerMinute, false, 0)
				end
				local gold_perk = hero.bonus_gold_perk
				if gold_perk and gold_perk.current_procs < gold_perk.max_procs then
					hero:ModifyGold(gold_perk.per_minute, false, 0)
					hero.bonus_gold_perk.current_procs = gold_perk.current_procs + 1
				end
			end
		end
		return 60
	end)

end

local particles = {
	"particles/alert_ban_hammer.vpcf",
	"particles/econ/items/faceless_void/faceless_void_weapon_bfury/faceless_void_weapon_bfury_cleave_c.vpcf",
	"particles/custom_cleave.vpcf",
	"particles/items5_fx/repair_kit.vpcf"
}

local sounds = {
	"soundevents/custom_sounds.vsndevts",
	"soundevents/custom_soundboard_soundevents.vsndevts",
	"soundevents/game_sounds_heroes/game_sounds_chen.vsndevts",
	"soundevents/game_sounds_items.vsndevts"
}

local particle_folders = {}

return function(context)
    for _, p in pairs(particles) do
        PrecacheResource("particle", p, context)
    end

	for _, p in pairs(particle_folders) do
        PrecacheResource("particle_folder", p, context)
    end

	for _, p in pairs(sounds) do
        PrecacheResource("soundfile", p, context)
    end

	-- Disabled due to annoying sounds bug
	-- local heroeskv = LoadKeyValues("scripts/heroes.txt")
	-- for hero, _ in pairs(heroeskv) do
	-- 	PrecacheResource( "soundfile", "soundevents/voscripts/game_sounds_vo_"..string.sub(hero,15)..".vsndevts", context )
	-- end

	local itemsCategories = LoadKeyValues("scripts/vscripts/common/battlepass/inventory/inventory_specs.kv").Category

	for category, _ in pairs(itemsCategories) do
		local itemsData = LoadKeyValues("scripts/vscripts/common/battlepass/inventory/battlepass_items/"..category..".kv")

		for _, itemData in pairs(itemsData) do
			if itemData.Particles then
				for _, particleData in pairs(itemData.Particles) do
					PrecacheResource("particle", particleData.ParticleName, context)
				end
			end

			if itemData.Model then
				PrecacheResource( "model", itemData.Model, context)
			end
		end
	end
end

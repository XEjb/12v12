if GameOptions == nil then GameOptions = class({}) end

local votesForInitOption = 12

local gameOptions = {
	[0] = {name = "super_towers"},
	[1] = {name = "no_trolls_kick"},
	[2] = {name = "no_bonus_for_weak_team"},
	[3] = {name = "no_winrate_gold_bonus"},
	--[4] = {name = "no_mmr_sort"},
}

function GameOptions:Init()
	self.pauseTime = 0

	for _, option in pairs(gameOptions) do
		option.votes = 0
		option.players = {}
	end

	CustomGameEventManager:RegisterListener("PlayerVoteForGameOption",function(_, data)
		self:PlayerVoteForGameOption(data)
	end)
end

function GameOptions:UpdatePause()
	Timers:RemoveTimer("game_options_unpause")
	Convars:SetFloat("host_timescale", 0.1)

	Timers:CreateTimer(0, function()
		self.pauseTime = self.pauseTime - 0.1
		if self.pauseTime > 0 then
			return 0.1
		else
			return nil
		end
	end)
	Timers:CreateTimer("game_options_unpause",{
		useGameTime = false,
		endTime = self.pauseTime/10,
		callback = function()
			Convars:SetFloat("host_timescale", 1)
			return nil
		end
	})
end

function GameOptions:PlayerVoteForGameOption(data)
	if not gameOptions[data.id] then return end

	local player_id = data.PlayerID
	if not player_id then return end

	if gameOptions[data.id].players[player_id] == nil then
		gameOptions[data.id].players[player_id] = true
		local newValue = gameOptions[data.id].votes + 1
		gameOptions[data.id].votes = newValue
		if newValue <= votesForInitOption then
			self.pauseTime = self.pauseTime + 1
			self:UpdatePause()
		end
	else
		gameOptions[data.id].players[player_id] = not gameOptions[data.id].players[player_id]
		local newValue = -1
		if gameOptions[data.id].players[player_id] then
			newValue = 1
		end
		gameOptions[data.id].votes = gameOptions[data.id].votes + newValue
	end

	local gameOptionsVotesForClient = {}
	for id, option in pairs(gameOptions) do
		gameOptionsVotesForClient[id] = option.votes
	end
	CustomNetTables:SetTableValue("game_state", "game_options", gameOptionsVotesForClient)
end

function GameOptions:RecordVotingResults()
	local gameOptionsResults = {}
	for _, option in pairs(gameOptions) do
		gameOptionsResults[option.name] = option.votes >= votesForInitOption
	end

	CustomNetTables:SetTableValue("game_state", "game_options_results", gameOptionsResults)
end

function GameOptions:OptionsIsActive(name)
	for _, option in pairs(gameOptions) do
		if option.name == name and option.votes then return option.votes >= votesForInitOption end
	end
	return nil
end

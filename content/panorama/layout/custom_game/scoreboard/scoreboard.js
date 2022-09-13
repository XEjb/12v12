const team_root_name = (team_id) => {
	return `Scoreboard_Team_${team_id}`;
};
const player_root_name = (player_id) => {
	return `Scoreboard_Player_${player_id}`;
};
const LOCAL_PLAYER_ID = Game.GetLocalPlayerID();

const HUD = {
	ROOT: $.GetContextPanel(),
	TEAMS_ROOT: $("#Scoreboard_TeamsList"),
};
let interval_funcs = {};
const MAP_NAME = Game.GetMapInfo().map_display_name;

function ScoreboardUpdater() {
	Object.values(interval_funcs).forEach((func) => {
		func();
	});
	$.Schedule(0.5, ScoreboardUpdater);
}

function SetPortraitForPlayer(image, player_id) {
	const player_info = Game.GetPlayerInfo(player_id);
	image.SetImage(
		player_info.player_selected_hero !== ""
			? GetPortraitImage(player_id, player_info.player_selected_hero)
			: "file://{images}/custom_game/unassigned.png",
	);
}
function UpdateTeamScore(root, team_id) {
	const team_info = Game.GetTeamDetails(team_id);
	root.SetDialogVariable("team_score", team_info.team_score || 0);
}
function CreateScoreboardTeamPanel(team_id) {
	if (
		team_id < DOTATeam_t.DOTA_TEAM_FIRST ||
		team_id >= DOTATeam_t.DOTA_TEAM_CUSTOM_MAX ||
		team_id == DOTATeam_t.DOTA_TEAM_NOTEAM ||
		team_id == DOTATeam_t.DOTA_TEAM_NEUTRALS
	)
		return;

	const team_root = $.CreatePanel("Panel", HUD.TEAMS_ROOT, team_root_name(team_id));
	team_root.BLoadLayoutSnippet("Scoreboard_Team");
	team_root.SetHasClass("LocalTeam", team_id == Players.GetTeam(LOCAL_PLAYER_ID));
	team_root.SetDialogVariableLocString("team_name", Game.GetTeamDetails(team_id).team_name);
	team_root.AddClass(`Team_${team_id}`);
	team_root.SetDialogVariableInt("team_rank", 0);
	team_root.rank_info = {
		players_count: 0,
		rating: 0,
	};

	if (team_id == 2) {
		HUD.MUTE_ALL_BUTTON_Voice = team_root.FindChildTraverse("MuteAllButton_Voice");
		HUD.MUTE_ALL_BUTTON_Text = team_root.FindChildTraverse("MuteAllButton_Text");
	}

	team_root.players_root = team_root.FindChildTraverse("PlayersList");

	interval_funcs[`UpdateTeamInfo_${team_id}`] = () => {
		UpdateTeamScore(team_root, team_id);
	};

	SortTeams();

	return team_root;
}

function UpdatePlayerStats_Init(root, player_id) {
	const player_info = Game.GetPlayerInfo(player_id);

	root.SetDialogVariable("player_name", player_info.player_name);
	root.SetDialogVariable("player_color", GetHEXPlayerColor(player_id));
	root.SetDialogVariable("hero_name", $.Localize(`#${player_info.player_selected_hero}`));

	const game_stat = CustomNetTables.GetTableValue("game_state", "player_stats");
	const custom_player_info = game_stat ? game_stat[player_id] : {};
	const rating = custom_player_info ? custom_player_info.rating || 1500 : 1500;
	root.SetDialogVariableInt("rank", rating);
	root.b_init = true;

	const team_root = root.GetParent().GetParent();
	const rank_info = team_root.rank_info;
	rank_info.players_count++;
	rank_info.rating += rating;

	team_root.SetDialogVariableInt("team_rank", rank_info.rating / rank_info.players_count);
}

function UpdatePlayerStats(root, player_id) {
	const player_info = Game.GetPlayerInfo(player_id);
	if (!player_info) return;

	if (!root.b_init) UpdatePlayerStats_Init(root, player_id);

	root.SetDialogVariableInt("hero_level", player_info.player_level);
	root.SetDialogVariableInt("kills", player_info.player_kills);
	root.SetDialogVariableInt("deaths", player_info.player_deaths);
	root.SetDialogVariableInt("assists", player_info.player_assists);
	root.SetDialogVariable("player_gold", FormatBigNumber(player_info.player_gold));
}

function UpdateNeutralItemForPlayer(root, player_id) {
	const hero_ent_index = Players.GetPlayerHeroEntityIndex(player_id);
	if (!hero_ent_index) return;

	const neutral_item = Entities.GetItemInSlot(hero_ent_index, 16);
	if (!neutral_item) return;

	root.itemname = Abilities.GetAbilityName(neutral_item);
}
function UpdateDisconnectStateForPlayer(root, player_id) {
	const player_info = Game.GetPlayerInfo(player_id);
	const connection_state = player_info.player_connection_state;
	root.SetHasClass("Disconnected", connection_state == DOTAConnectionState_t.DOTA_CONNECTION_STATE_DISCONNECTED);
	root.SetHasClass("Abandoneded", connection_state == DOTAConnectionState_t.DOTA_CONNECTION_STATE_ABANDONED);
}

function UpdateUltimateState(root, player_id) {
	const ultimate_state = Game.GetPlayerUltimateStateOrTime(player_id);
	if (ultimate_state == undefined) return;
	root.SetHasClass("UltReady", ultimate_state == PlayerUltimateStateOrTime_t.PLAYER_ULTIMATE_STATE_READY);
	root.SetHasClass("UltNoMana", ultimate_state == PlayerUltimateStateOrTime_t.PLAYER_ULTIMATE_STATE_NO_MANA);
}

let players_roots = [];

function CreatePanelForPlayer(player_id) {
	const player_info = Game.GetPlayerInfo(player_id);
	if (!player_info) {
		if (!interval_funcs[`CreatePanelForPlayer_${player_id}`])
			interval_funcs[`CreatePanelForPlayer_${player_id}`] = CreatePanelForPlayer.bind(undefined, player_id);
		return;
	}
	delete interval_funcs[`CreatePanelForPlayer_${player_id}`];

	let player_root = $(`#${player_root_name(player_id)}`);
	if (player_root) return;

	const team_id = Players.GetTeam(player_id);
	const team_root = $(`#${team_root_name(team_id)}`) || CreateScoreboardTeamPanel(team_id);
	if (!team_root) return;

	player_root = $.CreatePanel("Panel", team_root.players_root, player_root_name(player_id));
	player_root.BLoadLayoutSnippet("Scoreboard_Player");
	players_roots.push(player_root);

	player_root.player_id = player_id;
	player_root.team_id = team_id;
	player_root.disable_help_button = player_root.FindChildTraverse("DisableHelpButton");

	player_root.SetHasClass("LocalPlayer", player_id == LOCAL_PLAYER_ID);
	player_root.SetHasClass("BPlayerMuted_Voice", Game.IsPlayerMutedVoice(player_id));
	player_root.SetHasClass("BPlayerMuted_Text", Game.IsPlayerMutedText(player_id));

	const mute = (type) => {
		const is_muted = !Game[`IsPlayerMuted${type}`](player_id);
		Game[`SetPlayerMuted${type}`](player_id, is_muted);

		player_root.SetHasClass(`BPlayerMuted_${type}`, is_muted);
		player_root[`custom_mute_${type}`] = is_muted;

		GameEvents.SendCustomGameEventToServer("update_mute_players", {
			players: { [player_id]: is_muted },
			type: type,
		});
	};
	player_root.mute = mute;

	player_root.FindChildTraverse("MuteButton_Voice").SetPanelEvent("onactivate", () => {
		mute("Voice");
	});
	player_root.FindChildTraverse("MuteButton_Text").SetPanelEvent("onactivate", () => {
		mute("Text");
	});

	const kick_button = player_root.FindChildTraverse("Kick");
	kick_button.SetPanelEvent("onactivate", () => {
		if (HUD.ROOT.BHasClass("BKickVotingEnabled") && player_id != LOCAL_PLAYER_ID)
			GameEvents.SendCustomGameEventToServer("ui_kick_player", { target_id: player_id });
	});
	kick_button.SetPanelEvent("onmouseover", () => {
		HUD.ROOT.RemoveClass("KickGlow");
	});

	interval_funcs[`UpdateDynamicInfo_Scoreboard_Player_${player_id}`] = () => {
		SetPortraitForPlayer(player_root.FindChildTraverse("HeroImage"), player_id);
		UpdatePlayerStats(player_root, player_id);
		UpdateNeutralItemForPlayer(player_root.FindChildTraverse("NeutralItem"), player_id);
		UpdateDisconnectStateForPlayer(player_root, player_id);
	};

	if (team_id == Players.GetTeam(LOCAL_PLAYER_ID)) {
		interval_funcs[`UpdateDynamicInfoTeammate_Scoreboard_Player_${player_id}`] = () => {
			UpdateUltimateState(player_root, player_id);
		};
		const disable_help_button = player_root.FindChildTraverse("DisableHelpButton");
		disable_help_button.SetPanelEvent("onactivate", () => {
			GameEvents.SendCustomGameEventToServer("set_disable_help", {
				disable: disable_help_button.checked,
				to: player_id,
			});
		});
	}
	// TODO Tips for future
	// if (player_id != LOCAL_PLAYER_ID) {
	// 	player_root.FindChildTraverse("Tip").SetPanelEvent("onactivate", () => {
	// 		if (HUD.ROOT.BHasClass("TipsBlock")) return;
	// 		GameEvents.SendCustomGameEventToServer("Tips:tip", { target_player_id: player_id });
	// 	});
	// }

	HighlightByParty(player_id, player_root.FindChildTraverse("PlayerName"));
}

function SortTeams() {
	const radiant = $(`#${team_root_name(2)}`);
	const dire = $(`#${team_root_name(3)}`);

	if (dire && radiant) HUD.TEAMS_ROOT.MoveChildBefore(radiant, dire);
}

function InitPlayers() {
	for (let player_id = 0; player_id <= 23; player_id++) {
		CreatePanelForPlayer(player_id);
	}

	ScoreboardUpdater();
}

function MuteAll(type) {
	let mute_data = {};
	for (const player_id of Game.GetAllPlayerIDs()) {
		const player_panel = $(`#${player_root_name(player_id)}`);
		if (!player_panel) continue;

		if (HUD[`MUTE_ALL_BUTTON_${type}`].checked) {
			player_panel.SetHasClass(`BPlayerMuted_${type}`, true);
			Game[`SetPlayerMuted${type}`](player_id, true);
		} else if (!player_panel[`custom_mute_${type}`]) {
			player_panel.SetHasClass(`BPlayerMuted_${type}`, false);
			Game[`SetPlayerMuted${type}`](player_id, false);
		}
		mute_data[player_id] = Game[`IsPlayerMuted${type}`](player_id);
	}
	GameEvents.SendCustomGameEventToServer("update_mute_players", { players: mute_data, type: type });
}

function SetScoreboardVisibleState(b_show) {
	HUD.ROOT.SetHasClass("Show", b_show);
}

const TIP_COOLDOWN = 30;
let last_tip_cooldown;
function UpdateTips(data) {
	HUD.ROOT.SetHasClass("TipsBlock", data.used_this_game >= data.max_this_game || data.used_total >= data.max_total);

	if (data.cooldown > 0) {
		last_tip_cooldown = data.cooldown;
		const check_tip_cooldown = () => {
			HUD.ROOT.SetHasClass("TipsBlock", Game.GetGameTime() < last_tip_cooldown + TIP_COOLDOWN);
			if (Game.GetGameTime() >= last_tip_cooldown + TIP_COOLDOWN) {
				return;
			}
			$.Schedule(0.5, check_tip_cooldown);
		};
		check_tip_cooldown();
	}
}

function ShowPlayerPerk(event_data) {
	const player_id = event_data.playerId;
	const player_root = $(`#${player_root_name(player_id)}`);
	if (!player_root) return;

	const perk_image = player_root.FindChildTraverse("Perk");

	perk_image.SetImage(`file://{resources}/layout/custom_game/common/game_perks/icons/${event_data.perkName}.png`);
	perk_image.SetPanelEvent("onmouseover", function () {
		$.DispatchEvent(
			"DOTAShowTextTooltip",
			perk_image,
			$.Localize(`DOTA_Tooltip_${event_data.perkName}`, perk_image),
		);
	});
}

function RefreshDisableHelpList() {
	const disable_help = CustomNetTables.GetTableValue("disable_help", Players.GetLocalPlayer());
	if (!disable_help) return;

	const local_team = Players.GetTeam(LOCAL_PLAYER_ID);
	players_roots.forEach((player_root) => {
		if (local_team == player_root.team_id) return;
		if (disable_help[player_root.player_id]) player_root.disable_help_button.checked = true;
	});
}
function MutePlayerByItem(data) {
	const target_id = data.target_id;
	if (!target_id) return;

	const target_root = $(`#${player_root_name(target_id)}`);
	if (!target_root) return;
	target_root.mute("Voice");
	target_root.mute("Text");
}

function SetPlayerPatreonLevel(data) {
	HUD.ROOT.SetHasClass("BKickVotingEnabled", true);
}

(function () {
	HUD.TEAMS_ROOT.RemoveAndDeleteChildren();
	HUD.ROOT.SetHasClass("BKickVotingEnabled", false);

	GameUI.SetDefaultUIEnabled(DotaDefaultUIElement_t.DOTA_DEFAULT_UI_FLYOUT_SCOREBOARD, false);
	InitPlayers();
	SetScoreboardVisibleState(false);
	$.RegisterEventHandler("DOTACustomUI_SetFlyoutScoreboardVisible", HUD.ROOT, SetScoreboardVisibleState);

	GameEvents.SendCustomGameEventToServer("Tips:get_data", {});
	GameEvents.SendCustomGameEventToServer("game_perks:check_perks_for_players", {});
	GameEvents.SendCustomGameEventToServer("voting_for_kick:get_enable_state", {});

	const frame = GameEvents.NewProtectedFrame($.GetContextPanel());
	frame.SubscribeProtected("Tips:update", UpdateTips);
	frame.SubscribeProtected("game_perks:show_player_perk", ShowPlayerPerk);
	frame.SubscribeProtected("set_disable_help_refresh", RefreshDisableHelpList);
	frame.SubscribeProtected("mute_player_item", MutePlayerByItem);
	frame.SubscribeProtected("voting_for_kick:enable", SetPlayerPatreonLevel);
	frame.SubscribeProtected("voting_for_kick:open_scoreboard", () => {
		HUD.ROOT.AddClass("KickGlow");
		SetScoreboardVisibleState(true);
	});
})();

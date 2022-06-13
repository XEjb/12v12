const SYNCED_CHAT_ROOT = $.GetContextPanel();
const MESSAGES_CONTAINER = $("#SC_MessagesContainer");
const TEXT_ENTRY = $("#SC_TextEntry");
const SYMBOLS_COUNTER = $("#SC_SymbolsCounter");
const SUBMIT_BUTTON = $("#SC_Submit");
const ANON_HUD_CHECK = $("#AnonMessageCheck");
const TIMER_HUD = $("#TimerForUpdateRoot").GetChild(1);
const MUTE_LABEL = $("#SC_MuteRoot").GetChild(0);
let OPENED_STATE = false;
let NOT_SUPPORTER = true;
let MESSAGES = {};
let account_id;
let more_mess_button;

const DATE_MULTIPLIERS = {
	DAY: 8.64e7,
	HOUR: 3.6e6,
	MIN: 60000,
	SEC: 1000,
};

const MAX_SYMBOLS = 100;
const LOCAL_PLAYER_INFO = Game.GetLocalPlayerInfo();

function TEXT_LENGTH() {
	return TEXT_ENTRY.text.length;
}

function UpdateChatMessageText() {
	let current_length = TEXT_LENGTH();
	const is_limit = current_length == MAX_SYMBOLS;
	if (is_limit) Game.EmitSound("synced_chat.symbols_limit");
	SYMBOLS_COUNTER.SetHasClass("Limit", is_limit);
	SYMBOLS_COUNTER.SetDialogVariable("curr", current_length);
}
function OpenShop() {
	GameEvents.SendEventClientSideProtected("battlepass_inventory:open_specific_collection", {
		category: "Treasures",
		boostGlow: true,
	});
}
function SendChatMessage() {
	if (SUBMIT_BUTTON.BHasClass("COOLDOWN")) return;
	if (SYNCED_CHAT_ROOT.BHasClass("BPlayerMuted")) return;

	if (TEXT_ENTRY.text == "") return;

	if (NOT_SUPPORTER) {
		OpenShop();
		return;
	}

	GameEvents.SendCustomGameEventToServer("synced_chat:send", {
		steamId: LOCAL_PLAYER_INFO.player_steamid,
		steamName: LOCAL_PLAYER_INFO.player_name,
		text: TEXT_ENTRY.text,
		anon: ANON_HUD_CHECK.IsSelected(),
	});

	TEXT_ENTRY.text = "";
	Game.EmitSound("synced_chat.submit");

	SUBMIT_BUTTON.SetHasClass("COOLDOWN", true);
	$.Schedule(10, () => {
		SUBMIT_BUTTON.SetHasClass("COOLDOWN", false);
	});
}

function AddOlderMessages(data) {
	Object.values(data)
		.reverse()
		.forEach((val) => {
			AddMessage(val, true);
		});
}

function ScrollMessages() {
	const scroll_pos = MESSAGES_CONTAINER.scrolloffset_y;
	const content_height = MESSAGES_CONTAINER.contentheight - MESSAGES_CONTAINER.desiredlayoutheight;
	if (scroll_pos + content_height < 50) {
		$.Schedule(0.2, function () {
			MESSAGES_CONTAINER.ScrollToBottom();
		});
	}
}

function ProcessPollResult(data) {
	if (data.unmute_date) MuteChat({ unmute_date: data.unmute_date });
	if (data.account_id) account_id = data.account_id;

	let check_ping = false;
	if (data.ping) check_ping = true;

	Object.values(data.msg).forEach((val) => {
		AddMessage(val, false, check_ping);
	});
	ScrollMessages();
	SYNCED_CHAT_ROOT.SetHasClass("Loaded", true);

	if (data.pool_delay) {
		let today = new Date();
		today.setSeconds(today.getSeconds() + data.pool_delay);
		next_update_time = today;
	}
}

function ProcessSentMessage(data) {
	AddMessage(data);
	ScrollMessages();
}

let is_ping_cooldown = false;

function AddMessage(msg_data, is_old, check_ping) {
	if (MESSAGES[msg_data.id]) return;

	let text_content = msg_data.Content;
	text_content = text_content.replace(/<:.*:\d*>/g, (token) => {
		token = token.replace(/^</, "").replace(/\d*>/, "");
		return token;
	});
	if (text_content == "") return;

	const message_panel = $.CreatePanel("Panel", MESSAGES_CONTAINER, "SC_Msg_" + msg_data.id);
	message_panel.BLoadLayoutSnippet("SC_MessageLine");

	if (!SYNCED_CHAT_ROOT.BHasClass("Locked"))
		text_content = text_content.replace(/@\d*/g, (token) => {
			let result = token;
			if (account_id && `@${account_id}` == token) {
				result = `<font color='#fcb13b'>@${LOCAL_PLAYER_INFO.player_name}</font>`;
				message_panel.AddClass("Ping");
				if (check_ping) {
					dotaHud.SetHasClass("BSyncedChatPing", !SYNCED_CHAT_ROOT.BHasClass("show"));
					if (!is_ping_cooldown) {
						is_ping_cooldown = true;
						Game.EmitSound("synced_chat.ping");
					} else
						$.Schedule(1, () => {
							is_ping_cooldown = false;
						});
				}
			}
			return result;
		});

	const date_hud = message_panel.FindChildTraverse("SC_Msg_Date");

	const added_at_date = new Date(msg_data.AddedAt);
	let today = new Date();
	today.setMinutes(today.getMinutes() + today.getTimezoneOffset());
	let diff = Math.max(1000, today - added_at_date);

	if (diff >= DATE_MULTIPLIERS.DAY) {
		const days = Math.floor(diff / DATE_MULTIPLIERS.DAY);
		date_hud.text = days > 1 ? LocalizeWithValues("sc_days_ago", { v: days }) : $.Localize("sc_yesterday");
	} else if (diff >= DATE_MULTIPLIERS.HOUR) {
		date_hud.text = LocalizeWithValues("sc_hours_ago", { v: Math.floor(diff / DATE_MULTIPLIERS.HOUR) });
	} else if (diff >= DATE_MULTIPLIERS.MIN) {
		date_hud.text = LocalizeWithValues("sc_mins_ago", { v: Math.floor(diff / DATE_MULTIPLIERS.MIN) });
	} else {
		date_hud.text = LocalizeWithValues("sc_sec_ago", { v: Math.floor(diff / DATE_MULTIPLIERS.SEC) });
	}

	const avatar = message_panel.FindChildTraverse("SC_Msg_Avatar");
	const steam_nickname = message_panel.FindChildTraverse("SC_Msg_Name");

	if (msg_data.SteamId != "-1") {
		if (msg_data.Anonymous == 0) {
			avatar.steamid = msg_data.SteamId;
			steam_nickname.steamid = msg_data.SteamId;
		} else {
			message_panel.AddClass("Anon");
		}
	} else {
		message_panel.AddClass("Dev");
		message_panel.FindChildTraverse("SC_Dev_Name").text = msg_data.SteamName;
	}

	message_panel.FindChildTraverse("SC_Msg_Text").text = text_content;
	MESSAGES[msg_data.id] = message_panel;

	if (is_old) {
		MESSAGES_CONTAINER.MoveChildAfter(message_panel, more_mess_button);
		message_panel.ScrollParentToMakePanelFit(1, true);
	}
}

function CloseSyncedChat() {
	SYNCED_CHAT_ROOT.SetHasClass("show", false);
	OPENED_STATE = false;
	GameEvents.SendCustomGameEventToServer("synced_chat:window_state", {
		state: OPENED_STATE,
	});
	$.DispatchEvent("DropInputFocus");
}

SubscribeToNetTableKey("game_state", "patreon_bonuses", function (patreon_bonuses) {
	let local_stats = patreon_bonuses[Game.GetLocalPlayerID()];
	let level = 0;

	if (local_stats && local_stats.level) {
		level = local_stats.level;
	}

	NOT_SUPPORTER = level == 0;
	SYNCED_CHAT_ROOT.SetHasClass("Locked", NOT_SUPPORTER);
});

function AddButtonToChat(class_name, text_key, callback) {
	const button = $.CreatePanel("Button", MESSAGES_CONTAINER, "");
	button.BLoadLayoutSnippet("MoreMessage");
	button.AddClass(class_name);
	button.GetChild(1).text = $.Localize(text_key);
	button.SetPanelEvent("onactivate", callback);

	return button;
}

let next_update_time;
function UpdateTimer() {
	TIMER_HUD.SetDialogVariable(
		"sec",
		Math.floor(Math.max(next_update_time - new Date(), 0) / 1000)
			.toString()
			.padStart(2, "0"),
	);

	if (unmute_date) {
		let time = {
			days: 0,
			hours: 0,
			mins: 0,
		};
		let today = new Date();
		today.setMinutes(today.getMinutes() + today.getTimezoneOffset());
		let diff = Math.max(0, new Date(unmute_date) - today);

		const set_time = (t_name, format) => {
			let v = Math.floor(diff / format);
			time[t_name] = v.toString().padStart(2, 0);
			diff = diff - format * v;
		};
		set_time("days", 8.64e7);
		set_time("hours", 3.6e6);
		set_time("mins", 60000);
		MUTE_LABEL.text = LocalizeWithValues("sc_mute_date", {
			days: time.days,
			hours: time.hours,
			mins: time.mins,
		});
	}

	$.Schedule(0.5, () => {
		UpdateTimer();
	});
}

function FocusEntry(b_focus) {
	$.Msg(`Focus entry : [${b_focus}]`);
	if (b_focus) {
		SYNCED_CHAT_ROOT.SetHasClass("show", true);
		TEXT_ENTRY.SetFocus();
	} else if (!SYNCED_CHAT_ROOT.BHasHoverStyle()) CloseSyncedChat();
}

let unmute_date;
function MuteChat(data) {
	unmute_date = data.unmute_date;
	SYNCED_CHAT_ROOT.SetHasClass("BPlayerMuted", true);
}

(function () {
	SYNCED_CHAT_ROOT.SetHasClass("BPlayerMuted", false);
	next_update_time = new Date();
	UpdateTimer();
	MESSAGES_CONTAINER.RemoveAndDeleteChildren();

	AddButtonToChat("SuppChat", "loadscreen_become_supp", OpenShop);

	more_mess_button = AddButtonToChat("MoreMessage", "load_more_messages", () => {
		if (NOT_SUPPORTER) return;
		if (more_mess_button.BHasClass("Cooldown")) return;
		GameEvents.SendCustomGameEventToServer("synced_chat:get_older_messages", {});
		more_mess_button.AddClass("Cooldown");
		$.Schedule(10, () => {
			more_mess_button.RemoveClass("Cooldown");
		});
	});

	SYMBOLS_COUNTER.SetDialogVariable("max", MAX_SYMBOLS);
	SYMBOLS_COUNTER.SetDialogVariable("curr", 0);

	GameEvents.SubscribeProtected("synced_chat:poll_result", ProcessPollResult);
	GameEvents.SubscribeProtected("synced_chat:add_older_messages", AddOlderMessages);
	GameEvents.SubscribeProtected("synced_chat:message_sent", ProcessSentMessage);
	GameEvents.SubscribeProtected("synced_chat:mute", MuteChat);

	GameEvents.SendCustomGameEventToServer("synced_chat:request_inital", {});

	GameUI.Custom_OpenSyncedChat = () => {
		SYNCED_CHAT_ROOT.ToggleClass("show");
		if (SYNCED_CHAT_ROOT.BHasClass("show")) SYNCED_CHAT_ROOT.SetFocus();
		Game.EmitSound("ui_chat_slide_in");
		OPENED_STATE = !OPENED_STATE;
		GameEvents.SendCustomGameEventToServer("synced_chat:window_state", {
			state: OPENED_STATE,
		});

		if (SYNCED_CHAT_ROOT.first_open == undefined) {
			SYNCED_CHAT_ROOT.first_open = true;
			$.Schedule(0.1, () => {
				MESSAGES_CONTAINER.ScrollToBottom();
			});
		}
	};
	GameUI.Custom_ShowSyncedChatTooltip = () => {
		dotaHud.RemoveClass("BSyncedChatPing");
		sc_top_button = GameUI.GetTopMenuButton("SyncedChatButton");
		if (!sc_top_button) return;
		$.DispatchEvent("DOTAShowTextTooltip", sc_top_button, "#synced_chat_header");
	};
})();

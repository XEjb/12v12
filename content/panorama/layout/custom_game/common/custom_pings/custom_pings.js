let time_counter = 0;
let b_root_visible = false;
let tracker_hud;

function SetRootPingActive(bool) {
	tracker_hud.hittest = bool;
	HUD_ROOT_FOR_TRACKER.hittestchildren = bool;
}

function ClearActive() {
	for (let i = 1; i <= PINGS_COUNT; i++) {
		$(`#Custom_Ping${i}`).SetHasClass("Active", false);
	}
	HUD_PING_WHEEL.SetHasClass("DefaultPing", false);
}

function PingToServer() {
	for (let i = 1; i <= PINGS_COUNT; i++) {
		const panel = $(`#Custom_Ping${i}`);
		if (panel.BHasClass("Active")) {
			let ping_pos_screen = HUD_PING_WHEEL.GetPositionWithinWindow();
			const x = ping_pos_screen.x + hud_wheel_half_width;
			const y = ping_pos_screen.y + hud_wheel_half_height;
			GameEvents.SendCustomGameEventToServer("custom_ping:ping", {
				pos: Game.ScreenXYToWorld(x, y),
				type: panel.GetAttributeInt("ping-type", 0),
			});
		}
	}
}

function GamePingsTracker() {
	if (GameUI.IsAltDown() && GameUI.IsMouseDown(0)) {
		time_counter += THINK;
	} else {
		if (b_root_visible) PingToServer();
		ClearActive();
		SetRootPingActive(false);
		HUD_PING_WHEEL.visible = false;
		b_root_visible = false;
		time_counter = 0;
	}

	if (time_counter >= TRIGGER_TIME_FOR_WHEEL && !b_root_visible) {
		const cursor = GameUI.GetCursorPosition();
		SetRootPingActive(true);
		$.Schedule(0.01, () => {
			if (tracker_hud.BHasHoverStyle()) {
				HUD_PING_WHEEL.visible = true;
				b_root_visible = true;
				HUD_PING_WHEEL.style.position = `${(cursor[0] - hud_wheel_half_width) / ROOT.actualuiscale_x}px ${
					(cursor[1] - hud_wheel_half_height) / ROOT.actualuiscale_y
				}px 0px`;
			}
		});
	}

	if (b_root_visible) {
		ClearActive();
		const cursor = GameUI.GetCursorPosition();
		const root_pos = HUD_PING_WHEEL.GetPositionWithinWindow();

		const x = cursor[0] - root_pos.x - hud_wheel_half_width;
		const y = root_pos.y - cursor[1] + hud_wheel_half_height;

		let deg = (Math.atan2(y, x) * 180) / Math.PI + (y < 0 ? 360 : 0);

		let element_n = Math.ceil(0.5 + deg / (360 / (PINGS_COUNT - 1)));
		element_n = element_n == 7 ? 1 : element_n;

		const x_abs = Math.abs(x);
		const y_abs = Math.abs(y);
		if (x_abs < MIN_OFFSET && y_abs < MIN_OFFSET) element_n = 7;

		if (x_abs <= MAX_OFFSET * ROOT.actualuiscale_x && y_abs <= MAX_OFFSET * ROOT.actualuiscale_y) {
			const panel = $(`#Custom_Ping${element_n}`);
			if (panel) panel.SetHasClass("Active", true);
			HUD_PING_WHEEL.SetHasClass("DefaultPing", element_n == 7);
		}
	}
	$.Schedule(THINK, () => {
		GamePingsTracker();
	});
}

function ClientPing(data) {
	if (data.type == undefined || PINGS_DATA[data.type] == undefined) return;

	const original_map_width = Math.ceil(minimap.actuallayoutwidth / minimap.actualuiscale_x);
	const original_map_height = Math.ceil(minimap.actuallayoutheight / minimap.actualuiscale_y);

	const world_pos = data.pos.split(" ");
	const coef_x = world_pos[0] / (WORLD_X * 2);
	const coef_y = world_pos[1] / (WORLD_Y * 2);
	const pos_x = (coef_x + 0.5) * original_map_width;
	const pos_y = (0.5 - coef_y) * original_map_height;

	if (pos_x > original_map_width || pos_y > original_map_height) return;

	const new_ping = $.CreatePanel("Panel", HUD_FOR_CUSTOM_PINGS, "");
	new_ping.BLoadLayoutSnippet("CustomPing");

	const margin_side = pos_x - hud_ping_root_half_width + coef_x * 8;
	if (dota_hud.BHasClass("HUDFlipped")) {
		new_ping.style.marginLeft = `${original_map_width - margin_side - hud_ping_root_half_width * 2}px`;
	} else {
		new_ping.style.marginLeft = `${margin_side}px`;
	}

	const margin_top = pos_y + hud_ping_root_half_height - coef_y * 8;

	new_ping.style.marginTop = `${original_map_height - margin_top}px`;

	const image = new_ping.GetChild(0);
	image.AddClass("Pulse");

	if (PINGS_DATA[data.type].image != undefined) {
		image.SetImage(PINGS_DATA[data.type].image);
	}
	if (PINGS_DATA[data.type].sound != undefined) {
		Game.EmitSound(PINGS_DATA[data.type].sound);
	}

	if (data.type == C_PingsTypes.DEFAULT || data.type == C_PingsTypes.DANGER || data.type == C_PingsTypes.WAYPOINT) {
		var player_color = GetHEXPlayerColor(data.player_id);
		image.style.washColor = player_color;
	} else if (data.type == C_PingsTypes.RETREAT) {
		image.style.washColor = "#ff0a0a;";
	}

	let text_label;

	if (data.type == C_PingsTypes.WAYPOINT) {
		let hero_name = Players.GetPlayerSelectedHero(data.player_id);
		new_ping.GetChild(1).SetImage(GetPortraitIcon(data.player_id, hero_name));
		text_label = $.CreatePanel("Label", ROOT, "");
		text_label.AddClass("HeroNamePing");
		text_label.text = $.Localize(hero_name);
		text_label.style.color = player_color;
		text_label.SetParent(tracker_hud);
		$.Schedule(0.01, () => {
			FreezePanel(text_label, parseInt(world_pos[0]), parseInt(world_pos[1]), parseInt(world_pos[2]) + 120);
		});
	}

	$.Schedule(3.5, () => {
		new_ping.DeleteAsync(0);
		if (text_label) text_label.DeleteAsync(0);
	});
}

function FreezePanel(panel, pos_x, pos_y, pos_z) {
	if (!panel.IsValid()) return;
	const sX = Game.WorldToScreenX(pos_x, pos_y, pos_z);
	const sY = Game.WorldToScreenY(pos_x, pos_y, pos_z);

	var x = sX / panel.actualuiscale_x - panel.actuallayoutwidth / 2;
	var y = sY / panel.actualuiscale_y - panel.actuallayoutheight;
	panel.SetPositionInPixels(x, y, 0);
	$.Schedule(0, () => {
		FreezePanel(panel, pos_x, pos_y, pos_z);
	});
}
function ToggleMemorialDesc() {
	$("#MemorialInfo_Root").ToggleClass("Show");
}

function UpdateLocalTimerMemorial() {
	let text = $.Localize("#darklord_memorial_tournament_content");
	const content_block = $("#MemorialInfo_Desc_Text");

	const LOCAL_TIME_LAYOUT = /%%localTime_.*%%/;
	const TIME_FORMAT_24_CLIENTS = ["russian"];
	const ICON_LAYOUT = /%%icon_.*%%/;
	const URL_LAYOUT = /<url>.*<\/url>/;
	const FONT_HTML_BLOCK = /<font.+?<\/font>/g;
	const FONT_HTML_SPACE_FILLER = "!!!!!!!!!!!!!";
	const CONTENT_PARAMS = ["marginTop", "marginRight", "marginLeft"];

	var line;
	const lines = text.split("<br>");

	lines.forEach((t) => {
		if (t.match(LOCAL_TIME_LAYOUT)) {
			let time = t.match(LOCAL_TIME_LAYOUT)[0];
			let date = new Date(time.replace(/%%localTime_(.*)%%/g, "$1"));
			let hours = date.getHours();
			let b_24_format = TIME_FORMAT_24_CLIENTS.indexOf($.Language()) > -1;
			t = t.replace(
				time,
				LocalizeWithValues("tournament_date", {
					t_day_name: $.Localize(`UI_day_${date.getDay() + 1}`),
					t_month: $.Localize(`UI_month_${date.getMonth()}`),
					t_day: date.getDate(),
					t_year: date.getFullYear(),
					t_hour: `0${b_24_format ? hours : hours > 12 ? hours - 12 : hours}`.slice(-2),
					t_min: `0${date.getMinutes()}`.slice(-2),
					ampm: b_24_format ? "" : hours >= 12 ? "PM" : "AM",
				}),
			);
		}

		const content_params = {};
		CONTENT_PARAMS.forEach((p_name) => {
			const v = t.match(new RegExp("<" + p_name + ":\\d*>"));
			if (v != null) {
				t = t.replace(v[0], "");
				content_params[p_name] = v[0];
			}
		});
		if (t.match(ICON_LAYOUT) || t.match(URL_LAYOUT)) {
			line = $.CreatePanel("Panel", content_block, "");
			line.style.flowChildren = "right-wrap";

			t = t.replace(FONT_HTML_BLOCK, (match) => {
				return match.replace(/ /g, FONT_HTML_SPACE_FILLER);
			});

			const split = t.split(" ");
			split.forEach((_t, index) => {
				_t = _t.replace(new RegExp(FONT_HTML_SPACE_FILLER, "g"), " ");
				if (_t.search(ICON_LAYOUT)) {
					const _line = $.CreatePanel("Label", line, "");
					_line.html = true;
					_line.text = `${index == 0 ? "" : "\u00A0"}${_t}`;

					if (!_t.search(URL_LAYOUT)) {
						_line.AddClass("UrlLink");
						_line.text = _line.text.replace(/<\/?url>/g, "").trim();
						_line.SetPanelEvent("onactivate", function () {
							$.DispatchEvent("ExternalBrowserGoToURL", _line.text);
						});
					}
				} else {
					const i = $.CreatePanel("Image", line, "");
					i.SetImage(`file://{images}/custom_game/mail/${_t.match(ICON_LAYOUT)[0].replace(/%/g, "")}.png`);
				}
			});
		} else {
			line = $.CreatePanel("Label", content_block, "");
			line.html = true;
			line.text = t;
		}

		Object.entries(content_params).forEach(([p_name, v]) => {
			line.style[p_name] = `${v.replace(/\D/g, "")}px`;
		});
	});
}

(function () {
	HUD_FOR_CUSTOM_PINGS.RemoveAndDeleteChildren();
	HUD_ROOT_FOR_TRACKER.Children().forEach((p) => {
		if (p.id == "CustomPingsHudTracker") p.DeleteAsync(0);
	});
	const panel = $("#CustomPingsHudTracker");
	panel.SetParent(HUD_ROOT_FOR_TRACKER);
	panel.hittest = true;
	tracker_hud = panel;
	GamePingsTracker();
	UpdateLocalTimerMemorial();
	GameEvents.SubscribeProtected("custom_ping:ping_client", ClientPing);
})();

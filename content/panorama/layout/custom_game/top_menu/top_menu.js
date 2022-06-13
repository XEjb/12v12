const CONTEXT = $.GetContextPanel();
let buttons_cache = {};

function SetPositionForMenu() {
	const menu = $("#CTP_Menu");
	const menu_button = GameUI.GetTopMenuButton("CTP_Menu_Button");
	const button_pos = menu_button.GetPositionWithinWindow();
	if (!button_pos || button_pos.x == Infinity || button_pos.y == Infinity) {
		$.Schedule(0.5, SetPositionForMenu);
		return;
	}

	menu.style.marginLeft = `${button_pos.x / menu_button.actualuiscale_x}px`;
	menu.style.marginTop = `${(button_pos.y + menu_button.actuallayoutheight) / menu_button.actualuiscale_y}px`;
}

(() => {
	const menu = FindDotaHudElement("ButtonBar");
	menu.style.flowChildren = "right-wrap";
	menu.Children().forEach((b) => {
		b.style.margin = "0 5px";
		b.style.verticalAlign = "top";
	});

	CONTEXT.Children().forEach((child) => {
		if (child.paneltype == "Panel") {
			child.Children().forEach((button) => {
				buttons_cache[button.id] = button;
			});
		} else if (child.paneltype == "Button") {
			buttons_cache[child.id] = child;
			const exist_button = menu.FindChild(child.id);
			if (exist_button) exist_button.DeleteAsync(0);
			child.SetParent(menu);
		}
	});

	GameUI.GetTopMenuButton = (name) => {
		return buttons_cache[name];
	};
	GameUI.ToggleCustomTopMenu = (name) => {
		dotaHud.ToggleClass("BShowCustomDropDownTopMenu");
	};
	$.Schedule(0.1, SetPositionForMenu);
})();

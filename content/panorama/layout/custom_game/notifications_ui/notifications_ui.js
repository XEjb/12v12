function WeakTeamNotification(data) {
	const panel = $.CreatePanel("Panel", $("#Norifications_TOP"), "");
	panel.BLoadLayoutSnippet("WeakTeamBonus");

	panel.SetDialogVariable("mmr_diff", data.mmrDiff);
	panel.SetDialogVariable("exp_pct", data.xp_multiplier.toFixed(1));
	panel.SetDialogVariable("gold_pct", data.gold_multiplier.toFixed(1));

	panel.SetHasClass("show", true);

	panel.FindChildTraverse("WeakClose").SetPanelEvent("onactivate", () => {
		panel.SetHasClass("show", false);
	});
}
GameEvents.SubscribeProtected("WeakTeamNotification", WeakTeamNotification);

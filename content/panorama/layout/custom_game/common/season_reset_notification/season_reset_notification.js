const CONTEXT = $.GetContextPanel();

function SetStatus(status) {
	CONTEXT.SetHasClass("visible", status);
}

function SetSeasonResetStatus(event) {
	SetStatus(event.status);
	if (!event.status) {
		return;
	}
	CONTEXT.SetDialogVariableInt("season", event.season);
	CONTEXT.SetDialogVariableInt("new_rating", event.new_rating);
	CONTEXT.SetDialogVariableTime("next_reset_date", event.next_season_timestamp);
}

(() => {
	SetStatus(false);

	GameEvents.SubscribeProtected("SeasonReset:set_status", SetSeasonResetStatus);
	GameEvents.SendCustomGameEventToServer("SeasonReset:get_status", {});
})();

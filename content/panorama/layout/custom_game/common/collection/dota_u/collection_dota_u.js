const GIT_OPTIONS = $("#GitOptions");
function ShowGitOptions() {
	GIT_OPTIONS.SetHasClass("Show", true);
}
function HideGitOptions(delay) {
	const GIT_BUTTON = GameUI.GetTopMenuButton("GitButton");
	$.Schedule(delay, () => {
		GIT_OPTIONS.SetHasClass(
			"Show",
			!GIT_BUTTON || GIT_BUTTON.BHasHoverStyle() || GIT_OPTIONS.BHasHoverStyle() || false,
		);
	});
}

(function () {
	GameUI.Custom_ToggleCollection = () => {
		boostGlow = false;
		ToggleMenu("CollectionDotaU");
	};
	GameUI.Custom_ShowGitOptions = ShowGitOptions;
	GameUI.Custom_HideGitOptions = () => {
		HideGitOptions(0.2);
	};
})();

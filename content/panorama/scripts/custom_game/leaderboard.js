const LOCAL_PLAYER_ID = Game.GetLocalPlayerID();
const LEADERBOARD = $.GetContextPanel();
const LEADERBOARD_DATA = $("#LeaderboardData");
function CloseLeaderboard() {
	LEADERBOARD.SetHasClass("Show", false);
}
(function () {
	CloseLeaderboard();
	GameUI.Custom_ToggleLeaderboard = () => {
		LEADERBOARD.ToggleClass("Show");
	};

	LEADERBOARD_DATA.RemoveAndDeleteChildren();
	SubscribeToNetTableKey("game_state", "leaderboard", (leaderboard_data) => {
		Object.entries(leaderboard_data).forEach(([place, data]) => {
			const panel = $.CreatePanel("Panel", LEADERBOARD_DATA, "");
			panel.BLoadLayoutSnippet("LeaderboardPlayer");

			panel.SetHasClass("dark", place % 2 == 0);
			if (place <= 3) panel.AddClass(`top${place}`);

			const set_value_label = (label_name, var_name, value) => {
				panel.FindChildTraverse(label_name)[var_name] = value;
			};
			set_value_label("RankIndex", "text", place);
			set_value_label("Rating", "text", data.rating);
			set_value_label("player_avatar", "steamid", data.steamId);
			set_value_label("player_user_name", "steamid", data.steamId);
		});
	});
	SubscribeToNetTableKey("game_state", "player_stats", (ratingsObj) => {
		const local_data = ratingsObj[LOCAL_PLAYER_ID];
		if (local_data && local_data.rating) $("#LocalPlayerRating").text = local_data.rating;
	});
})();

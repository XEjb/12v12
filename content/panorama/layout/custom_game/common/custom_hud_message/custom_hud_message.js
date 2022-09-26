const TEXT_LABEL = $("#DOTAU_HudText");
const TEXT_CONTAINER = $("#DOTAU_HudMessageContainer");

function CreateCustomMessage(data) {
	CloseMessage();
	TEXT_CONTAINER.SetHasClass("Show", true);
	TEXT_CONTAINER.SetHasClass("Init", true);
	if (data.message) TEXT_LABEL.text = $.Localize(data.message);
}
function CloseMessage() {
	TEXT_CONTAINER.SetHasClass("Show", false);
	TEXT_CONTAINER.SetHasClass("Init", false);
}
(function () {
	CloseMessage();

	const frame = GameEvents.NewProtectedFrame($.GetContextPanel());
	frame.SubscribeProtected("custom_hud_message:send", CreateCustomMessage);
})();

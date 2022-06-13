"use strict";

//Dont use this file for utility functions, dont require it anywhere except custom_ui_manifest

const token = Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
GameEvents.SendCustomGameEventToServer("secret_token", { token: token });

GameEvents.SubscribeProtected = function (event_name, callback) {
	return GameEvents.Subscribe(event_name, (event) => {
		const player_id = Game.GetLocalPlayerID();
		// Spectators cant send token to server and have to ignore this check
		// This give possibility to ruin spectators custom UI to cheaters, but I think it's not very important
		// Maybe can be fixed if we will generate tokens on server side and send it to clients
		if (player_id == -1 || token == event.chc_secret_token) {
			callback(event.event_data);
		} else {
			$.Msg(
				`Registered event ${event_name} have wrong server token: ${event.chc_secret_token}, for CUSTOM clientside events use GameEvents.SendEventClientSideProtected`,
			);
		}
	});
};

GameEvents.SendEventClientSideProtected = function (event_name, event_data) {
	const event = {
		event_data: event_data,
		chc_secret_token: token,
	};
	GameEvents.SendEventClientSide(event_name, event);
};

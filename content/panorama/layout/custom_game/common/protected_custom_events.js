// Dont use this file for utility functions, dont require it anywhere except custom_ui_manifest
const TOKEN = Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
const MANIFEST_LAYOUT_NAME = $.GetContextPanel().layoutfile;
let FRAMES = {};

/**
 * Subscribes to protected event, checking for token to match current client on every invocation.
 *
 * **WARNING**: lifetime of this subscription is bound to protected events library, it won't be cancelled on other files reload.
 * Use `GameEvents.NewProtectedFrame` for proper protected events lifetime control.
 * @param {String} event_name
 * @param {CallableFunction} callback
 * @returns ID of listener
 */
GameEvents.SubscribeProtected = (event_name, callback) => {
	return GameEvents.Subscribe(event_name, (event) => {
		// Spectators cant send token to server and have to ignore this check
		// This give possibility to ruin spectators custom UI to cheaters, but I think it's not very important
		// Maybe can be fixed if we will generate tokens on server side and send it to clients
		if (Game.GetLocalPlayerID() == -1 || TOKEN == event.protected_token) {
			callback(event.event_data);
		} else {
			throw `Registered event ${event_name} has wrong server token: ${event.protected_token}.
Use GameEvents.Subscribe for vanilla events and GameEvents.SendEventClientSideProtected for custom client-side events`;
		}
	});
};

/**
 * Sends client-side **custom** event in protected way.
 *
 * Otherwise plain clientside event sending fails due to missing token
 * @param {String} event_name
 * @param {Object} event_data
 */
GameEvents.SendEventClientSideProtected = function (event_name, event_data) {
	const event = {
		event_data: event_data,
		protected_token: TOKEN,
	};
	GameEvents.SendEventClientSide(event_name, event);
};

class ProtectedFrame {
	constructor() {
		this.bound_subscriptions = [];
	}

	/**
	 * Subscribes to protected event, checking for token to match current client on every invocation.
	 *
	 * Lifetime of subscription is bound to this `frame`.
	 * @param {String} event_name
	 * @param {CallableFunction} callback
	 * @returns ID of listener
	 */
	SubscribeProtected(event_name, callback) {
		const _id = GameEvents.SubscribeProtected(event_name, callback);
		this.bound_subscriptions.push(_id);
		return _id;
	}

	/**
	 * Basic proxy to subscribe without protection to custom events.
	 *
	 * Mainly used for cases where protected subscription is impossible (i.e. loadscreen that loads earlier than manifest itself)
	 * All this does is invokes event callback with `.event_data` prefetched from protected event payload
	 * @param {String} event_name
	 * @param {CallableFunction} callback
	 * @returns ID of listener
	 */
	Subscribe(event_name, callback) {
		const _id = GameEvents.Subscribe(event_name, (event) => {
			callback(event.event_data);
		});
		this.bound_subscriptions.push(_id);
		return _id;
	}

	/**
	 * Release all subscriptions bound to this protected frame.
	 *
	 * Usually performed automatially on file reload
	 */
	Release() {
		for (const _id of this.bound_subscriptions) {
			GameEvents.Unsubscribe(_id);
		}
	}
}

/**
 * Prepares new protected frame for event subscriptions.
 *
 * Acts as a reload-proxy to cancel all subscriptions related to context file on reload.
 * @param {Panel | string} context - context panel of JS file, from $.GetContextPanel()
 * @returns
 */
GameEvents.NewProtectedFrame = (context) => {
	let file_name;
	if (typeof context == "string") {
		file_name = context;
	} else {
		file_name = context.layoutfile;
	}

	// using frames in manifest-linked js may cause other manifest-linked files to get cancelled
	if (file_name == MANIFEST_LAYOUT_NAME) {
		throw "[Protected Events] WARNING: YOU SHOULD NOT BE USING FRAMES IN MANIFEST-LINKED JAVASCRIPT.\nUse GameEvents.SubscribeProtected directly.";
	}

	const current_frame = FRAMES[file_name];
	if (current_frame) {
		$.Msg(`Releasing existing frame for ${file_name}`);
		current_frame.Release();
	}

	let frame = new ProtectedFrame(file_name);
	FRAMES[file_name] = frame;
	return frame;
};

(() => {
	$.Msg(`[Protected Events] reloaded!`);
	GameEvents.SendCustomGameEventToServer("ProtectedEvents:set_token", { token: TOKEN });
})();

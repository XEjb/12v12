const CONTEXT = $.GetContextPanel();
const MAIL_LIST = $("#MailList");
const MAIL_ACTIVE_TAB = $("#ActiveMailTab");
const MAIL_ATTACHMENTS = $("#MailAttachments");
const MAIL_BUTTON = $("#MailButton");
let collection = FindDotaHudElement("CollectionDotaU");

let selected_mail_id;
let selected_mail_entry;
let mails = {};
let mail_entries = {};

function SetMailPanelState(state) {
	CONTEXT.SetHasClass("visible", state);
}

function ToggleMailPanel() {
	const new_state = !CONTEXT.BHasClass("visible");
	CONTEXT.SetHasClass("visible", new_state);
	if (new_state) OpenFirstMail();
}

function OpenFirstMail() {
	const keys = Object.keys(mails).reverse();
	CONTEXT.SetHasClass("no_mails", keys.length == 0);

	if (keys.length > 0) {
		OpenMailWithId(keys[0], true);
	}

	MAIL_LIST.ScrollToTop();
}

function MailButtonPressed() {
	let mail_data = mails[selected_mail_id];
	if (!mail_data) return;
	const is_active_mail_claimed = mail_data.is_claimed == 1;
	if (is_active_mail_claimed) {
		// delete
		delete mails[selected_mail_id];
		delete mail_entries[selected_mail_id];

		GameEvents.SendCustomGameEventToServer("WebMail:delete_mail", {
			mail_id: selected_mail_id,
		});
		selected_mail_entry.DeleteAsync(0);
		selected_mail_id = undefined;
		selected_mail_entry = undefined;

		OpenFirstMail();

		Game.EmitSound("General.ButtonClick");
	} else {
		// claim
		mail_data.is_claimed = 1;
		MAIL_ACTIVE_TAB.SetHasClass("is_claimed", true);
		selected_mail_entry.SetHasClass("is_claimed", true);

		MAIL_BUTTON.SetDialogVariableLocString("label", "mail_delete");

		GameEvents.SendCustomGameEventToServer("WebMail:claim_mail", {
			mail_id: selected_mail_id,
		});

		Game.EmitSound("General.ButtonClick");
	}
}

function ResolveItemImage(item_name, refetch_flag) {
	if (!collection) {
		collection = FindDotaHudElement("CollectionDotaU");
		if (refetch_flag) return "";
		return ResolveItemImage(item_name, true);
	}

	const item = collection.FindChildTraverse(`Item_${item_name}`);
	if (item) return item.imagePath;
}

function CreateAttachment(attachment_name, count) {
	const attachment_panel = $.CreatePanel("Panel", MAIL_ATTACHMENTS, attachment_name);
	attachment_panel.BLoadLayoutSnippet("attachment");
	attachment_panel.AddClass(attachment_name);
	attachment_panel.SetDialogVariableInt("count", count);
	attachment_panel.SetHasClass("single", count == 1);

	const image_path = ResolveItemImage(attachment_name);
	if (image_path) attachment_panel.GetChild(0).GetChild(0).SetImage(image_path);

	attachment_panel.SetPanelEvent("onmouseover", () => {
		let item_name = $.Localize(`#${attachment_name}`);
		if (MAIL_ACTIVE_TAB.BHasClass("is_claimed")) {
			item_name = `${item_name} (${$.Localize("#attachment_claimed")})`;
		}
		$.DispatchEvent("DOTAShowTextTooltip", attachment_panel, item_name);
	});
	attachment_panel.SetPanelEvent("onmouseout", () => {
		$.DispatchEvent("DOTAHideTextTooltip", attachment_panel);
	});
}

function OpenMailWithId(id, skip_opening) {
	const mail_data = mails[id];
	if (!mail_data) return;

	if (!skip_opening) {
		SetMailPanelState(true);
		Game.EmitSound("ui_topmenu_activate");
	}

	const mail_entry = mail_entries[id];

	if (selected_mail_entry) selected_mail_entry.SetHasClass("selected", false);
	mail_entry.SetHasClass("selected", true);
	selected_mail_entry = mail_entry;

	selected_mail_id = id;
	const is_claimed = mail_data.is_claimed == 1;
	MAIL_ACTIVE_TAB.SetDialogVariable("topic", $.Localize(mail_data.topic));
	MAIL_ACTIVE_TAB.SetDialogVariable("source", $.Localize(mail_data.source));
	MAIL_ACTIVE_TAB.SetDialogVariable("text_content", mail_data.text_content);
	MAIL_ACTIVE_TAB.SetDialogVariable("created_at", mail_data.created_at.substring(0, 19));
	MAIL_ACTIVE_TAB.SetHasClass("is_claimed", is_claimed);

	MAIL_ATTACHMENTS.RemoveAndDeleteChildren();

	MAIL_BUTTON.SetDialogVariableLocString("label", is_claimed ? "mail_delete" : "mail_claim");

	if (mail_data.attachments) {
		for (const [attachment_name, data] of Object.entries(mail_data.attachments)) {
			if (attachment_name == "items") {
				for (const [_, item_data] of Object.entries(data)) {
					CreateAttachment(item_data.name, item_data.count);
				}
			} else {
				CreateAttachment(attachment_name, data);
			}
		}
	}
}

function UpdateMails(event) {
	MAIL_LIST.RemoveAndDeleteChildren();
	selected_mail_entry = undefined;
	selected_mail_id = undefined;
	// reversing since server fetches from first mail to last, and we are interested in latest on top
	for (const [_, mail] of Object.entries(event.mails || {}).reverse()) {
		mails[mail.id] = mail;
		const mail_entry = $.CreatePanel("Panel", MAIL_LIST, mail.id);
		mail_entry.BLoadLayoutSnippet("mail_entry");

		mail_entry.SetDialogVariable("topic", $.Localize(mail.topic));
		mail_entry.SetHasClass("is_claimed", mail.is_claimed == 1);

		mail_entry.SetPanelEvent("onactivate", () => {
			OpenMailWithId(mail.id);
		});

		mail_entries[mail.id] = mail_entry;
	}

	OpenFirstMail();
}

(() => {
	GameEvents.SubscribeProtected("WebMail:update", UpdateMails);
	GameEvents.SendCustomGameEventToServer("WebMail:get_mails", {});

	GameUI.OpenMailWithId = OpenMailWithId;
	GameUI.Custom_ToggleMailPanel = ToggleMailPanel;
})();

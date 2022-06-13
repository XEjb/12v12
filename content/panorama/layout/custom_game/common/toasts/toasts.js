const CONTEXT = $.GetContextPanel();
const DEFAULT_DURATION = 60;

let current_toasts_schedules = {};
let current_toast_id = 0;

function RemoveToast(toast, id) {
	if (current_toasts_schedules[id]) {
		current_toasts_schedules[id] = $.CancelScheduled(current_toasts_schedules[id]);
	}

	toast.SetHasClass("Active", false);
	toast.DeleteAsync(0.5);
}

function PrepareToast(toast, event, toast_id) {
	const image = toast.FindChildTraverse("ToastImage");

	let toast_image_src;
	switch (event.toast_type) {
		case "mail_incoming": {
			toast.SetDialogVariable("topic", $.Localize(event.data.topic));
			toast.SetDialogVariable("source", $.Localize(event.data.source));

			Game.EmitSound("WeeklyQuest.StarGranted");

			toast.SetPanelEvent("onactivate", () => {
				GameUI.OpenMailWithId(event.data.id);
				RemoveToast(toast, toast_id);
			});
			toast_image_src = "file://{images}/custom_game/mail/mail_gold.png";
			break;
		}
		case "payment_success": {
			Game.EmitSound("WeeklyQuest.ClaimReward");
			const product_name = event.data.product_name;
			const product_name_localized = $.Localize(`#${product_name}_purchase_header`);
			let product_name_complete =
				event.data.quantity > 1
					? `${product_name_localized} - x${event.data.quantity}`
					: product_name_localized;

			toast_image_src = GameUI.GetProductIcon(product_name);
			if (event.data.gift_codes) {
				const gift_code_prefix_localized = $.Localize("#toast_gift_code_prefix");
				product_name_complete = `${gift_code_prefix_localized} ${product_name_complete}`;
				// TODO: bind on_activate to open gift codes window
				// alter product name to say "Gift Code for <product name>"
			}
			toast.SetDialogVariable("product_name", product_name_complete);
			toast.SetPanelEvent("onactivate", () => {
				GameEvents.SendEventClientSideProtected("battlepass_inventory:open_specific_collection", {
					category: "Treasures",
					boostGlow: false,
				});
				if (event.data.gift_codes) {
					GameUI.OpenGiftCodes();
				}
				RemoveToast(toast, toast_id);
			});
			break;
		}
		case "payment_fail": {
			const product_name = event.data.product_name;
			toast.SetDialogVariable("product_name", $.Localize(`#${product_name}_purchase_header`));
			toast.SetPanelEvent("onactivate", () => {
				$.DispatchEvent("ExternalBrowserGoToURL", event.data.hosted_invoice_url);
				RemoveToast(toast, toast_id);
			});
			toast_image_src = GameUI.GetProductIcon(product_name);
			break;
		}
	}

	image.SetImage(toast_image_src);

	toast.SetDialogVariable("toast_header", $.Localize(`#toast_${event.toast_type}`, toast));
	toast.SetDialogVariable("toast_description", $.Localize(`#toast_${event.toast_type}_description`, toast));

	toast.SetHasClass("Active", true);
	toast.SetHasClass(event.toast_type, true);

	current_toasts_schedules[current_toast_id] = $.Schedule(DEFAULT_DURATION, () => {
		RemoveToast(toast, current_toast_id);
	});
}

function NewToast(event) {
	if (!event.toast_type) return;

	const toast = $.CreatePanel("Panel", CONTEXT, `${current_toast_id}`);
	toast.BLoadLayoutSnippet("toast");

	const close_button = toast.FindChild("CloseButton");
	close_button.SetPanelEvent("onactivate", () => {
		RemoveToast(toast, current_toast_id);
	});

	PrepareToast(toast, event, current_toast_id);

	current_toast_id++;
}

(() => {
	GameEvents.SubscribeProtected("Toasts:new", NewToast);
	CONTEXT.RemoveAndDeleteChildren();
})();

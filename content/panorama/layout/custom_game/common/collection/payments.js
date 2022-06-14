const PAYMENT_WINDOW = $("#CollectionPayment");
const PRICE_LABEL = $("#Price");
const GIFT_CODE_CHECKER = $("#GiftCodePaymentFlag");
const QUANTITY_CONTAINER = $("#PurchaseQuantityContainer");

const HTML_CONTAINER = $("#PaymentWindow");
const HTML_BROWSER = $("#PaymentWindowHTML");
const HTML_LOADER = $("#PaymentWindowHTML_Loading");
const HTML_WINDOW_LOADER = $("#PaymentWindowLoader");
const HTML_ERROR = $("#PaymentWindowError");

let CURRENT_PRODUCT_NAME;
let CURRENT_QUANTITY = 1;
let AS_GIFT_CODE = false;

function SetPaymentWindowStatus(state) {
	HTML_CONTAINER.SetHasClass("Hidden", state == "closed");
	HTML_LOADER.visible = state == "html";
	HTML_WINDOW_LOADER.visible = state === "loading";
	HTML_BROWSER.visible = state === "html";
	HTML_ERROR.visible = false;
}

function ClosePayment() {
	HTML_CONTAINER.SetHasClass("Hidden", true);
}

function UpdateGiftCodeState() {
	AS_GIFT_CODE = GIFT_CODE_CHECKER.IsSelected();
}

function SetPaymentVisible(state) {
	$("#CollectionPayment").SetHasClass("show", state);
	GIFT_CODE_CHECKER.SetSelected(false);
	UpdateGiftCodeState();
}

function SetQuantity(value) {
	CURRENT_QUANTITY = value;
	QUANTITY_CONTAINER.SetDialogVariableInt("quantity", value);

	const total_price = Math.floor(GameUI.GetProductPrice(CURRENT_PRODUCT_NAME) * CURRENT_QUANTITY * 100) / 100;
	PRICE_LABEL.SetDialogVariable("price", total_price.toFixed(2));

	const header = $.Localize(`#${CURRENT_PRODUCT_NAME}_purchase_header`);
	if (CURRENT_QUANTITY > 1) {
		PAYMENT_WINDOW.SetDialogVariable("purchase_header", `${header} - x${CURRENT_QUANTITY}`);
	} else {
		PAYMENT_WINDOW.SetDialogVariable("purchase_header", header);
	}
}

function ModifyQuantity(value) {
	if (GameUI.IsControlDown()) value *= 5;
	if (!CURRENT_PRODUCT_NAME || !IsQuantityEnabledForProduct(CURRENT_PRODUCT_NAME)) return;
	CURRENT_QUANTITY = Math.max(CURRENT_QUANTITY + value, 1);

	SetQuantity(CURRENT_QUANTITY);
	Game.EmitSound("General.ButtonClick");
}

function InitiatePayment(name) {
	CURRENT_PRODUCT_NAME = name;

	$("#PatreonPaymentButton").visible = name == "base_booster" || name == "golden_booster";

	PAYMENT_WINDOW.SetDialogVariable("purchase_header", $.Localize(`#${name}_purchase_header`));
	PAYMENT_WINDOW.SetDialogVariable("purchase_description", $.Localize(`#${name}_purchase_description`));

	SetQuantity(1);
	QUANTITY_CONTAINER.visible = IsQuantityEnabledForProduct(name);
	GIFT_CODE_CHECKER.visible = IsGiftCodesEnabledForProduct(name);

	PRICE_LABEL.SetDialogVariable("price", GameUI.GetProductPrice(name).toFixed(2));
	PRICE_LABEL.SetAlreadyLocalizedText(GameUI.GetPriceTemplate());

	$("#PurchasingIcon").SetImage(GameUI.GetProductIcon(name));

	SetPaymentVisible(true);
}

function RequestPaymentUrlWithMethod(method) {
	if (!method) return;

	GameEvents.SendCustomGameEventToServer("Payments:request_url", {
		product_name: CURRENT_PRODUCT_NAME,
		payment_method: method,
		as_gift_code: AS_GIFT_CODE,
		quantity: CURRENT_QUANTITY || 1,
	});

	SetPaymentVisible(false);

	if (method != "card") {
		SetPaymentWindowStatus("loading");
	}
}

function OpenPatreonURL() {
	$.DispatchEvent("ExternalBrowserGoToURL", "https://www.patreon.com/dota2unofficial");
	SetPaymentVisible(false);
}

function OpenPaymentURL(event) {
	if (!event.url) return;

	// open chinese payment methods in in-game browser
	if (event.method && event.method != "card") {
		HTML_BROWSER.SetURL(event.url);
		$.Schedule(1, () => {
			SetPaymentWindowStatus("html");
		});
	} else {
		$.DispatchEvent("ExternalBrowserGoToURL", event.url);
	}

	SetPaymentVisible(false);
}

(function () {
	GameUI.InitiatePayment = InitiatePayment;
	GameUI.RequestPaymentUrlWithMethod = RequestPaymentUrlWithMethod;

	GameEvents.SubscribeProtected("Payments:open_url", OpenPaymentURL);
	GameEvents.SubscribeProtected("reset_mmr:show", () => {
		InitiatePayment("reset_mmr");
	});

	SetPaymentWindowStatus("closed");
})();

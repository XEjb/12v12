const CURRENCIES = {
	CNY: "cny",
	USD: "usd",
};

const LANGUAGE_TO_CURRENCY = {
	schinese: "cny",
	tchinese: "cny",
};

// usd is default and defined in GetPriceTemplate
const CURRENCY_TEMPLATES = {
	schinese: "{s:price}元",
	tchinese: "{s:price}元",
};

// PAYMENT_VALUES
const PRODUCTS = {
	base_booster: {
		price: {
			[CURRENCIES.USD]: 8.5,
			[CURRENCIES.CNY]: 55,
		},
		icon: "file://{resources}/images/custom_game/payment/payment_boost.png",
	},
	golden_booster: {
		price: {
			[CURRENCIES.USD]: 34.0,
			[CURRENCIES.CNY]: 220,
		},
		icon: "file://{resources}/images/custom_game/payment/payment_boost.png",
	},
	reset_mmr: {
		price: {
			[CURRENCIES.USD]: 4.99,
			[CURRENCIES.CNY]: 33,
		},
		icon: "file://{resources}/images/custom_game/payment/reset_mmr.png",
		gift_codes_disabled: true,
		quantity_disabled: true,
	},
	glory_bundle_100: {
		price: {
			[CURRENCIES.USD]: 0.99,
			[CURRENCIES.CNY]: 7,
		},
		icon: "file://{images}/custom_game/collection/glory_shop/glory_bundle_100_no_fortune.png",
	},
	glory_bundle_550: {
		price: {
			[CURRENCIES.USD]: 0.99,
			[CURRENCIES.CNY]: 7,
		},
		icon: "file://{images}/custom_game/collection/glory_shop/glory_bundle_550_no_fortune.png",
	},
	glory_bundle_1150: {
		price: {
			[CURRENCIES.USD]: 4.99,
			[CURRENCIES.CNY]: 33,
		},
		icon: "file://{images}/custom_game/collection/glory_shop/glory_bundle_1150_no_fortune.png",
	},
	glory_bundle_3000: {
		price: {
			[CURRENCIES.USD]: 24.99,
			[CURRENCIES.CNY]: 165,
		},
		icon: "file://{images}/custom_game/collection/glory_shop/glory_bundle_3000_no_fortune.png",
	},
	glory_bundle_6500: {
		price: {
			[CURRENCIES.USD]: 49.99,
			[CURRENCIES.CNY]: 330,
		},
		icon: "file://{images}/custom_game/collection/glory_shop/glory_bundle_6500_no_fortune.png",
	},
	glory_bundle_15000: {
		price: {
			[CURRENCIES.USD]: 99.99,
			[CURRENCIES.CNY]: 660,
		},
		icon: "file://{images}/custom_game/collection/glory_shop/glory_bundle_15000_no_fortune.png",
	},
};

function IsGiftCodesEnabledForProduct(product_name) {
	if (!PRODUCTS[product_name]) return true;
	return !PRODUCTS[product_name].gift_codes_disabled;
}

function IsQuantityEnabledForProduct(product_name) {
	if (!PRODUCTS[product_name]) return true;
	return !PRODUCTS[product_name].quantity_disabled;
}

function GetProductPrice(product_name) {
	const currency = LANGUAGE_TO_CURRENCY[$.Language()] || CURRENCIES.USD;
	const product = PRODUCTS[product_name];
	if (!product) return "UNSET";
	return product.price[currency] || "UNSET";
}

function GetProductIcon(product_name) {
	const product = PRODUCTS[product_name];
	if (!product || !product.icon) return "";
	return product.icon;
}

function GetPriceTemplate() {
	return CURRENCY_TEMPLATES[$.Language()] || "${s:price}";
}
function GetProducts() {
	return PRODUCTS;
}

(() => {
	GameUI.GetProductPrice = GetProductPrice;
	GameUI.IsGiftCodesEnabledForProduct = IsGiftCodesEnabledForProduct;
	GameUI.GetProductIcon = GetProductIcon;
	GameUI.GetPriceTemplate = GetPriceTemplate;
	GameUI.GetProducts = GetProducts;
})();

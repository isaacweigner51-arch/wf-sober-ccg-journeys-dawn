extends Node

signal billing_ready(ready: bool)
signal products_updated(products: Dictionary)
signal purchase_completed(product_id: String, pack_count: int)
signal purchase_failed(message: String)

const PRODUCT_TYPE := "inapp"
const RECEIPT_PATH := "user://wf_sober_billing_receipts.cfg"
const PRODUCTS := {
    "wf_sober_packs_5": 5,
    "wf_sober_packs_15": 15,
    "wf_sober_packs_40": 40,
    "wf_sober_packs_80": 80,
}

var billing_client: Object = null
var connected := false
var product_details: Dictionary = {}
var pending_product_id := ""
var processed_tokens: Dictionary = {}

func _ready() -> void:
    _load_receipts()
    call_deferred("initialize")

func initialize() -> void:
    if not OS.has_feature("android"):
        billing_ready.emit(false)
        return
    if ClassDB.class_exists("BillingClient"):
        billing_client = ClassDB.instantiate("BillingClient")
    elif Engine.has_singleton("GodotGooglePlayBilling"):
        billing_client = Engine.get_singleton("GodotGooglePlayBilling")
    if billing_client == null:
        purchase_failed.emit("Google Play Billing plugin is not installed.")
        billing_ready.emit(false)
        return
    _connect_if_available("connected", _on_connected)
    _connect_if_available("disconnected", _on_disconnected)
    _connect_if_available("connect_error", _on_connect_error)
    _connect_if_available("product_details_query_completed", _on_product_details_query_completed)
    _connect_if_available("product_details_query_error", _on_product_details_query_error)
    _connect_if_available("purchases_updated", _on_purchases_updated)
    _connect_if_available("purchase_error", _on_purchase_error)
    _connect_if_available("purchase_consumed", _on_purchase_consumed)
    _connect_if_available("purchase_consumption_error", _on_purchase_consumption_error)
    if billing_client.has_method("start_connection"):
        billing_client.call("start_connection")
    else:
        purchase_failed.emit("The installed billing plugin is incompatible with this build.")
        billing_ready.emit(false)

func _connect_if_available(signal_name: StringName, callback: Callable) -> void:
    if billing_client != null and billing_client.has_signal(signal_name) and not billing_client.is_connected(signal_name, callback):
        billing_client.connect(signal_name, callback)

func is_available() -> bool:
    return connected and billing_client != null

func buy(product_id: String) -> void:
    if not PRODUCTS.has(product_id):
        purchase_failed.emit("Unknown pack product.")
        return
    if not is_available():
        purchase_failed.emit("Google Play purchases are only available in the installed Android app from a Play testing track.")
        return
    pending_product_id = product_id
    if not billing_client.has_method("purchase"):
        purchase_failed.emit("Purchase method is unavailable. Update the Google Play Billing plugin.")
        return
    var arg_count := _method_arg_count("purchase")
    match arg_count:
        1:
            billing_client.call("purchase", product_id)
        2:
            billing_client.call("purchase", product_id, "")
        3:
            billing_client.call("purchase", product_id, "", false)
        _:
            billing_client.call("purchase", product_id)

func refresh_products() -> void:
    if not is_available() or not billing_client.has_method("query_product_details"):
        return
    var ids: Array[String] = []
    for id in PRODUCTS.keys():
        ids.append(str(id))
    billing_client.call("query_product_details", ids, PRODUCT_TYPE)

func restore_pending_purchases() -> void:
    if not is_available():
        purchase_failed.emit("Google Play Billing is not connected.")
        return
    if billing_client.has_method("query_purchases"):
        var arg_count := _method_arg_count("query_purchases")
        if arg_count >= 1:
            billing_client.call("query_purchases", PRODUCT_TYPE)
        else:
            billing_client.call("query_purchases")

func formatted_price(product_id: String, fallback: String) -> String:
    var details: Dictionary = product_details.get(product_id, {})
    for key in ["formatted_price", "formattedPrice", "price"]:
        if details.has(key) and str(details[key]) != "":
            return str(details[key])
    return fallback

func _method_arg_count(method_name: String) -> int:
    if billing_client == null:
        return -1
    for method in billing_client.get_method_list():
        if str(method.get("name", "")) == method_name:
            return int((method.get("args", []) as Array).size())
    return -1

func _on_connected() -> void:
    connected = true
    billing_ready.emit(true)
    refresh_products()
    restore_pending_purchases()

func _on_disconnected() -> void:
    connected = false
    billing_ready.emit(false)

func _on_connect_error(response_code = 0, debug_message = "") -> void:
    connected = false
    purchase_failed.emit("Google Play Billing connection failed: %s" % str(debug_message))
    billing_ready.emit(false)

func _on_product_details_query_completed(result = {}) -> void:
    var list: Array = []
    if result is Dictionary:
        list = result.get("product_details", result.get("result_array", []))
    elif result is Array:
        list = result
    for entry in list:
        if entry is Dictionary:
            var id := _extract_product_id(entry)
            if id != "":
                product_details[id] = entry
    products_updated.emit(product_details)

func _on_product_details_query_error(response_code = 0, debug_message = "", queried_products = []) -> void:
    purchase_failed.emit("Could not load Google Play prices: %s" % str(debug_message))

func _on_purchases_updated(result = {}) -> void:
    var purchases: Array = []
    if result is Dictionary:
        purchases = result.get("purchases", result.get("result_array", []))
    elif result is Array:
        purchases = result
    for purchase in purchases:
        if purchase is Dictionary:
            _process_purchase(purchase)

func _process_purchase(purchase: Dictionary) -> void:
    var product_id := _extract_product_id(purchase)
    if product_id == "" or not PRODUCTS.has(product_id):
        return
    var state = purchase.get("purchase_state", purchase.get("purchaseState", 1))
    if state is int and int(state) != 1 and int(state) != 0:
        return
    var token := str(purchase.get("purchase_token", purchase.get("purchaseToken", "")))
    if token == "":
        token = "%s:%s" % [product_id, str(purchase.hash())]
    if processed_tokens.has(token):
        return
    processed_tokens[token] = product_id
    _save_receipts()
    purchase_completed.emit(product_id, int(PRODUCTS[product_id]))
    pending_product_id = ""
    _consume_purchase(token)

func _extract_product_id(data: Dictionary) -> String:
    for key in ["product_id", "productId", "sku"]:
        if data.has(key) and str(data[key]) != "":
            return str(data[key])
    var products = data.get("products", [])
    if products is Array and products.size() > 0:
        return str(products[0])
    return pending_product_id

func _consume_purchase(token: String) -> void:
    if billing_client == null or token == "" or not billing_client.has_method("consume_purchase"):
        return
    billing_client.call("consume_purchase", token)

func _on_purchase_error(response_code = 0, debug_message = "") -> void:
    pending_product_id = ""
    purchase_failed.emit("Purchase was not completed: %s" % str(debug_message))

func _on_purchase_consumed(purchase_token = "") -> void:
    pass

func _on_purchase_consumption_error(response_code = 0, debug_message = "", purchase_token = "") -> void:
    purchase_failed.emit("Purchase was granted, but Google Play could not mark it consumed yet. It will retry later.")

func _load_receipts() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(RECEIPT_PATH) == OK:
        processed_tokens = cfg.get_value("billing", "processed_tokens", {})

func _save_receipts() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("billing", "processed_tokens", processed_tokens)
    cfg.save(RECEIPT_PATH)

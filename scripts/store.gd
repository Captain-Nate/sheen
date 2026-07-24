extends Node
## Thin StoreKit wrapper over the OpenIAP godot-iap plugin (autoload "GodotIapPlugin").
##
## Only does anything on iOS with the native plugin present. Everywhere else
## (editor / web / macOS) it stays disabled and game.gd keeps its coin / mock-unlock
## path, so the shop is fully testable without a store.

signal product_delivered(product_id: String)   ## entitlement granted (purchase OR restore)
signal purchase_failed(message: String)
signal restore_complete(delivered: int)

const IapTypes := preload("res://addons/godot-iap/types.gd")

## Non-consumable product IDs — must match App Store Connect exactly.
const PRODUCT_IDS: Array[String] = [
	"com.captainnate.sheen.theme.crimson",
	"com.captainnate.sheen.theme.neon",
	"com.captainnate.sheen.theme.matte",
	"com.captainnate.sheen.theme.glacier",
	"com.captainnate.sheen.theme.reef",
	"com.captainnate.sheen.theme.latte",
	"com.captainnate.sheen.theme.arcade",
	"com.captainnate.sheen.themes.all",
]

var available := false          ## true once StoreKit is connected (iOS only)
var status := "starting"        ## human-readable store state, shown in the shop header
var product_count := -1         ## products returned by StoreKit (-1 = not fetched yet)
var _iap: Node = null

func _ready() -> void:
	if OS.get_name() != "iOS":
		status = "off-platform (mock unlocks)"
		print("[store] not iOS — StoreKit disabled (mock unlocks used)")
		return
	_iap = get_node_or_null("/root/GodotIapPlugin")
	if _iap == null:
		status = "plugin missing"
		push_warning("[store] GodotIapPlugin autoload missing — StoreKit disabled")
		return
	_iap.purchase_updated.connect(_on_purchase_updated)
	_iap.purchase_error.connect(_on_purchase_error)
	status = "connecting…"
	_connect_and_load()

func _connect_and_load() -> void:
	var ok: bool = await _iap.init_connection()
	if not ok:
		status = "App Store connection failed"
		push_warning("[store] init_connection failed")
		return
	available = true
	status = "connected — loading products…"
	var req := IapTypes.ProductRequest.new()
	req.skus = PRODUCT_IDS
	req.type = IapTypes.ProductQueryType.IN_APP
	var products: Array = await _iap.fetch_products(req)
	product_count = products.size()
	if product_count == 0:
		status = "connected — 0 products (ASC still propagating?)"
	else:
		status = "connected — %d products" % product_count
	print("[store] ", status)

## Re-ask StoreKit for products if we have none yet (called when the shop opens,
## so a fetch that raced ASC propagation heals without relaunching the app).
func refresh_if_empty() -> void:
	if not available or product_count > 0:
		return
	status = "connected — loading products…"
	var req := IapTypes.ProductRequest.new()
	req.skus = PRODUCT_IDS
	req.type = IapTypes.ProductQueryType.IN_APP
	var products: Array = await _iap.fetch_products(req)
	product_count = products.size()
	if product_count == 0:
		status = "connected — 0 products (ASC still propagating?)"
	else:
		status = "connected — %d products" % product_count
	print("[store] ", status)

## Start a purchase. Result arrives on product_delivered / purchase_failed.
func buy(product_id: String) -> void:
	if not available or product_count <= 0:
		purchase_failed.emit("Store not ready: " + status)
		return
	var props := IapTypes.RequestPurchaseProps.new()
	props.request = IapTypes.RequestPurchasePropsByPlatforms.new()
	props.request.apple = IapTypes.RequestPurchaseIosProps.new()
	props.request.apple.sku = product_id
	props.type = IapTypes.ProductQueryType.IN_APP
	_iap.request_purchase(props)

## Restore previously-bought non-consumables. Fires product_delivered per item.
func restore() -> void:
	if not available:
		restore_complete.emit(0)
		return
	await _iap.restore_purchases()
	var purchases: Array = await _iap.get_available_purchases()
	var n := 0
	for p in purchases:
		var pid := _pid_of(p)
		if pid != "":
			product_delivered.emit(pid)
			n += 1
	restore_complete.emit(n)

func _on_purchase_updated(purchase: Dictionary) -> void:
	var pid := String(purchase.get("productId", ""))
	if pid == "":
		return
	product_delivered.emit(pid)
	# Non-consumable: acknowledge so StoreKit stops replaying it on launch.
	_iap.finish_transaction_dict(purchase, false)

func _on_purchase_error(error: Dictionary) -> void:
	var code := String(error.get("code", ""))
	if code in ["user-cancelled", "userCancelled", "E_USER_CANCELLED", "purchase-cancelled"]:
		return   # user backed out — not an error to surface
	purchase_failed.emit(String(error.get("message", "Purchase failed")))

func _pid_of(p) -> String:
	if p is Dictionary:
		return String(p.get("productId", ""))
	if p != null and p.has_method("to_dict"):
		return String(p.to_dict().get("productId", ""))
	return ""

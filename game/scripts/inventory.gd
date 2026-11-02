extends Node

signal inventory_changed(snapshot: Dictionary)
signal item_used(item_type: StringName)

@export var backpack_capacity: int = 12
var backpack_level: int = 1
var ammo_762: int = 0
var ammo_556: int = 120
var ammo_9mm: int = 90
var ammo_12g: int = 24
var ammo_sniper: int = 20
var medkits: int = 2
var grenades: int = 1
var armor_durability: float = 0.0
var helmet_durability: float = 0.0
var carried_items: int = 0

func _ready() -> void:
	_emit_changed()

func add_item(item_type: StringName, amount: int = 1) -> bool:
	if amount <= 0:
		return false
	var accepted := 0
	match item_type:
		&"ammo_762":
			accepted = mini(amount, max(0, _ammo_capacity() - ammo_762))
			ammo_762 += accepted
		&"ammo_556":
			accepted = mini(amount, max(0, _ammo_capacity() - ammo_556))
			ammo_556 += accepted
		&"ammo_9mm":
			accepted = mini(amount, max(0, _ammo_capacity() - ammo_9mm))
			ammo_9mm += accepted
		&"ammo_12g":
			accepted = mini(amount, max(0, _ammo_capacity() - ammo_12g))
			ammo_12g += accepted
		&"ammo_sniper":
			accepted = mini(amount, max(0, _ammo_capacity() - ammo_sniper))
			ammo_sniper += accepted
		&"medkit":
			accepted = mini(amount, max(0, 5 - medkits))
			medkits += accepted
		&"frag_grenade":
			accepted = mini(amount, max(0, 3 - grenades))
			grenades += accepted
		&"armor":
			var before := armor_durability
			armor_durability = minf(100.0, armor_durability + 50.0 * amount)
			accepted = 1 if armor_durability > before else 0
		&"helmet":
			var before := helmet_durability
			helmet_durability = minf(100.0, helmet_durability + 50.0 * amount)
			accepted = 1 if helmet_durability > before else 0
		&"backpack":
			var before := backpack_level
			backpack_level = mini(3, backpack_level + amount)
			backpack_capacity = 12 + (backpack_level - 1) * 6
			accepted = backpack_level - before
		_:
			return false
	if accepted <= 0:
		return false
	carried_items += accepted
	_emit_changed()
	return true

func get_ammo(ammo_type: StringName) -> int:
	match ammo_type:
		&"ammo_762": return ammo_762
		&"ammo_556": return ammo_556
		&"ammo_9mm": return ammo_9mm
		&"ammo_12g": return ammo_12g
		&"ammo_sniper": return ammo_sniper
		_: return 0

func consume_ammo(amount: int, ammo_type: StringName = &"ammo_sniper") -> int:
	var used := mini(maxi(amount, 0), get_ammo(ammo_type))
	match ammo_type:
		&"ammo_762": ammo_762 -= used
		&"ammo_556": ammo_556 -= used
		&"ammo_9mm": ammo_9mm -= used
		&"ammo_12g": ammo_12g -= used
		&"ammo_sniper": ammo_sniper -= used
	_emit_changed()
	return used

func consume_grenade() -> bool:
	if grenades <= 0:
		return false
	grenades -= 1
	item_used.emit(&"frag_grenade")
	_emit_changed()
	return true

func use_medkit() -> bool:
	if medkits <= 0:
		return false
	var health := get_parent().get_node_or_null("Health")
	if health == null or float(health.get("current_health")) >= float(health.get("maximum_health")):
		return false
	medkits -= 1
	health.call("heal", 45.0)
	item_used.emit(&"medkit")
	_emit_changed()
	return true

func absorb_damage(amount: float) -> float:
	var remaining := maxf(0.0, amount)
	if armor_durability > 0.0:
		var absorbed := minf(armor_durability, remaining * 0.30)
		armor_durability -= absorbed
		remaining -= absorbed
	if helmet_durability > 0.0:
		var absorbed_helmet := minf(helmet_durability, remaining * 0.15)
		helmet_durability -= absorbed_helmet
		remaining -= absorbed_helmet
	_emit_changed()
	return remaining

func _ammo_capacity() -> int:
	return 60 + (backpack_level - 1) * 60

func get_snapshot() -> Dictionary:
	return {
		"ammo_762": ammo_762,
		"ammo_556": ammo_556,
		"ammo_9mm": ammo_9mm,
		"ammo_12g": ammo_12g,
		"ammo_sniper": ammo_sniper,
		"medkits": medkits,
		"grenades": grenades,
		"armor": roundi(armor_durability),
		"helmet": roundi(helmet_durability),
		"backpack_level": backpack_level,
		"capacity": backpack_capacity
	}

func _emit_changed() -> void:
	inventory_changed.emit(get_snapshot())

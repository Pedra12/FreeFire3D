extends Node3D

@export var weapon_path: String = "res://assets/weapons/awm_free_fire.glb"
@export var target_weapon_length: float = 0.82
@export var hand_offset: Vector3 = Vector3(0.02, -0.12, 0.10)
@export var hand_rotation_degrees: Vector3 = Vector3(0.0, -90.0, 0.0)
@export var debug_visible_fallback := true

const WEAPON_CATALOG := {
	&"awm": {"path":"res://assets/weapons/awm_free_fire.glb","length":0.82},
	&"assault_rifle": {"path":"res://assets/weapons/assault_rifle.glb","length":0.83},
	&"smg": {"path":"res://assets/weapons/smg.glb","length":0.45},
	&"shotgun": {"path":"res://assets/weapons/shotgun.glb","length":0.92},
	&"pistol": {"path":"res://assets/weapons/pistol.glb","length":0.20}
}
const HAND_HINTS := ["righthand","right_hand","hand_r","mixamorigrighthand","wrist_r","rightwrist"]

var mounted_weapon: Node3D
var weapon_attachment: Node3D
var current_weapon_id: StringName = &"awm"
var _request_id := 0

func _ready() -> void:
	call_deferred("_attach_weapon", _request_id)

func equip_weapon(weapon_id: StringName) -> bool:
	if not WEAPON_CATALOG.has(weapon_id):
		push_warning("WEAPON_MOUNT: unknown weapon " + String(weapon_id))
		return false
	var config: Dictionary = WEAPON_CATALOG[weapon_id]
	var next_path := String(config["path"])
	if not ResourceLoader.exists(next_path):
		push_warning("WEAPON_MOUNT: missing model " + next_path)
		return false
	current_weapon_id = weapon_id
	weapon_path = next_path
	target_weapon_length = float(config["length"])
	_request_id += 1
	call_deferred("_attach_weapon", _request_id)
	return true

func _find_right_hand(skeleton: Skeleton3D) -> int:
	for hint in HAND_HINTS:
		for index in range(skeleton.get_bone_count()):
			var normalized := String(skeleton.get_bone_name(index)).to_lower().replace(":", "").replace(" ", "")
			if normalized == hint.replace(":", "").replace(" ", ""):
				return index
	for index in range(skeleton.get_bone_count()):
		var name := String(skeleton.get_bone_name(index)).to_lower()
		if name.contains("hand") and (name.contains("right") or name.ends_with("_r") or name.begins_with("r_")):
			return index
	for index in range(skeleton.get_bone_count()):
		var name := String(skeleton.get_bone_name(index)).to_lower()
		if name.contains("wrist") and (name.contains("right") or name.ends_with("_r") or name.begins_with("r_")):
			return index
	return -1

func _attach_weapon(request_id: int = -1) -> void:
	await get_tree().process_frame
	if not is_inside_tree() or (request_id >= 0 and request_id != _request_id):
		return
	var character := get_parent()
	var model: Node3D
	for path in ["VisualRoot/Olivia","VisualRoot/FemalePlayer","VisualRoot/CharacterModel"]:
		model = character.get_node_or_null(path) as Node3D
		if model != null:
			break
	if model == null:
		push_warning("WEAPON_MOUNT: character visual not found at " + str(character.get_path()))
		return

	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	var skeleton: Skeleton3D = skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
	var hand_index := _find_right_hand(skeleton) if skeleton != null else -1
	var attachment: Node3D
	if hand_index >= 0:
		var bone_attachment := BoneAttachment3D.new()
		bone_attachment.name = "RightHandWeaponAttachment"
		bone_attachment.bone_name = skeleton.get_bone_name(hand_index)
		skeleton.add_child(bone_attachment)
		attachment = bone_attachment
		attachment.position = hand_offset
		attachment.rotation_degrees = hand_rotation_degrees
	else:
		if not debug_visible_fallback:
			push_warning("WEAPON_MOUNT: no right-hand bone found; weapon not attached")
			return
		# Visible fallback keeps the weapon rendered while a rig naming issue is diagnosed.
		attachment = Node3D.new()
		attachment.name = "WeaponVisibleFallback"
		model.add_child(attachment)
		attachment.position = Vector3(0.24, 0.92, 0.12)
		attachment.rotation_degrees = hand_rotation_degrees
		push_warning("WEAPON_MOUNT: right-hand bone unavailable; using visible fallback")

	var packed := load(weapon_path) as PackedScene
	if packed == null:
		attachment.queue_free()
		push_warning("WEAPON_MOUNT: unable to load " + weapon_path)
		return
	var weapon := packed.instantiate() as Node3D
	if weapon == null:
		attachment.queue_free()
		push_warning("WEAPON_MOUNT: weapon root is not Node3D")
		return
	var bounds := AABB()
	var has_bounds := false
	for item in weapon.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := item as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var local_bounds := mesh_instance.get_aabb() * mesh_instance.transform
		bounds = local_bounds if not has_bounds else bounds.merge(local_bounds)
		has_bounds = true
		for surface in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.get_active_material(surface)
			if material is BaseMaterial3D:
				var two_sided := (material as BaseMaterial3D).duplicate() as BaseMaterial3D
				two_sided.cull_mode = BaseMaterial3D.CULL_DISABLED
				mesh_instance.set_surface_override_material(surface, two_sided)
	if not has_bounds:
		weapon.queue_free()
		attachment.queue_free()
		push_warning("WEAPON_MOUNT: weapon contains no visible mesh surfaces")
		return
	var longest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if longest <= 0.0001:
		weapon.queue_free()
		attachment.queue_free()
		push_warning("WEAPON_MOUNT: invalid weapon bounds")
		return
	weapon.scale = Vector3.ONE * (target_weapon_length / longest)
	weapon.position = -bounds.get_center() * weapon.scale
	attachment.add_child(weapon)
	if is_instance_valid(weapon_attachment):
		weapon_attachment.queue_free()
	weapon_attachment = attachment
	mounted_weapon = weapon
	print("WEAPON_MOUNT_OK id=", current_weapon_id, " bone=", skeleton.get_bone_name(hand_index) if hand_index >= 0 else "VISIBLE_FALLBACK", " mesh_count=", weapon.find_children("*","MeshInstance3D",true,false).size())

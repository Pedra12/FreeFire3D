extends Node3D

@export var weapon_path: String = "res://assets/weapons/awm_free_fire.glb"
@export var preferred_bones: Array[StringName] = [
	&"hand_r",
	&"RightHand",
	&"mixamorig:RightHand",
	&"right_hand"
]
@export var target_weapon_length: float = 0.82
@export var hand_offset: Vector3 = Vector3(0.02, -0.22, 0.24)
@export var hand_rotation_degrees: Vector3 = Vector3(0.0, -90.0, 0.0)

const WEAPON_CATALOG := {
	&"awm": {"path": "res://assets/weapons/awm_free_fire.glb", "length": 0.82},
	&"assault_rifle": {"path": "res://assets/weapons/assault_rifle.glb", "length": 0.83},
	&"smg": {"path": "res://assets/weapons/smg.glb", "length": 0.45},
	&"shotgun": {"path": "res://assets/weapons/shotgun.glb", "length": 0.92},
	&"pistol": {"path": "res://assets/weapons/pistol.glb", "length": 0.20}
}

var mounted_weapon: Node3D
var weapon_attachment: BoneAttachment3D
var current_weapon_id: StringName = &"awm"

func _ready() -> void:
	call_deferred("_attach_weapon")

func equip_weapon(weapon_id: StringName) -> bool:
	if not WEAPON_CATALOG.has(weapon_id):
		push_warning("WEAPON_MOUNT: unknown weapon " + String(weapon_id))
		return false
	var config: Dictionary = WEAPON_CATALOG[weapon_id]
	var next_path: String = String(config["path"])
	if not FileAccess.file_exists(next_path):
		push_warning("WEAPON_MOUNT: missing model " + next_path)
		return false
	current_weapon_id = weapon_id
	weapon_path = next_path
	target_weapon_length = float(config["length"])
	call_deferred("_attach_weapon")
	return true

func _attach_weapon() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var character := get_parent()
	var model: Node3D = character.get_node_or_null("VisualRoot/Olivia") as Node3D
	if model == null:
		model = character.get_node_or_null("VisualRoot/FemalePlayer") as Node3D
	if model == null:
		model = character.get_node_or_null("VisualRoot/CharacterModel") as Node3D
	if model == null:
		push_warning("WEAPON_MOUNT: character visual not found")
		return

	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		push_warning("WEAPON_MOUNT: Skeleton3D not found")
		return
	var skeleton := skeletons[0] as Skeleton3D
	var selected_bone: StringName = &""
	for candidate in preferred_bones:
		if skeleton.find_bone(candidate) >= 0:
			selected_bone = candidate
			break
	if selected_bone == &"":
		push_warning("WEAPON_MOUNT: right hand bone not found")
		return

	var packed := load(weapon_path) as PackedScene
	if packed == null:
		push_warning("WEAPON_MOUNT: weapon asset unavailable: " + weapon_path)
		return
	var weapon := packed.instantiate() as Node3D
	if weapon == null:
		push_warning("WEAPON_MOUNT: weapon scene root is not Node3D")
		return

	var mesh_nodes := weapon.find_children("*", "MeshInstance3D", true, false)
	var largest_dimension := 0.0
	for item in mesh_nodes:
		var mesh := item as MeshInstance3D
		if mesh.mesh == null:
			continue
		var extent := mesh.get_aabb().size
		largest_dimension = maxf(largest_dimension, maxf(extent.x, maxf(extent.y, extent.z)))
	if largest_dimension <= 0.000001:
		weapon.queue_free()
		push_warning("WEAPON_MOUNT: weapon geometry has no measurable bounds")
		return

	if is_instance_valid(weapon_attachment):
		weapon_attachment.queue_free()
	var attachment := BoneAttachment3D.new()
	attachment.name = "RightHandWeaponAttachment"
	attachment.bone_name = selected_bone
	skeleton.add_child(attachment)
	attachment.position = hand_offset
	attachment.rotation_degrees = hand_rotation_degrees
	weapon.scale = Vector3.ONE * (target_weapon_length / largest_dimension)
	attachment.add_child(weapon)
	weapon_attachment = attachment
	mounted_weapon = weapon
	print("WEAPON_MOUNT_OK id=", current_weapon_id, " bone=", selected_bone, " scale=", weapon.scale, " meshes=", mesh_nodes.size())

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

var mounted_weapon: Node3D

func _ready() -> void:
	call_deferred("_attach_weapon")

func _attach_weapon() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var character := get_parent()
	var model := character.get_node_or_null("VisualRoot/FemalePlayer") as Node3D
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
		var bounds := mesh.get_aabb()
		var extent := bounds.size
		largest_dimension = maxf(largest_dimension, maxf(extent.x, maxf(extent.y, extent.z)))
	if largest_dimension <= 0.000001:
		weapon.queue_free()
		push_warning("WEAPON_MOUNT: weapon geometry has no measurable bounds")
		return

	var attachment := BoneAttachment3D.new()
	attachment.name = "RightHandWeaponAttachment"
	attachment.bone_name = selected_bone
	skeleton.add_child(attachment)
	attachment.position = hand_offset
	attachment.rotation_degrees = hand_rotation_degrees
	weapon.scale = Vector3.ONE * (target_weapon_length / largest_dimension)
	attachment.add_child(weapon)
	mounted_weapon = weapon
	print("WEAPON_MOUNT_OK bone=", selected_bone, " scale=", weapon.scale, " meshes=", mesh_nodes.size())

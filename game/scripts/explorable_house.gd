extends Node3D

## A deliberately walkable two-storey combat house used to calibrate world scale.
## The visible stair treads sit over a continuous ramp collider so CharacterBody3D
## and bots can climb it without a custom step-up controller.
@export var wall_height: float = 3.0
@export var wall_thickness: float = 0.22
@export var house_width: float = 10.0
@export var house_depth: float = 9.0

var wall_material := StandardMaterial3D.new()
var floor_material := StandardMaterial3D.new()
var stair_material := StandardMaterial3D.new()
var roof_material := StandardMaterial3D.new()

func _ready() -> void:
	wall_material.albedo_color = Color(0.67, 0.58, 0.43)
	wall_material.roughness = 0.92
	floor_material.albedo_color = Color(0.30, 0.25, 0.19)
	floor_material.roughness = 0.95
	stair_material.albedo_color = Color(0.42, 0.29, 0.17)
	stair_material.roughness = 0.9
	roof_material.albedo_color = Color(0.20, 0.24, 0.27)
	roof_material.roughness = 0.9
	_build_house()

func _build_house() -> void:
	# Ground and upper floor slabs. The upper slab leaves a stairwell opening.
	_add_box("GroundFloor", Vector3(0, -0.12, 0), Vector3(10.0, 0.24, 9.0), floor_material, true)
	_add_box("UpperFloorLeft", Vector3(-1.55, 2.88, 0), Vector3(6.9, 0.24, 9.0), floor_material, true)
	_add_box("UpperFloorRight", Vector3(4.55, 2.88, 0), Vector3(0.9, 0.24, 9.0), floor_material, true)
	_add_box("UpperFloorBack", Vector3(3.1, 2.88, -3.65), Vector3(2.0, 0.24, 1.7), floor_material, true)

	# Ground-floor outer walls with a 1.6m x 2.2m front doorway.
	_add_wall("FrontLeft", Vector3(-2.9, 1.5, -4.39), Vector3(4.2, 3.0, 0.22))
	_add_wall("FrontRight", Vector3(2.9, 1.5, -4.39), Vector3(4.2, 3.0, 0.22))
	_add_wall("FrontLintel", Vector3(0, 2.62, -4.39), Vector3(1.6, 0.76, 0.22))
	_add_wall("BackWall", Vector3(0, 1.5, 4.39), Vector3(10.0, 3.0, 0.22))
	_add_wall("LeftWall", Vector3(-4.89, 1.5, 0), Vector3(0.22, 3.0, 8.8))
	_add_wall("RightWall", Vector3(4.89, 1.5, 0), Vector3(0.22, 3.0, 8.8))

	# Upper floor walls and roof, also with a front doorway for visibility/access.
	_add_wall("UpperFrontLeft", Vector3(-2.9, 4.5, -4.39), Vector3(4.2, 3.0, 0.22))
	_add_wall("UpperFrontRight", Vector3(2.9, 4.5, -4.39), Vector3(4.2, 3.0, 0.22))
	_add_wall("UpperFrontLintel", Vector3(0, 5.62, -4.39), Vector3(1.6, 0.76, 0.22))
	_add_wall("UpperBackWall", Vector3(0, 4.5, 4.39), Vector3(10.0, 3.0, 0.22))
	_add_wall("UpperLeftWall", Vector3(-4.89, 4.5, 0), Vector3(0.22, 3.0, 8.8))
	_add_wall("UpperRightWall", Vector3(4.89, 4.5, 0), Vector3(0.22, 3.0, 8.8))
	_add_box("Roof", Vector3(0, 6.12, 0), Vector3(10.2, 0.24, 9.2), roof_material, true)

	# Internal partition walls leave the central room open.
	_add_wall("GroundPartition", Vector3(-1.6, 1.5, 0.7), Vector3(0.18, 3.0, 5.2))
	_add_wall("UpperPartition", Vector3(-1.6, 4.5, 0.7), Vector3(0.18, 3.0, 5.2))

	# A smooth collision ramp follows the visible stair treads, rising 3m over 4.5m.
	var ramp_angle := atan2(3.0, 4.5)
	_add_ramp("StairRamp", Vector3(3.15, 1.50, 0.85), Vector3(1.18, 0.18, 5.42), ramp_angle)
	for i in range(16):
		var rise := 3.0 * float(i + 1) / 16.0
		var run := 4.5 * float(i + 1) / 16.0
		_add_visual_box("StairTread_%02d" % i,
			Vector3(3.15, rise - 0.08, 3.1 - run),
			Vector3(1.18, 0.16, 0.34), stair_material)

	# Landing and simple door frames make the entrance legible in third person.
	_add_box("UpperLanding", Vector3(3.15, 3.04, -1.72), Vector3(1.5, 0.12, 1.0), floor_material, true)
	_add_visual_box("DoorFrameLeft", Vector3(-0.92, 1.12, -4.30), Vector3(0.12, 2.24, 0.12), stair_material)
	_add_visual_box("DoorFrameRight", Vector3(0.92, 1.12, -4.30), Vector3(0.12, 2.24, 0.12), stair_material)

func _add_wall(node_name: String, at: Vector3, size: Vector3) -> void:
	_add_box(node_name, at, size, wall_material, true)

func _add_box(node_name: String, at: Vector3, size: Vector3, material: Material, collision: bool) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 1
	add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	if collision:
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		body.add_child(shape_node)

func _add_visual_box(node_name: String, at: Vector3, size: Vector3, material: Material) -> void:
	_add_box(node_name, at, size, material, false)

func _add_ramp(node_name: String, at: Vector3, size: Vector3, angle: float) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = at
	body.rotation.x = angle
	body.collision_layer = 1
	body.collision_mask = 1
	add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = stair_material
	body.add_child(mesh_instance)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)

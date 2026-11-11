class_name ScreenPanel
extends Node3D

## A cockpit monitor: a dark frame with a quad showing a small 2D scene rendered by a
## SubViewport. Subclasses fill `viewport` with controls in `build_screen()`.
## The panel faces +Z like the dashboard, so it is placed with the same orientation.

@export var screen_size := Vector2(0.72, 1.0)
@export var pixels_per_meter := 500.0
@export var frame_color := Color(0.05, 0.055, 0.07)

var viewport: SubViewport


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(screen_size * pixels_per_meter)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	build_screen()

	var frame_material := StandardMaterial3D.new()
	frame_material.albedo_color = frame_color
	frame_material.roughness = 0.9
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(screen_size.x + 0.08, screen_size.y + 0.08, 0.04)
	frame_mesh.material = frame_material
	var frame := MeshInstance3D.new()
	frame.mesh = frame_mesh
	frame.position.z = -0.03
	add_child(frame)

	var screen_material := StandardMaterial3D.new()
	screen_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen_material.albedo_texture = viewport.get_texture()
	var quad_mesh := QuadMesh.new()
	quad_mesh.size = screen_size
	quad_mesh.material = screen_material
	var quad := MeshInstance3D.new()
	quad.mesh = quad_mesh
	add_child(quad)


## Override: add the screen's controls to `viewport`.
func build_screen() -> void:
	pass

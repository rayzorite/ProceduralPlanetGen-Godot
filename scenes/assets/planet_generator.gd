extends MeshInstance3D

@export_group("Planet Settings")
@export_range(4, 64) var resolution: int = 16
@export_range(5, 20) var noise_scale: float = 7.0
@export_range(0.1, 0.5) var elevation_amplitude: float = 0.2
@export_range(-0.5, 0.5) var sea_level_bias := 0.25
@export var radius: float = 1.0
@export var planet_seed: int = 0

var noise := FastNoiseLite.new()
var planet_data: Array = []

@onready var randomize_planet_btn: Button = %RandomizePlanetBtn


# ============================================================
# === INITIALIZATION =========================================
# ============================================================

func _ready():
	if randomize_planet_btn:
		randomize_planet_btn.pressed.connect(_randomize_planet)
	else:
		push_warning("⚠️ RandomizePlanetBtn not found in scene!")

	if planet_seed == 0:
		planet_seed = randi()

	noise.seed = planet_seed
	_regenerate_planet()


# ============================================================
# === MAIN GENERATION LOGIC ==================================
# ============================================================

func _randomize_planet():
	planet_seed = randi()
	noise.seed = planet_seed
	print("🎲 Randomized planet seed:", planet_seed)
	_regenerate_planet()


func _regenerate_planet():
	if resolution < 4:
		return

	planet_data.clear()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for face in range(6):
		var local_up: Vector3 = get_face_direction(face)
		_generate_face(st, local_up)

	mesh = st.commit()

	# === Shader Setup ===
	if not material_override:
		material_override = ShaderMaterial.new()
		material_override.shader = load("uid://ow5jfk0mf24k")

	var mat := material_override as ShaderMaterial
	mat.set_shader_parameter("radius", radius)
	mat.set_shader_parameter("elevation_amplitude", elevation_amplitude)
	mat.set_shader_parameter("sea_level_bias", sea_level_bias)
	mat.set_shader_parameter("ocean_color", Color(0.0, 0.561, 0.918, 1.0))
	mat.set_shader_parameter("planet_seed", float(planet_seed))  # 👈 pass seed to shader

	mesh.surface_set_material(0, mat)

	print("🌍 Planet regenerated → vertices:", planet_data.size(), " | Seed:", planet_seed)

# ============================================================
# === GEOMETRY ===============================================
# ============================================================

func get_face_direction(face: int) -> Vector3:
	return [
		Vector3.FORWARD, Vector3.BACK,
		Vector3.UP, Vector3.DOWN,
		Vector3.RIGHT, Vector3.LEFT
	][face]


func _generate_face(st: SurfaceTool, local_up: Vector3) -> void:
	var axis_a := Vector3(local_up.y, local_up.z, local_up.x)
	var axis_b := local_up.cross(axis_a)

	var grid := []
	grid.resize(resolution)
	for i in range(resolution):
		grid[i] = []
		for j in range(resolution):
			grid[i].append(null)

	for y in range(resolution):
		for x in range(resolution):
			var percent := Vector2(x, y) / float(resolution - 1)
			var point_on_unit_cube := (
				local_up +
				(percent.x - 0.5) * 2.0 * axis_a +
				(percent.y - 0.5) * 2.0 * axis_b
			)
			var point_on_sphere := point_on_unit_cube.normalized()
			var base_continent := noise.get_noise_3dv(point_on_sphere * (noise_scale * 0.3))
			var detail := noise.get_noise_3dv(point_on_sphere * noise_scale * 2.0)
			var islands := base_continent * 0.6 + detail * 0.4

			var elevation := pow(max(islands, 0.0), 1.3) * 2.0 - sea_level_bias
			var final_pos := point_on_sphere * (radius + elevation * elevation_amplitude)
			var normal := point_on_sphere

			grid[y][x] = {
				"pos": final_pos,
				"normal": normal,
				"height": final_pos.length(),
				"temperature": clamp(1.0 - abs(point_on_sphere.y), 0.0, 1.0),
			}

	for y in range(resolution - 1):
		for x in range(resolution - 1):
			var v00 = grid[y][x]
			var v10 = grid[y][x + 1]
			var v01 = grid[y + 1][x]
			var v11 = grid[y + 1][x + 1]

			_push_vertex_with_attrs(st, v00)
			_push_vertex_with_attrs(st, v01)
			_push_vertex_with_attrs(st, v11)
			_push_vertex_with_attrs(st, v00)
			_push_vertex_with_attrs(st, v11)
			_push_vertex_with_attrs(st, v10)


func _push_vertex_with_attrs(st: SurfaceTool, v: Dictionary) -> void:
	var biome := _get_biome(v["height"], v["temperature"])
	var biome_color := _get_biome_color(biome)

	st.set_normal(v["normal"])
	st.set_color(biome_color)

	planet_data.append({
		"pos": v["pos"],
		"height": v["height"],
		"temperature": v["temperature"],
		"biome": biome
	})

	st.add_vertex(v["pos"])


# ============================================================
# === BIOME LOGIC ============================================
# ============================================================

func _get_biome(height: float, temperature: float) -> String:
	if height < radius * (1.0 + 0.02):
		return "ocean"
	elif temperature > 0.7:
		return "desert"
	elif temperature > 0.3:
		return "forest"
	else:
		return "snow"

func _get_biome_color(biome: String) -> Color:
	match biome:
		"ocean":
			return Color(0.094, 0.475, 1.0, 1.0)
		"desert":
			return Color(0.859, 0.753, 0.378, 1.0)
		"forest":
			return Color(0.235, 0.718, 0.2, 1.0)
		"snow":
			return Color(0.876, 0.876, 0.938, 1.0)
		_:
			return Color(1, 0, 1)

## [임시 시안 — 정식 구현 아님] 2.5D 쿼터뷰 마을 구도 확인용.
## 확인할 것: 쿼터뷰에서 4개 구역과 건물 크기 비율이 읽기 좋은가, 색 틴트·층수 크기가 되는가.
## 검증 후 삭제한다. 모델은 game/Cartoon City Massive Pack/ (저장소에 올리지 않음).
## 실행: godot --path game res://scenes/spike/village_spike.tscn -- --shot=<저장할 png 경로>
## 에셋 없이 확인: 같은 명령 끝에 --no-pack 추가.
extends Node3D

const M := "res://Cartoon City Massive Pack/Models/"

var use_pack_models: bool = true
var model_root: String = M

## 유료 에셋 없이도 종류별 크기와 색을 확인할 수 있는 임시 도형 크기.
const FALLBACK_SIZES := {
	"집": Vector3(4, 3.4, 4), "분수": Vector3(4, 1.2, 4),
	"나무": Vector3(2.5, 5, 2.5), "가로등": Vector3(0.6, 5, 0.6),
	"벤치": Vector3(3, 1, 1), "표지판": Vector3(2, 3, 0.5),
	"농구장": Vector3(7, 0.2, 7), "노점": Vector3(3, 2.5, 3),
	"신호탑": Vector3(2, 6, 2), "버스정류장": Vector3(4, 3, 2),
	"쓰레기더미": Vector3(2, 1, 2),
}

## 종류 → 모델, 크기 배율. 모델은 실제 미터 크기라 높이에 맞추지 않고 배율만 곱한다
## (농구장·표지판처럼 납작한 모델을 높이에 맞추면 수백 배로 커진다).
## 집은 층수가 모델을 고른다: 1층 3.4m, 2층 6.2m, 3층 8.7m, 4~5층 10.3m.
const KINDS := {
	"집": {"paths": [M + "Buildings/Building 1/Building_1_1_A.glb", M + "Buildings/Building_2/Building_2_1_A.glb", M + "Buildings/Building 17/Building_17_1_A.glb", M + "Buildings/Building 11/Building_11_1_A.glb", M + "Buildings/Building 11/Building_11_1_A.glb"], "mul": 1.0},
	"분수": {"paths": [M + "Nature and Park/Fountain_1_A.glb"], "mul": 1.2},
	"나무": {"paths": [M + "Nature and Park/Tree_A_1.glb", M + "Nature and Park/Tree_B_1.glb"], "mul": 1.3},
	"가로등": {"paths": [M + "Nature and Park/StreetLamp_3_A.glb"], "mul": 1.0},
	"벤치": {"paths": [M + "Nature and Park/Bench_1_A.glb"], "mul": 2.0},
	"표지판": {"paths": [M + "Construction Site/Other/Sign_C_1.glb"], "mul": 5.0},
	"농구장": {"paths": [M + "Basketball/Basketball_Court_1.glb"], "mul": 0.6},
	"노점": {"paths": [M + "Street Props/Kiosk_1_A.glb"], "mul": 1.3},
	"신호탑": {"paths": [M + "Roof Props/SignalTower_1_A.glb"], "mul": 2.5},
	"버스정류장": {"paths": [M + "Street Props/BusStop_A.glb"], "mul": 1.3},
	"쓰레기더미": {"paths": [M + "Street Props/Trashbag_A_1.glb"], "mul": 3.0},
}

const TINTS := {
	"파랑": Color(0.45, 0.65, 1.0), "빨강": Color(1.0, 0.45, 0.4), "노랑": Color(1.0, 0.9, 0.4),
	"초록": Color(0.5, 0.9, 0.5), "금색": Color(1.0, 0.8, 0.3), "검정": Color(0.35, 0.35, 0.4),
	"흰색": Color(1, 1, 1),
}

const ZONE_SIZE := 27.0
const ZONE_GAP := 3.0

## 구역 → (그리드 칸, 땅 색, 건물 목록). 건물 = [종류, 색, 층수, 슬롯(col,row), 변형]
const ZONES := {
	"광장": {"cell": Vector2(0, 0), "ground": Color(0.80, 0.86, 0.72), "items": [
		["분수", "파랑", 1, Vector2(1, 1), 0], ["나무", "", 1, Vector2(0, 0), 0], ["나무", "", 1, Vector2(2, 0), 1],
		["벤치", "", 1, Vector2(0, 2), 0], ["가로등", "", 1, Vector2(2, 2), 0], ["쓰레기더미", "", 1, Vector2(1, 2), 0]]},
	"주거지": {"cell": Vector2(1, 0), "ground": Color(0.86, 0.82, 0.70), "items": [
		["집", "파랑", 1, Vector2(0, 0), 0], ["집", "빨강", 2, Vector2(1, 0), 1], ["집", "노랑", 3, Vector2(2, 0), 2],
		["집", "초록", 2, Vector2(0, 2), 0], ["나무", "", 1, Vector2(1, 2), 0], ["가로등", "", 1, Vector2(2, 2), 0]]},
	"시장": {"cell": Vector2(0, 1), "ground": Color(0.88, 0.80, 0.78), "items": [
		["노점", "초록", 1, Vector2(0, 0), 0], ["노점", "빨강", 1, Vector2(1, 0), 0], ["노점", "노랑", 1, Vector2(2, 0), 0],
		["벤치", "", 1, Vector2(0, 2), 0], ["가로등", "", 1, Vector2(2, 2), 0]]},
	"축제": {"cell": Vector2(1, 1), "ground": Color(0.74, 0.82, 0.88), "items": [
		["농구장", "", 1, Vector2(1, 0), 0], ["신호탑", "", 1, Vector2(0, 2), 0],
		["표지판", "", 1, Vector2(2, 2), 0], ["버스정류장", "", 1, Vector2(1, 2), 0]]},
}


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--no-pack"):
		use_pack_models = false
	_build_environment()
	for zone_name in ZONES:
		_build_zone(zone_name, ZONES[zone_name])
	_build_camera()
	var shot := _shot_path()
	if not shot.is_empty():
		for i in 12:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(shot)
		print("saved ", shot)
		get_tree().quit()


func _shot_path() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			return arg.substr(7)
	return ""


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.78, 0.92)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.88, 0.95)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	add_child(sun)


func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 64.0
	cam.rotation_degrees = Vector3(-35.264, 45, 0)
	cam.position = cam.basis.z * 150.0
	cam.current = true
	add_child(cam)


func _zone_origin(cell: Vector2) -> Vector3:
	var step := ZONE_SIZE + ZONE_GAP
	return Vector3((cell.x - 0.5) * step, 0, (cell.y - 0.5) * step)


func _build_zone(zone_name: String, zone: Dictionary) -> void:
	var origin := _zone_origin(zone["cell"])
	var ground := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(ZONE_SIZE, 0.3, ZONE_SIZE)
	ground.mesh = box
	var gm := StandardMaterial3D.new()
	gm.albedo_color = (zone["ground"] as Color) * 0.55
	ground.material_override = gm
	ground.position = origin + Vector3(0, -0.15, 0)
	add_child(ground)

	var label := Label3D.new()
	label.text = zone_name
	label.font_size = 96
	label.pixel_size = 0.05
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 16
	label.position = origin + Vector3(0, 1.0, -ZONE_SIZE * 0.5 - 1.5)
	add_child(label)

	var slot := ZONE_SIZE / 3.0
	for item in zone["items"]:
		var kind: String = item[0]
		var floors: int = item[2]
		var holder := _create_building(kind, floors, item[4])
		var col_row: Vector2 = item[3]
		holder.position = origin + Vector3((col_row.x - 1.0) * slot, 0, (col_row.y - 1.0) * slot)
		var tint: String = item[1]
		if TINTS.has(tint):
			_tint(holder, TINTS[tint])
		add_child(holder)


## 모델이 없으면 load() 오류를 내거나 건물을 생략하지 않고 도형으로 대체한다.
func _create_building(kind: String, floors: int, variant: int) -> Node3D:
	var spec: Dictionary = KINDS[kind]
	var paths: Array = spec["paths"]
	var idx: int = (clampi(floors, 1, 5) - 1) if kind == "집" else variant
	var path: String = model_root.path_join(str(paths[posmod(idx, paths.size())]).trim_prefix(M))
	if use_pack_models and ResourceLoader.exists(path, "PackedScene"):
		var scene := load(path) as PackedScene
		if scene != null:
			var model: Node = scene.instantiate()
			if model is Node3D:
				return _fit(model as Node3D, spec["mul"])
			model.free()

	var size: Vector3 = FALLBACK_SIZES[kind]
	if kind == "집":
		size.y += 2.2 * (clampi(floors, 1, 5) - 1)
	var mesh := MeshInstance3D.new()
	if kind in ["나무", "분수"]:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = size.x * 0.5
		cylinder.bottom_radius = size.x * 0.5
		cylinder.height = size.y
		mesh.mesh = cylinder
	else:
		var box := BoxMesh.new()
		box.size = size
		mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.72, 0.75)
	mesh.mesh.surface_set_material(0, material)
	mesh.position.y = size.y * 0.5
	var holder := Node3D.new()
	holder.add_child(mesh)
	return holder


## 모델에 배율을 곱하고 바닥 중앙을 원점에 둔다.
func _fit(model: Node3D, mul: float) -> Node3D:
	var box := _merged_aabb(model, Transform3D.IDENTITY)
	var holder := Node3D.new()
	holder.add_child(model)
	var s := mul
	model.scale = Vector3.ONE * s
	var c := box.get_center()
	model.position = Vector3(-c.x * s, -box.position.y * s, -c.z * s)
	return holder


func _merged_aabb(node: Node, xf: Transform3D) -> AABB:
	var result := AABB()
	var first := true
	var local_xf := xf
	if node is Node3D:
		local_xf = xf * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		result = local_xf * (node as MeshInstance3D).mesh.get_aabb()
		first = false
	for child in node.get_children():
		var sub := _merged_aabb(child, local_xf)
		if sub.size == Vector3.ZERO:
			continue
		result = sub if first else result.merge(sub)
		first = false
	return result


func _tint(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for s in mi.get_surface_override_material_count():
			var m := mi.get_active_material(s)
			if m is StandardMaterial3D:
				var d := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				d.albedo_color = color
				mi.set_surface_override_material(s, d)
	for child in node.get_children():
		_tint(child, color)

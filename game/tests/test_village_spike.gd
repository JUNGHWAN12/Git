extends "res://tests/test_case.gd"

const VillageSpike := preload("res://scenes/spike/village_spike.gd")


func test_every_kind_has_visible_fallback_without_pack() -> void:
	var spike := VillageSpike.new()
	assert_true(spike.has_method("_create_building"), "에셋 없는 건물 생성 경로가 필요함")
	if not spike.has_method("_create_building"):
		spike.free()
		return
	spike.set("use_pack_models", false)
	assert_eq(VillageSpike.KINDS.size(), 11)
	for kind in VillageSpike.KINDS:
		var building: Node3D = spike.call("_create_building", kind, 1, 0)
		var bounds: AABB = spike.call("_merged_aabb", building, Transform3D.IDENTITY)
		assert_true(bounds.size.x > 0 and bounds.size.y > 0 and bounds.size.z > 0, kind)
		assert_true(is_equal_approx(bounds.position.y, 0.0), "바닥 정렬: " + kind)
		building.free()
	spike.free()


func test_missing_model_directory_automatically_uses_fallback() -> void:
	var spike := VillageSpike.new()
	assert_true(spike.has_method("_create_building"), "모델이 없으면 대체 도형이 필요함")
	if not spike.has_method("_create_building"):
		spike.free()
		return
	spike.set("model_root", "res://__missing_village_models__/")
	for kind in VillageSpike.KINDS:
		var building: Node3D = spike.call("_create_building", kind, 1, 0)
		var bounds: AABB = spike.call("_merged_aabb", building, Transform3D.IDENTITY)
		assert_true(bounds.size.length() > 0, "자동 대체: " + kind)
		building.free()
	spike.free()


func test_fallback_house_height_reflects_floors() -> void:
	var spike := VillageSpike.new()
	assert_true(spike.has_method("_create_building"), "층수를 표현할 대체 도형이 필요함")
	if not spike.has_method("_create_building"):
		spike.free()
		return
	spike.set("use_pack_models", false)
	var short_house: Node3D = spike.call("_create_building", "집", 1, 0)
	var tall_house: Node3D = spike.call("_create_building", "집", 3, 0)
	var short_bounds: AABB = spike.call("_merged_aabb", short_house, Transform3D.IDENTITY)
	var tall_bounds: AABB = spike.call("_merged_aabb", tall_house, Transform3D.IDENTITY)
	assert_true(tall_bounds.size.y > short_bounds.size.y, "층수가 높으면 대체 집도 높아야 함")
	short_house.free()
	tall_house.free()
	spike.free()


func test_zone_keeps_buildings_and_tints_without_pack() -> void:
	var spike := VillageSpike.new()
	assert_true(spike.has_method("_create_building"), "모델 누락 때 건물을 건너뛰면 안 됨")
	if not spike.has_method("_create_building"):
		spike.free()
		return
	spike.set("use_pack_models", false)
	var zone: Dictionary = VillageSpike.ZONES["주거지"]
	spike.call("_build_zone", "주거지", zone)
	assert_eq(spike.get_child_count(), 2 + zone["items"].size(), "땅·라벨·모든 건물이 있어야 함")
	var house := spike.get_child(2) as Node3D
	var mesh := house.get_child(0) as MeshInstance3D
	assert_true(mesh != null, "대체 집에 메시가 있어야 함")
	if mesh != null:
		var material := mesh.get_active_material(0) as StandardMaterial3D
		assert_true(material != null, "색상 재질이 있어야 함")
		if material != null:
			assert_eq(material.albedo_color, VillageSpike.TINTS["파랑"])
	spike.free()

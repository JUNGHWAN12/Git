extends "res://tests/test_case.gd"

const BuildingFile := preload("res://core/building_file.gd")

# docs/GIT_SIMULATOR_SPEC.md 2.1 의 예시와 글자 하나까지 같아야 한다.
const FOUNTAIN := "종류: 분수\n\n색: 파랑\n\n층수: 1\n\n장식: 꽃\n"


func test_serialize_matches_spec_format() -> void:
	var text := BuildingFile.serialize({"장식": "꽃", "층수": 1, "종류": "분수", "색": "파랑"})
	assert_eq(text, FOUNTAIN)


func test_parse_round_trip() -> void:
	var result := BuildingFile.parse(FOUNTAIN)
	assert_true(result["ok"], str(result))
	assert_eq(BuildingFile.serialize(result["props"]), FOUNTAIN)


func test_extra_keys_go_last_in_name_order() -> void:
	var text := BuildingFile.serialize({"종류": "집", "창문": "2", "굴뚝": "있음"})
	assert_eq(text, "종류: 집\n\n굴뚝: 있음\n\n창문: 2\n")


func test_conflict_markers_make_broken_building() -> void:
	var conflicted := "종류: 분수\n\n<<<<<<< HEAD\n색: 노랑\n=======\n색: 금색\n>>>>>>> feature/festival\n"
	assert_true(BuildingFile.has_conflict_markers(conflicted))
	assert_eq(BuildingFile.parse(conflicted)["error"], "conflict_markers")


func test_adjacent_lines_are_rejected() -> void:
	# 빈 줄이 없으면 실제 Git에서 다른 속성끼리도 충돌하므로 형식 오류로 본다.
	assert_eq(BuildingFile.parse("종류: 분수\n색: 파랑\n")["error"], "missing_blank_line")


func test_missing_kind_is_rejected() -> void:
	assert_eq(BuildingFile.parse("색: 파랑\n")["error"], "missing_kind")

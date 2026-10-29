extends "res://tests/test_case.gd"

## 프로젝트의 모든 .gd 스크립트가 문법 오류 없이 컴파일되는지 확인한다.
## (화면 스크립트는 단위 테스트가 직접 불러오지 않으므로 여기서 지킨다)

const ROOTS := ["res://core", "res://scenes", "res://tests"]


func test_all_scripts_compile() -> void:
	var paths := PackedStringArray()
	for root in ROOTS:
		_collect(root, paths)
	assert_true(paths.size() >= 5, "스크립트 수: %d" % paths.size())
	for path in paths:
		var script := load(path) as GDScript
		assert_true(script != null and script.can_instantiate(), "컴파일 실패: " + path)


func _collect(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file in dir.get_files():
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))
	for sub in dir.get_directories():
		_collect(dir_path.path_join(sub), out)

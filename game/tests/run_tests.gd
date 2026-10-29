## 헤드리스 테스트 실행기.
##   godot --headless --path game --script res://tests/run_tests.gd
## 마지막 줄에 "RESULT: passed=N failed=M" 을 출력하고, 실패가 있으면 종료 코드 1.
extends SceneTree

const TEST_FILES := [
	"res://tests/test_hangul_keys.gd",
	"res://tests/test_building_file.gd",
	"res://tests/test_scripts_compile.gd",
]


func _init() -> void:
	var passed := 0
	var failed := 0
	for path in TEST_FILES:
		var script: GDScript = load(path)
		if script == null:
			printerr("FAIL %s — 스크립트를 불러오지 못함" % path)
			failed += 1
			continue
		var suite: Object = script.new()
		for method in suite.get_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			suite.call("reset")
			suite.call(name)
			var errors: PackedStringArray = suite.get("errors")
			if errors.is_empty():
				passed += 1
				print("ok   %s::%s" % [path.get_file(), name])
			else:
				failed += 1
				for e in errors:
					printerr("FAIL %s::%s — %s" % [path.get_file(), name, e])
	print("RESULT: passed=%d failed=%d" % [passed, failed])
	quit(1 if failed > 0 else 0)

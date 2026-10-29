## 아주 작은 테스트 기반 클래스 (애드온 없이 Godot만으로 실행).
## 테스트 파일은 `extends "res://tests/test_case.gd"` 로 시작하고 `test_` 로 시작하는 함수를 만든다.
extends RefCounted

var errors: PackedStringArray = []


func reset() -> void:
	errors.clear()


func assert_eq(actual: Variant, expected: Variant, note: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		errors.append("기대값 %s, 실제값 %s %s" % [var_to_str(expected), var_to_str(actual), note])


func assert_true(value: bool, note: String = "") -> void:
	if not value:
		errors.append("참이어야 함 %s" % note)

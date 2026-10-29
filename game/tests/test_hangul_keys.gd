extends "res://tests/test_case.gd"

const Keys := preload("res://core/hangul_keys.gd")


func test_git_typed_in_korean() -> void:
	assert_eq(Keys.to_qwerty("햣"), "git")


func test_full_commands() -> void:
	assert_eq(Keys.to_qwerty("햣 채ㅡㅡㅑㅅ"), "git commit")
	assert_eq(Keys.to_qwerty("햣 ㄴㅅㅁ션"), "git status")
	assert_eq(Keys.to_qwerty("ㅊㅇ .."), "cd ..")
	assert_eq(Keys.to_qwerty("ㅣㄴ"), "ls")
	assert_eq(Keys.to_qwerty("ㅊㅁㅅ"), "cat")
	assert_eq(Keys.to_qwerty("칟ㅁㄱ"), "clear")


func test_non_hangul_is_unchanged() -> void:
	assert_eq(Keys.to_qwerty("git add ."), "git add .")


func test_mistyped_command_detected() -> void:
	assert_eq(Keys.mistyped_command("햣 ㄴㅅㅁ션"), "git status")
	assert_eq(Keys.mistyped_command("  ㅣㄴ  "), "ls")


func test_real_korean_words_are_not_commands() -> void:
	assert_eq(Keys.mistyped_command("커밋"), "")
	assert_eq(Keys.mistyped_command("분수"), "")
	assert_eq(Keys.mistyped_command("git commit -m \"분수 짓기\""), "")
	assert_eq(Keys.mistyped_command(""), "")

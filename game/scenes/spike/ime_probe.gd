## IME 진단 도구: 한글 IME 이벤트(조합 문자열·키 입력·텍스트 변경)를 user://ime_probe.log 에 기록한다.
## 엔진 버전을 바꾸거나 학교 PC에서 한글 입력이 이상할 때 '광장'을 입력해 확인한다.
## (Godot 4.7.2는 조합이 넘어갈 때 확정 글자의 문자 입력이 오지 않는다 — docs/P0_VALIDATION.md)
##   godot --path game --script res://scenes/spike/ime_probe.gd
extends SceneTree

var _log: FileAccess
var _last_ime := ""
var _fields: Dictionary = {}


func _initialize() -> void:
	_log = FileAccess.open("user://ime_probe.log", FileAccess.WRITE)
	_write("engine=%s autoload_helper=%s args=%s" % [
		Engine.get_version_info().get("string", ""), str(root.has_node("_mcp_game_helper")), str(OS.get_cmdline_args())])
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(box)

	var guide := Label.new()
	guide.text = "IME 진단: 아래 세 칸에 차례로 '광장' 두 글자를 입력해 주세요 (Enter는 누르지 않아도 됩니다)."
	box.add_child(guide)

	var plain := LineEdit.new()
	plain.placeholder_text = "A: 기본 글꼴 LineEdit"
	box.add_child(plain)
	_watch_line("A", plain)

	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["D2Coding", "Consolas", "Malgun Gothic", "monospace"])
	var styled := LineEdit.new()
	styled.placeholder_text = "B: 스파이크와 같은 글꼴 LineEdit"
	styled.add_theme_font_override("font", mono)
	box.add_child(styled)
	_watch_line("B", styled)

	var multi := TextEdit.new()
	multi.placeholder_text = "C: TextEdit (여러 줄)"
	multi.custom_minimum_size = Vector2(0, 120)
	box.add_child(multi)
	multi.text_changed.connect(func() -> void: _write("C text_changed %s" % var_to_str(multi.text)))
	multi.focus_entered.connect(func() -> void: _write("C focus"))
	_fields["C"] = multi

	var spy := Node.new()
	spy.set_script(_spy_script())
	spy.set("probe", self)
	root.add_child(spy)


func _watch_line(tag: String, edit: LineEdit) -> void:
	edit.text_changed.connect(func(t: String) -> void: _write("%s text_changed %s" % [tag, var_to_str(t)]))
	edit.focus_entered.connect(func() -> void: _write("%s focus" % tag))
	_fields[tag] = edit


func _process(_delta: float) -> bool:
	var ime := DisplayServer.ime_get_text()
	if ime != _last_ime:
		_last_ime = ime
		var texts := PackedStringArray()
		for tag: String in _fields:
			texts.append("%s=%s" % [tag, var_to_str(_fields[tag].get("text"))])
		_write("ime_text %s sel=%s | %s" % [var_to_str(ime), str(DisplayServer.ime_get_selection()), " ".join(texts)])
	return false


func on_key(event: InputEventKey) -> void:
	_write("key pressed=%s echo=%s keycode=%d(%s) unicode=%d(%s)" % [
		str(event.pressed), str(event.echo), event.keycode, OS.get_keycode_string(event.keycode),
		event.unicode, String.chr(event.unicode) if event.unicode > 0 else ""])


func _write(line: String) -> void:
	_log.store_line("%d %s" % [Time.get_ticks_msec(), line])
	_log.flush()


func _spy_script() -> GDScript:
	var s := GDScript.new()
	s.source_code = "extends Node\nvar probe: Object\nfunc _input(e: InputEvent) -> void:\n\tif e is InputEventKey:\n\t\tprobe.call(\"on_key\", e)\nfunc _notification(what: int) -> void:\n\tif what == MainLoop.NOTIFICATION_OS_IME_UPDATE:\n\t\tprobe.call(\"_write\", \"NOTIFICATION_OS_IME_UPDATE\")\n"
	s.reload()
	return s

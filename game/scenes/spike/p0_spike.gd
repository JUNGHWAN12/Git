## P0 기술 스파이크 (docs/IMPLEMENTATION_PLAN.md P0)
## 학교 Windows PC에서 Godot으로 다음이 되는지 확인하는 버려도 되는 화면.
##   ① 한글 입력 (커밋 메시지·충돌 편집기)  ② 터미널 입력·한/영 감지  ③ 커밋 그래프 그리기 성능
##   ④ 교실 네트워크 (선생님 PC 서버 ↔ 학생 PC 접속)
## 화면은 코드로 만든다 (.tscn 수작업 편집 최소화).
extends Control

const HangulKeys := preload("res://core/hangul_keys.gd")
const CommitGraphSpike := preload("res://scenes/spike/commit_graph_spike.gd")
const NetSpike := preload("res://scenes/spike/net_spike.gd")

var _ui_font: Font
var _mono_font: Font

# ① 한글 입력
var _message: LineEdit
var _ime_log: RichTextLabel

# ② 터미널
var _term_output: RichTextLabel
var _term_input: LineEdit
var _history: PackedStringArray = []
var _history_index := 0

# ③ 그래프
var _graph: Control
var _fps_label: Label


func _ready() -> void:
	_setup_fonts()
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var title := Label.new()
	title.text = "커밋 크래프트 · P0 기술 스파이크 (Godot %s)" % Engine.get_version_info().get("string", "")
	title.add_theme_font_size_override("font_size", 22)
	root.add_child(title)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	tabs.add_child(_build_ime_tab())
	tabs.add_child(_build_terminal_tab())
	tabs.add_child(_build_graph_tab())
	var net := NetSpike.new()
	net.name = "④ 교실 네트워크"
	net.mono_font = _mono_font
	tabs.add_child(net)

	_fps_label = Label.new()
	root.add_child(_fps_label)


func _process(_delta: float) -> void:
	_fps_label.text = "FPS: %d   |   창 크기: %s" % [int(Engine.get_frames_per_second()), str(get_viewport_rect().size)]


# ------------------------------------------------------------------ 글꼴
func _setup_fonts() -> void:
	# Windows 기본 글꼴 사용 (내려받을 필요 없음). 웹 내보내기에서는 글꼴 파일을 넣어야 한다.
	var ui := SystemFont.new()
	ui.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Noto Sans KR", "sans-serif"])
	_ui_font = ui
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["D2Coding", "Consolas", "Malgun Gothic", "monospace"])
	_mono_font = mono

	var t := Theme.new()
	t.default_font = _ui_font
	t.default_font_size = 18
	theme = t


# ------------------------------------------------------------------ ① 한글 입력
func _build_ime_tab() -> Control:
	var box := VBoxContainer.new()
	box.name = "① 한글 입력"

	var guide := Label.new()
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.text = "확인할 것: 아래 칸에 '광장에 분수 짓기'를 입력하고 Enter.\n" \
		+ "· 끝 글자 '기'가 두 번 들어가지 않는가?  · 조합 중인 글자가 칸 안에 바로 보이는가?\n" \
		+ "· 여러 줄 칸에서 한글을 쓰다가 방향키·Backspace로 고칠 수 있는가?"
	box.add_child(guide)

	_message = LineEdit.new()
	_message.placeholder_text = "커밋 메시지 (한 줄) — Enter로 제출"
	_message.add_theme_font_override("font", _mono_font)
	_message.text_changed.connect(_on_message_changed)
	_message.text_submitted.connect(_on_message_submitted)
	box.add_child(_message)

	var editor := TextEdit.new()
	editor.placeholder_text = "충돌 편집기 시험 (여러 줄)"
	editor.custom_minimum_size = Vector2(0, 160)
	editor.add_theme_font_override("font", _mono_font)
	editor.text = "종류: 분수\n\n<<<<<<< HEAD\n색: 노랑\n=======\n색: 금색\n>>>>>>> feature/festival\n"
	box.add_child(editor)

	_ime_log = RichTextLabel.new()
	_ime_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ime_log.scroll_following = true
	_ime_log.add_theme_font_override("normal_font", _mono_font)
	box.add_child(_ime_log)
	return box


func _on_message_changed(text: String) -> void:
	_log_ime("변경", text)


func _on_message_submitted(text: String) -> void:
	_log_ime("제출(Enter)", text)
	_message.clear()


func _log_ime(kind: String, text: String) -> void:
	# 글자 수를 함께 찍어 중복 입력을 눈으로 확인한다.
	_ime_log.add_text("[%s] \"%s\" (%d글자)\n" % [kind, text, text.length()])


# ------------------------------------------------------------------ ② 터미널
func _build_terminal_tab() -> Control:
	var box := VBoxContainer.new()
	box.name = "② 터미널"

	_term_output = RichTextLabel.new()
	_term_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_term_output.scroll_following = true
	_term_output.selection_enabled = true
	_term_output.add_theme_font_override("normal_font", _mono_font)
	box.add_child(_term_output)

	_term_input = LineEdit.new()
	_term_input.placeholder_text = "$ 명령 입력 (help, clear, 한글 상태로 git 입력해 보기)"
	_term_input.add_theme_font_override("font", _mono_font)
	_term_input.text_submitted.connect(_on_terminal_submit)
	_term_input.gui_input.connect(_on_terminal_key)
	box.add_child(_term_input)

	_print_line("커밋 크래프트 터미널 시험판. 'help'를 입력해 보세요.")
	_print_line("시험: 한/영 키를 한글로 둔 채 git status 를 쳐 보세요 (화면엔 '햣 ㄴㅅㅁ션').")
	return box


func _on_terminal_submit(raw: String) -> void:
	_term_input.clear()
	var input := raw.strip_edges()
	_print_line("$ " + input)
	if input.is_empty():
		return
	_history.append(input)
	_history_index = _history.size()

	var fixed := HangulKeys.mistyped_command(input)
	if not fixed.is_empty():
		_print_line("🦉 한글 자판으로 입력된 것 같아! 한/영 키를 눌러 영어로 바꿔줘.")
		_print_line("   혹시 이거였어?  $ " + fixed)
		return

	match input:
		"help":
			_print_line("지원(시험판): help, clear, echo <글>. git 명령은 시뮬레이터가 붙으면 동작합니다.")
		"clear":
			_term_output.clear()
		_:
			if input.begins_with("echo "):
				_print_line(input.substr(5))
			elif input.begins_with("git"):
				_print_line("(P0 스파이크: Git 시뮬레이터는 P1에서 연결됩니다)")
			else:
				_print_line("bash: %s: command not found" % input.split(" ", false)[0])


func _on_terminal_key(event: InputEvent) -> void:
	# ↑↓ 키로 이전 명령 불러오기
	var key := event as InputEventKey
	if key == null or not key.pressed or _history.is_empty():
		return
	if key.keycode == KEY_UP:
		_history_index = maxi(_history_index - 1, 0)
	elif key.keycode == KEY_DOWN:
		_history_index = mini(_history_index + 1, _history.size())
	else:
		return
	_term_input.text = "" if _history_index >= _history.size() else _history[_history_index]
	_term_input.caret_column = _term_input.text.length()
	_term_input.accept_event()


func _print_line(text: String) -> void:
	_term_output.add_text(text + "\n")


# ------------------------------------------------------------------ ③ 커밋 그래프
func _build_graph_tab() -> Control:
	var box := VBoxContainer.new()
	box.name = "③ 커밋 그래프"

	var bar := HBoxContainer.new()
	box.add_child(bar)
	var count_label := Label.new()
	count_label.text = "커밋 수"
	bar.add_child(count_label)
	var count := SpinBox.new()
	count.min_value = 10
	count.max_value = 2000
	count.step = 10
	count.value = 100
	bar.add_child(count)
	var stress := CheckBox.new()
	stress.text = "매 프레임 다시 그리기 (부하 시험)"
	bar.add_child(stress)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)

	_graph = CommitGraphSpike.new()
	scroll.add_child(_graph)
	_graph.call("generate", int(count.value))
	count.value_changed.connect(func(v: float) -> void: _graph.call("generate", int(v)))
	stress.toggled.connect(func(on: bool) -> void: _graph.set("redraw_every_frame", on))
	return box

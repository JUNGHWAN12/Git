## ④ 교실 네트워크 시험 (P0)
## 선생님 PC: "서버 열기" → 화면에 나온 주소를 칠판에 적기
## 학생 PC: 주소·닉네임 입력 → "접속" → "알림 보내기"로 서로 보이는지 확인
extends VBoxContainer

const Protocol := preload("res://core/net/protocol.gd")
const RoomServer := preload("res://core/net/room_server.gd")
const RoomClient := preload("res://core/net/room_client.gd")

var mono_font: Font

var _server: RoomServer = null
var _client: RoomClient = null
var _address: LineEdit
var _nickname: LineEdit
var _message: LineEdit
var _status: Label
var _log: RichTextLabel
var _was_open := false


func _ready() -> void:
	var guide := Label.new()
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.text = "선생님 PC에서 [서버 열기] → 아래 주소를 학생에게 알려 주세요. 학생은 주소와 닉네임을 넣고 [접속].\n" \
		+ "Windows 방화벽 창이 뜨면 허용해야 합니다(관리자 권한이 필요할 수 있음). 접속이 안 되면 결과를 기록해 주세요."
	add_child(guide)

	var server_row := HBoxContainer.new()
	add_child(server_row)
	var open_button := Button.new()
	open_button.text = "서버 열기 (선생님 PC)"
	open_button.pressed.connect(_on_open_server)
	server_row.add_child(open_button)
	var ips := Label.new()
	ips.text = "이 PC 주소: " + ", ".join(_local_ipv4()) + "  (포트 %d)" % Protocol.DEFAULT_PORT
	server_row.add_child(ips)

	var join_row := HBoxContainer.new()
	add_child(join_row)
	_address = LineEdit.new()
	_address.placeholder_text = "서버 주소 (예: 192.168.0.10)"
	_address.custom_minimum_size = Vector2(280, 0)
	join_row.add_child(_address)
	_nickname = LineEdit.new()
	_nickname.placeholder_text = "닉네임"
	_nickname.custom_minimum_size = Vector2(160, 0)
	join_row.add_child(_nickname)
	var join_button := Button.new()
	join_button.text = "접속"
	join_button.pressed.connect(_on_join)
	join_row.add_child(join_button)

	var say_row := HBoxContainer.new()
	add_child(say_row)
	_message = LineEdit.new()
	_message.placeholder_text = "보낼 알림 (예: 분수 완성!)"
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message.text_submitted.connect(func(_t: String) -> void: _on_say())
	say_row.add_child(_message)
	var say_button := Button.new()
	say_button.text = "알림 보내기"
	say_button.pressed.connect(_on_say)
	say_row.add_child(say_button)

	_status = Label.new()
	_status.text = "상태: 연결 안 됨"
	add_child(_status)

	_log = RichTextLabel.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.scroll_following = true
	if mono_font != null:
		_log.add_theme_font_override("normal_font", mono_font)
	add_child(_log)


func _process(_delta: float) -> void:
	if _server != null:
		_server.poll()
		for line in _server.drain_log():
			_write("[서버] " + line)
	if _client == null:
		return
	_client.poll()
	if _client.is_open() and not _was_open:
		_was_open = true
		_write("[나] 서버에 연결됨")
	if _client.is_closed() and _was_open:
		_was_open = false
		_write("[나] 연결이 끊김 — 내 작업은 그대로예요 (실제 Git처럼 push/fetch만 못 함)")
	for msg in _client.drain_inbox():
		match str(msg["t"]):
			"welcome":
				_write("[서버] 환영합니다, %s" % msg.get("name", ""))
			"joined":
				_write("[서버] %s 님이 들어왔어요" % msg.get("name", ""))
			"left":
				_write("[서버] %s 님이 나갔어요" % msg.get("name", ""))
			"said":
				_write("📢 %s: %s" % [msg.get("from", ""), msg.get("text", "")])
			"error":
				_write("[오류] %s" % msg.get("text", ""))
	_status.text = "상태: %s · 접속자 %d명: %s" % [
		"연결됨" if _client.is_open() else "연결 중/끊김",
		_client.players.size(),
		", ".join(_client.players),
	]


func _on_open_server() -> void:
	if _server != null and _server.is_listening():
		_write("[서버] 이미 열려 있어요")
		return
	_server = RoomServer.new()
	var err := _server.start(Protocol.DEFAULT_PORT)
	if err != OK:
		_write("[서버] 열기 실패 (오류 %d) — 포트가 사용 중이거나 막혀 있어요" % err)
		_server = null


func _on_join() -> void:
	if _client != null:
		_client.close()
	_client = RoomClient.new()
	_was_open = false
	var url := _to_url(_address.text)
	var err := _client.connect_to(url, _nickname.text)
	_write("[나] %s 에 접속 시도%s" % [url, "" if err == OK else " — 실패 (오류 %d)" % err])


func _on_say() -> void:
	if _client == null or not _client.is_open():
		_write("[나] 먼저 접속하세요")
		return
	if _message.text.strip_edges().is_empty():
		return
	_client.say(_message.text)
	_message.clear()


## "192.168.0.10" → "ws://192.168.0.10:8910". ws://, wss:// 로 시작하면 그대로.
static func _to_url(address: String) -> String:
	var a := address.strip_edges()
	if a.is_empty():
		a = "127.0.0.1"
	if a.begins_with("ws://") or a.begins_with("wss://"):
		return a
	if not a.contains(":"):
		a += ":%d" % Protocol.DEFAULT_PORT
	return "ws://" + a


static func _local_ipv4() -> PackedStringArray:
	var out := PackedStringArray()
	for ip in IP.get_local_addresses():
		if ip.contains(".") and not ip.begins_with("127.") and not ip.begins_with("169.254."):
			out.append(ip)
	if out.is_empty():
		out.append("(찾지 못함)")
	return out


func _write(text: String) -> void:
	_log.add_text(text + "\n")

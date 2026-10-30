## 교실 서버 접속 (학생 쪽). 화면 쪽에서 매 프레임 poll()을 불러 준다.
## 서버가 끊겨도 내 로컬 저장소는 그대로다 — 실제 Git처럼 커밋은 계속되고 push/fetch만 못 한다.
extends RefCounted

const Protocol := preload("res://core/net/protocol.gd")

var nickname := ""
var my_id := -1
var welcomed := false
var players := PackedStringArray()

var _ws := WebSocketPeer.new()
var _hello_sent := false
var _inbox: Array[Dictionary] = []


## url 예: "ws://192.168.0.10:8910" (교실 서버), "wss://hub.example.kr" (인터넷 서버)
func connect_to(url: String, name: String) -> Error:
	nickname = Protocol.clean_nickname(name)
	_ws.inbound_buffer_size = Protocol.MAX_MESSAGE_BYTES
	return _ws.connect_to_url(url)


func poll() -> void:
	_ws.poll()
	if _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	if not _hello_sent:
		send({"t": "hello", "v": Protocol.VERSION, "name": nickname})
		_hello_sent = true
	while _ws.get_available_packet_count() > 0:
		var msg := Protocol.decode(_ws.get_packet().get_string_from_utf8())
		if msg.is_empty():
			continue
		if msg["t"] == "welcome":
			welcomed = true
			my_id = int(msg.get("id", -1))
			nickname = str(msg.get("name", nickname))
		if msg.has("players"):
			players = PackedStringArray(msg["players"])
		_inbox.append(msg)


func send(message: Dictionary) -> void:
	if is_open():
		_ws.send_text(Protocol.encode(message))


func say(text: String) -> void:
	send({"t": "say", "text": text})


## 받은 메시지를 꺼낸다 (꺼내면 비워짐).
func drain_inbox() -> Array[Dictionary]:
	var out := _inbox
	_inbox = []
	return out


func is_open() -> bool:
	return _ws.get_ready_state() == WebSocketPeer.STATE_OPEN


func is_closed() -> bool:
	return _ws.get_ready_state() == WebSocketPeer.STATE_CLOSED


func close() -> void:
	_ws.close()

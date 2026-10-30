## 교실 서버 (= 허브 섬). 교사 PC 또는 인터넷 서버에서 실행한다.
## 지금은 접속·명단·알림 전달만 한다. 허브 저장소(fetch/push)는 P1 Git 코어가 생기면 붙인다.
## Node가 아니므로 화면 쪽에서 매 프레임 poll()을 불러 준다.
extends RefCounted

const Protocol := preload("res://core/net/protocol.gd")

var _tcp := TCPServer.new()
var _peers: Dictionary = {}     # id(int) -> WebSocketPeer
var _names: Dictionary = {}     # id(int) -> 닉네임 (hello를 보낸 접속만)
var _next_id := 1
var _log := PackedStringArray()


func start(port: int = Protocol.DEFAULT_PORT) -> Error:
	var err := _tcp.listen(port)
	if err == OK:
		_note("서버 시작: 포트 %d" % port)
	return err


func stop() -> void:
	for ws in _peers.values():
		(ws as WebSocketPeer).close()
	_peers.clear()
	_names.clear()
	_tcp.stop()


func is_listening() -> bool:
	return _tcp.is_listening()


func player_names() -> PackedStringArray:
	var names := PackedStringArray()
	for id in _sorted_ids():
		if _names.has(id):
			names.append(str(_names[id]))
	return names


## 화면에 보여줄 서버 기록을 꺼낸다 (꺼내면 비워짐).
func drain_log() -> PackedStringArray:
	var out := _log
	_log = PackedStringArray()
	return out


func poll() -> void:
	while _tcp.is_connection_available():
		var ws := WebSocketPeer.new()
		ws.inbound_buffer_size = Protocol.MAX_MESSAGE_BYTES
		if ws.accept_stream(_tcp.take_connection()) == OK:
			_peers[_next_id] = ws
			_next_id += 1
	for id in _sorted_ids():
		var ws: WebSocketPeer = _peers[id]
		ws.poll()
		var state := ws.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			while ws.get_available_packet_count() > 0:
				_handle(id, ws.get_packet().get_string_from_utf8())
		elif state == WebSocketPeer.STATE_CLOSED:
			_peers.erase(id)
			if _names.has(id):
				var name: String = _names[id]
				_names.erase(id)
				_note("%s 나감" % name)
				_broadcast({"t": "left", "name": name, "players": player_names()})


func _handle(id: int, text: String) -> void:
	var msg := Protocol.decode(text)
	if msg.is_empty():
		return
	match str(msg["t"]):
		"hello":
			if int(msg.get("v", 0)) != Protocol.VERSION:
				_send(id, {"t": "error", "code": "version", "text": "게임 버전이 서버와 달라요. 선생님께 최신 파일을 받으세요."})
				(_peers[id] as WebSocketPeer).close()
				return
			var name := Protocol.clean_nickname(str(msg.get("name", "")))
			_names[id] = name
			_note("%s 들어옴" % name)
			_send(id, {"t": "welcome", "id": id, "name": name, "players": player_names()})
			_broadcast({"t": "joined", "name": name, "players": player_names()}, id)
		"say":
			if not _names.has(id):
				return
			# 시험판: 짧은 알림 문장만 전달 (자유 채팅은 정식판에서 교사가 켤 때만)
			var line := str(msg.get("text", "")).left(80)
			_broadcast({"t": "said", "from": _names[id], "text": line})


func _send(id: int, message: Dictionary) -> void:
	var ws: WebSocketPeer = _peers.get(id)
	if ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(Protocol.encode(message))


func _broadcast(message: Dictionary, except_id: int = -1) -> void:
	for id in _sorted_ids():
		if id != except_id and _names.has(id):
			_send(id, message)


func _sorted_ids() -> Array:
	var ids := _peers.keys()
	ids.sort()
	return ids


func _note(text: String) -> void:
	_log.append(text)

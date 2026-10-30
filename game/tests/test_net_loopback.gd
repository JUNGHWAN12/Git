extends "res://tests/test_case.gd"

## 한 컴퓨터 안에서 서버 1개 + 학생 2명을 띄워 실제 WebSocket으로 주고받는지 확인한다.

const Protocol := preload("res://core/net/protocol.gd")
const RoomServer := preload("res://core/net/room_server.gd")
const RoomClient := preload("res://core/net/room_client.gd")


func test_protocol_rejects_bad_messages() -> void:
	assert_eq(Protocol.decode("이건 JSON 아님"), {})
	assert_eq(Protocol.decode("[1, 2]"), {})
	assert_eq(Protocol.decode("{\"x\": 1}"), {})
	assert_eq(Protocol.decode("{\"t\": \"say\"}")["t"], "say")


func test_nickname_is_cleaned() -> void:
	assert_eq(Protocol.clean_nickname("   "), "건축가")
	assert_eq(Protocol.clean_nickname("  하늘  "), "하늘")
	assert_eq(Protocol.clean_nickname("가나다라마바사아자차카타파하").length(), Protocol.MAX_NICKNAME_LENGTH)


func test_two_students_meet_on_server() -> void:
	var server := RoomServer.new()
	var port := 0
	for candidate in [28910, 28911, 28912, 28913, 28914]:
		if server.start(candidate) == OK:
			port = candidate
			break
	assert_true(port != 0, "서버 포트를 열지 못함")
	if port == 0:
		return

	var url := "ws://127.0.0.1:%d" % port
	var sky := RoomClient.new()
	var rain := RoomClient.new()
	assert_eq(sky.connect_to(url, "하늘"), OK)
	assert_eq(rain.connect_to(url, "단비"), OK)

	var said := false
	var heard := false
	for _i in 500:
		server.poll()
		sky.poll()
		rain.poll()
		if not said and sky.welcomed and rain.welcomed and sky.players.size() == 2:
			sky.say("분수 완성!")
			said = true
		for msg in rain.drain_inbox():
			if msg["t"] == "said" and msg["from"] == "하늘" and msg["text"] == "분수 완성!":
				heard = true
		if heard:
			break
		OS.delay_msec(10)

	assert_true(sky.welcomed and rain.welcomed, "환영 메시지를 못 받음")
	var names := server.player_names()
	assert_true(names.size() == 2 and names.has("하늘") and names.has("단비"), "명단: " + str(names))
	assert_true(heard, "단비가 하늘의 알림을 못 받음")
	sky.close()
	rain.close()
	server.stop()

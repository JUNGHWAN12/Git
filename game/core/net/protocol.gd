## 교실 협업 통신 규약 (docs/MULTIPLAYER_DESIGN.md 5장).
## 메시지는 JSON 텍스트 1개 = WebSocket 패킷 1개. 모든 메시지에 "t"(종류)가 있다.
extends RefCounted

## 서버와 게임 버전이 다르면 접속을 거절한다.
const VERSION := 1
const DEFAULT_PORT := 8910
## 메시지 1개 최대 크기 (저장소가 작으므로 넉넉함)
const MAX_MESSAGE_BYTES := 256 * 1024
const MAX_NICKNAME_LENGTH := 12


static func encode(message: Dictionary) -> String:
	return JSON.stringify(message)


## 형식이 맞지 않으면 빈 사전을 돌려준다.
static func decode(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_MESSAGE_BYTES:
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var message: Dictionary = parsed
	if not message.has("t") or typeof(message["t"]) != TYPE_STRING:
		return {}
	return message


## 닉네임 정리: 앞뒤 공백 제거, 길이 제한. 비면 "건축가".
static func clean_nickname(name: String) -> String:
	var cleaned := name.strip_edges().left(MAX_NICKNAME_LENGTH)
	return "건축가" if cleaned.is_empty() else cleaned

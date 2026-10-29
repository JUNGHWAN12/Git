## 건물 파일 형식 (docs/GIT_SIMULATOR_SPEC.md 2.1).
##
##   종류: 분수
##
##   색: 파랑
##
## "키: 값" 줄 사이에 빈 줄을 1개씩 둔다. 이렇게 해야 다른 속성을 동시에 고치면
## 실제 Git처럼 자동 병합되고, 같은 속성을 고치면 충돌한다.
extends RefCounted

## 파일에 쓰는 속성 순서. 목록에 없는 키는 뒤에 이름순으로 붙인다.
const KEY_ORDER := ["종류", "색", "층수", "장식"]


## 속성 사전을 파일 내용으로 만든다. 같은 속성이면 항상 같은 글자가 나와야 한다 (해시 재현성).
static func serialize(props: Dictionary) -> String:
	var lines := PackedStringArray()
	for key in KEY_ORDER:
		if props.has(key):
			lines.append("%s: %s" % [key, str(props[key])])
	var extra_keys: Array = []
	for key in props.keys():
		if not (key in KEY_ORDER):
			extra_keys.append(key)
	extra_keys.sort()
	for key in extra_keys:
		lines.append("%s: %s" % [key, str(props[key])])
	return "\n\n".join(lines) + "\n"


## 파일 내용을 읽는다.
## 성공: {"ok": true, "props": {...}, "error": ""}
## 실패: {"ok": false, "props": {}, "error": "conflict_markers" | "missing_blank_line" | "bad_line" | "missing_kind"}
## 실패한 건물은 마을에 "깨진 건물(지지직)"로 그린다.
static func parse(content: String) -> Dictionary:
	if has_conflict_markers(content):
		return _fail("conflict_markers")
	var body := content.trim_suffix("\n")
	var lines := body.split("\n")
	var props := {}
	for i in lines.size():
		var line: String = lines[i]
		if i % 2 == 1:
			if not line.is_empty():
				return _fail("missing_blank_line")
			continue
		var sep := line.find(": ")
		if sep <= 0:
			return _fail("bad_line")
		props[line.substr(0, sep)] = line.substr(sep + 2)
	if not props.has("종류"):
		return _fail("missing_kind")
	return {"ok": true, "props": props, "error": ""}


## 실제 Git의 충돌 표시자 줄이 남아 있는지 확인한다.
static func has_conflict_markers(content: String) -> bool:
	for line in content.split("\n"):
		if line.begins_with("<<<<<<< ") or line == "=======" or line.begins_with(">>>>>>> "):
			return true
	return false


static func _fail(error: String) -> Dictionary:
	return {"ok": false, "props": {}, "error": error}

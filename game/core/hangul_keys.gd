## 한/영 전환 감지.
## 한글 자판 상태로 영어 명령을 친 입력(예: "햣" = git)을 찾아 영어로 바꿔 준다.
## 두벌식 표준 자판 기준. 엔진 기능을 쓰지 않는 순수 로직 (core 규칙).
extends RefCounted

const SYLLABLE_FIRST := 0xAC00  # 가
const SYLLABLE_LAST := 0xD7A3   # 힣
const COMPAT_CONSONANT_FIRST := 0x3131  # ㄱ
const COMPAT_VOWEL_FIRST := 0x314F      # ㅏ
const COMPAT_VOWEL_LAST := 0x3163       # ㅣ

# 초성 19개
const CHO := ["r", "R", "s", "e", "E", "f", "a", "q", "Q", "t", "T", "d", "w", "W", "c", "z", "x", "v", "g"]
# 중성 21개 (호환 자모 모음 순서와 같음)
const JUNG := ["k", "o", "i", "O", "j", "p", "u", "P", "h", "hk", "ho", "hl", "y", "n", "nj", "np", "nl", "b", "m", "ml", "l"]
# 종성 28개 (0번 = 받침 없음)
const JONG := ["", "r", "R", "rt", "s", "sw", "sg", "e", "f", "fr", "fa", "fq", "ft", "fx", "fv", "fg", "a", "q", "qt", "t", "T", "d", "w", "c", "z", "x", "v", "g"]
# 호환 자모 자음 30개 (ㄱ~ㅎ, 겹자음 포함)
const COMPAT_CONSONANTS := ["r", "R", "rt", "s", "sw", "sg", "e", "E", "f", "fr", "fa", "fq", "ft", "fx", "fv", "fg", "a", "q", "Q", "qt", "t", "T", "d", "w", "W", "c", "z", "x", "v", "g"]

## 게임 터미널에서 첫 단어로 쓰는 명령
const KNOWN_COMMANDS := ["git", "cd", "ls", "cat", "clear"]


## 한글을 같은 자리의 영어 자판 글자로 바꾼다. 한글이 아닌 글자는 그대로 둔다.
@warning_ignore("integer_division")
static func to_qwerty(text: String) -> String:
	var out := ""
	for i in text.length():
		var code := text.unicode_at(i)
		if code >= SYLLABLE_FIRST and code <= SYLLABLE_LAST:
			var index := code - SYLLABLE_FIRST
			out += str(CHO[index / 588]) + str(JUNG[(index % 588) / 28]) + str(JONG[index % 28])
		elif code >= COMPAT_CONSONANT_FIRST and code < COMPAT_VOWEL_FIRST:
			out += str(COMPAT_CONSONANTS[code - COMPAT_CONSONANT_FIRST])
		elif code >= COMPAT_VOWEL_FIRST and code <= COMPAT_VOWEL_LAST:
			out += str(JUNG[code - COMPAT_VOWEL_FIRST])
		else:
			out += text[i]
	return out


static func has_hangul(text: String) -> bool:
	for i in text.length():
		var code := text.unicode_at(i)
		if code >= SYLLABLE_FIRST and code <= SYLLABLE_LAST:
			return true
		if code >= COMPAT_CONSONANT_FIRST and code <= COMPAT_VOWEL_LAST:
			return true
	return false


## 첫 단어가 한글이고, 영어 자판으로 바꾸면 아는 명령이 되면 바꾼 입력 전체를 돌려준다.
## 해당하지 않으면 빈 문자열. 예: "햣 ㄴㅅㅁ션" → "git status", "분수" → ""
static func mistyped_command(input: String) -> String:
	var trimmed := input.strip_edges()
	if trimmed.is_empty():
		return ""
	var words := trimmed.split(" ", false)
	var first: String = words[0]
	if not has_hangul(first):
		return ""
	if to_qwerty(first) in KNOWN_COMMANDS:
		return to_qwerty(trimmed)
	return ""

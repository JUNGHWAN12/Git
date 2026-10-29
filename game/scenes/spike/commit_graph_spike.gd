## 커밋 그래프(시간의 나무) 그리기 성능 시험.
## main(0번 줄)에서 가지가 갈라졌다가 병합 커밋으로 돌아오는 모양을 반복해서 만든다.
extends Control

const ROW := 26.0
const LANE := 40.0
const MARGIN := Vector2(40, 24)
const RADIUS := 8.0
const LANE_COLORS := [Color("#c9a227"), Color("#ff8a7a"), Color("#7fd1ff")]  # main=금색

var redraw_every_frame := false

# 각 원소: {"lane": int, "parents": Array}
var _nodes: Array[Dictionary] = []


func generate(count: int) -> void:
	_nodes.clear()
	var last_main := -1
	var next_lane := 1
	while _nodes.size() < count:
		_nodes.append({"lane": 0, "parents": [] if last_main < 0 else [last_main]})
		last_main = _nodes.size() - 1
		# 6개마다 가지를 내어 커밋 3개 후 main으로 병합
		if _nodes.size() % 6 == 0 and _nodes.size() + 4 <= count:
			var lane := next_lane
			next_lane = 2 if next_lane == 1 else 1
			var parent := last_main
			for _k in 3:
				_nodes.append({"lane": lane, "parents": [parent]})
				parent = _nodes.size() - 1
			_nodes.append({"lane": 0, "parents": [last_main, parent]})
			last_main = _nodes.size() - 1
	custom_minimum_size = Vector2(MARGIN.x * 2 + LANE * 3, MARGIN.y * 2 + ROW * _nodes.size())
	queue_redraw()


func _process(_delta: float) -> void:
	if redraw_every_frame:
		queue_redraw()


func _position(index: int) -> Vector2:
	# 최신 커밋이 위로 오게 그린다 (git log 순서와 같음)
	var lane: int = _nodes[index]["lane"]
	return MARGIN + Vector2(lane * LANE, (_nodes.size() - 1 - index) * ROW)


func _draw() -> void:
	for i in _nodes.size():
		var to := _position(i)
		for p in _nodes[i]["parents"]:
			var from := _position(int(p))
			var lane: int = _nodes[i]["lane"]
			draw_line(from, to, LANE_COLORS[maxi(lane, int(_nodes[int(p)]["lane"]))], 3.0, true)
	for i in _nodes.size():
		var lane: int = _nodes[i]["lane"]
		draw_circle(_position(i), RADIUS, LANE_COLORS[lane])
		if _nodes[i]["parents"].size() == 2:
			draw_circle(_position(i), RADIUS * 0.45, Color.WHITE)  # 병합 커밋 표시

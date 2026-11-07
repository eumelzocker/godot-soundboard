class_name SoundLengthScanner
extends Node

## Determines the length of queued audio files in the background, spending at most
## frame_budget_ms per frame so large folders do not block the UI. Loaded streams stay in the
## AudioFileLoader cache, so a later first play starts without loading.

signal length_ready(path: String, seconds: float)

@export_range(1.0, 50.0, 0.5, "suffix:ms") var frame_budget_ms: float = 4.0

var _queue: Array[String] = []


func _ready() -> void:
  set_process(false)


## Replaces any pending work with [param paths].
func scan(paths: Array[String]) -> void:
  _queue = paths.duplicate()
  set_process(not _queue.is_empty())


func is_scanning() -> bool:
  return not _queue.is_empty()


func _process(_delta: float) -> void:
  var deadline := Time.get_ticks_usec() + int(frame_budget_ms * 1000.0)
  while not _queue.is_empty() and Time.get_ticks_usec() < deadline:
    var path: String = _queue.pop_front()
    var stream := AudioFileLoader.load_stream(path)
    if stream != null:
      length_ready.emit(path, stream.get_length())
  set_process(not _queue.is_empty())

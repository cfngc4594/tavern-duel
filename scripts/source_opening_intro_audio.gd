extends Node
const Audio=preload("res://scripts/source_opening_audio.gd")
## Fixed-build zhCN announcer path. Muting is not source-load failure.
const CLIPS: Array = [
 {"path":"res://assets/original_opening/audio/announcer_jaina_VO_ANNOUNCER_JAINA_06.wav","frames":60557},
 {"path":"res://assets/original_opening/audio/announcer_versus_VO_ANNOUNCER_VERSUS_21.wav","frames":42496},
 {"path":"res://assets/original_opening/audio/announcer_guldan_VO_ANNOUNCER_GUL_DAN_13.wav","frames":92304}
]
const GAP: float = 0.05000000074505806
const SOURCE_FALLBACK_HOLD: float = 0.6000000238418579
var game
var muted: bool = false
var played: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var missing: Array = []
var last_age: float = -1.0

static func announcer_duration() -> float:
 return (60557.0 + 42496.0 + 92304.0) / 48000.0 + 2.0 * GAP

static func intro_extension() -> float:
 return announcer_duration() - SOURCE_FALLBACK_HOLD

static func schedule() -> Array:
 var result: Array = []
 var at: float = 0.0
 for clip in CLIPS:
  result.append({"at":at,"path":clip.path,"duration":float(clip.frames)/48000.0})
  at += float(clip.frames)/48000.0 + GAP
 return result

func setup(host) -> void:
 game = host
 for clip in CLIPS:
  if not ResourceLoader.exists(str(clip.path)): missing.append(clip.path)

func reset() -> void:
 Audio.stop_tree(self)
 for player in players:
  if is_instance_valid(player): player.stop(); player.queue_free()
 players.clear()
 played.clear()
 last_age = -1.0

func sample(age: float) -> void:
 if age < last_age: reset()
 last_age = age
 for i in range(CLIPS.size()):
  var event: Dictionary = schedule()[i]
  if played.has(i) or age < float(event.at): continue
  played[i] = true
  if muted or not Audio.permitted(game) or not missing.is_empty(): continue
  # Frame-step/seek compatibility: skip an already elapsed clip, seek into active.
  var elapsed: float = maxf(0.0, age - float(event.at))
  if elapsed >= float(event.duration): continue
  var player := AudioStreamPlayer.new()
  player.bus = &"SFX"
  add_child(player)
  player.stream = load(str(event.path))
  player.pitch_scale = 1.0
  player.volume_db = 0.0
  players.append(player)
  player.finished.connect(player.queue_free)
  player.play(elapsed)

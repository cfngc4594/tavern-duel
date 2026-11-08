extends Node
const Audio=preload("res://scripts/source_opening_audio.gd")
## Classic HERO_07 then HERO_08 START; invoke only for source option12 && !skip.
## Runs concurrently with dealing, never extends the announcer intro timeline.
var game
var muted: bool = false
var fired: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var last_age: float = -1.0
const EVENTS: Array = [
 {"at":0.0,"duration":3.515375,"path":"res://assets/original_opening/audio/start_guldan_VO_HERO_07_Start_09.wav"},
 {"at":3.515375,"duration":1.488,"path":"res://assets/original_opening/audio/start_jaina_VO_HERO_08_Start_64.wav"}
]
func setup(host) -> void:
 game=host
func reset() -> void:
 Audio.stop_tree(self)
 for player in players:
  if is_instance_valid(player):player.stop();player.queue_free()
 players.clear();fired.clear();last_age=-1.0
func sample(age: float) -> void:
 if age<last_age:reset()
 last_age=age
 for i in range(EVENTS.size()):
  var event:Dictionary=EVENTS[i]
  if fired.has(i) or age<float(event.at):continue
  fired[i]=true
  var elapsed:float=age-float(event.at)
  if muted or not Audio.permitted(game) or elapsed>=float(event.duration):continue
  var player:=AudioStreamPlayer.new();player.bus=&"SFX";add_child(player)
  player.stream=load(event.path);player.pitch_scale=1.0;player.volume_db=0.0
  players.append(player);player.finished.connect(player.queue_free);player.play(maxf(0.0,elapsed))

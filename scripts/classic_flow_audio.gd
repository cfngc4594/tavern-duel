extends Node
## Unchanged public original audio. Archive names verified; 2014 mix is not.
## The looping/cross-event timing below is reconstructed, not source loop metadata.
const DIRECTORY="res://assets/audio/flow/"
const HASHES={
	"turn_timer_end_turn_button_flips_over.wav":"f82f23b94bee6f39e120af4b69c149acd8f1406842f2db4be7f5376d6d548210",
	"turn_timer_fuse_unravels.wav":"98fabedd5c807409c6b07ba815972eda8971bf3d721f4c340057ca146710dc4d",
	"turn_timer_fuse_burns.wav":"f473fa6020cd5ee24ba31a9bc838a26c33d7d478e33ec4fc6b2fd1d4a2bd9c50",
	"turn_timer_end_turn_button_explodes.wav":"ad95d9c6f3e7e13fa990a7a5f641200ccccb88b8bc0aa0e9c327157c4f33a1de"
}
var voices: Array[AudioStreamPlayer]=[]
var burn_active=false
var history: Array=[]

func _ready():
	for i in range(3):
		var voice=AudioStreamPlayer.new();voice.bus=&"SFX";voice.volume_db=-7;add_child(voice);voices.append(voice)
	voices[1].finished.connect(func():
		if burn_active and SoundManager.sfx_enabled: voices[1].play()
	)

func _play(index:int, filename:String):
	if not SoundManager.sfx_enabled or SoundManager.sfx_volume<=0: return
	var path=DIRECTORY+filename
	if not HASHES.has(filename) or not ResourceLoader.exists(path): return
	if FileAccess.file_exists(path) and FileAccess.get_sha256(path)!=HASHES[filename]: return
	voices[index].stream=load(path);voices[index].pitch_scale=1.0;voices[index].play()
	history.append({"event":filename,"path":path,"time_ms":Time.get_ticks_msec(),"pitch":1.0})
	if history.size()>128: history.pop_front()

func button_flip():
	# A fast, empty enemy turn can finish after the visual timeout flash but
	# before the original expiry WAV ends. Preserve that tail on the shared voice.
	if voices.size()>2 and voices[2].playing and voices[2].stream != null and voices[2].stream.resource_path.ends_with("turn_timer_end_turn_button_explodes.wav"):
		return
	_play(2,"turn_timer_end_turn_button_flips_over.wav")

func rope_start(): _play(0,"turn_timer_fuse_unravels.wav")
func rope_burn():
	burn_active=true;_play(1,"turn_timer_fuse_burns.wav")
func rope_timeout():
	stop();_play(2,"turn_timer_end_turn_button_explodes.wav")
func stop_rope():
	burn_active=false
	for i in range(mini(2,voices.size())): voices[i].stop()

func stop():
	burn_active=false
	for voice in voices: voice.stop()

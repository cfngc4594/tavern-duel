extends "res://scripts/game.gd"
func _ready():pass
func _process(_dt):pass
func play_sound(_kind):pass
func _event(_name):pass
func _begin_spell_audio_preview(_key):pass
func _cancel_spell_audio_preview():pass
func _target_feedback_at(_point):return {}
func _exit_tree():pass
var rejected_reason=""
var cast_count=0
func _reject_card(_index,_point,reason)->bool:
 rejected_reason=reason;return false
func _spend_mana(cost,side=0):
 if side==0:mana-=cost
 else:enemy_mana-=cost
func _cast_dual_spell(_key,_target,_side,_point):cast_count+=1
func _log(_label,_detail,_color):pass

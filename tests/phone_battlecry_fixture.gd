extends "res://scripts/game.gd"
var summons:=0
var resolved_target:Dictionary={}
func _ready():pass
func _process(_dt):pass
func _exit_tree():pass
func play_sound(_kind):pass
func _event(_kind):pass
func show_toast(_text):pass
func _cancel_spell_audio_preview():pass
func _reject_feedback(_point,_reason,_origin=Vector2.ZERO):pass
func _spend_mana(cost,_side=0):mana-=cost
func _log(_a,_b,_c):pass
func _new_unit(key,side,pos):
 return {"key":key,"side":side,"pos":pos,"scale":1.0,"dead":false,"animating":false}
func _summon_effect(_unit,_source={},target={}):
 summons+=1;resolved_target=target

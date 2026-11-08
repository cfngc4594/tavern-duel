extends "res://scripts/game.gd"
var presses:=0
var releases:=0
var cancels:=0
var begins:=0
var real_hand_hit_test:=false
var grabbed_index:=-1
func _ready(): pass
func _process(_dt): pass
func _update_hover(_audio:bool=true):
 if real_hand_hit_test: super._update_hover(false)
 else: hover_card=2
func _pointer_press():
 presses+=1;press_screen_pos=screen_pointer;pressed_card=hover_card if real_hand_hit_test else 2
func _pointer_release(): releases+=1
func cancel_interaction(): cancels+=1
func _begin_card_drag(_index:int): begins+=1;drag_index=_index;grabbed_index=_index
func real_pointer_release(): super._pointer_release()

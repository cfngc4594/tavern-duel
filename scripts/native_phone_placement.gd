extends RefCounted
## InputManager.PlayZoneSlotMousedOver 0x06005a11, ordinary classic minions.
## No invented screen hysteresis. Source slot is 1-based, game insertion is 0-based.
const Layout=preload("res://scripts/source_phone_board_layout.gd")
static func slot_width(row:Dictionary,count:int,source_previous_slot:int)->float:
 var width_count=clampi(count+(1 if source_previous_slot>=1 else 0),0,int(row.spacing.max_slots))
 return float(row.collider_bounds.size[0])/float(row.spacing.max_slots)*(1.0+float(row.spacing.phone_width_modifiers[width_count]))
static func source_slot(row:Dictionary,count:int,previous:int,hit_x:float,held_x:float)->int:
 var width=slot_width(row,count,previous)
 var center_x=float(row.phone_world_position[0])
 var left=center_x-(count+1)*width*.5
 var slot=int(ceil((hit_x-left)/width))-1
 if slot<0 or slot>count:slot=0 if held_x<center_x else count
 return slot+1
static func ray_hit(context,point:Vector2)->Dictionary:
 # Original layer12 hit, filtered to Battlefield only after friendly-play gate.
 return preload("res://scripts/native_phone_input_hitboxes.gd").hit(context,point,12,{},"BattlefieldHitbox")

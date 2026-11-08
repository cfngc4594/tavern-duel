extends RefCounted
## InputManager.UpdateTargetingArrow 0x060059d2 / HandleUpdateWhileHoldingCard
## 0x06005a13 / ShouldCancelTargeting 0x060059d1 / DropHeldSpellLikeCard 0x06005a26.
## Ordinary classic spells, without deck actions, reverse target or hand targets.
static func over_playfield(context,point:Vector2,hero_targeting:bool=false)->bool:
 return not preload("res://scripts/native_phone_input_hitboxes.gd").hit(context,point,12,{"HeroHitboxForPhone":hero_targeting}).is_empty()
static func keep_targeting(context,point:Vector2)->bool:
 return not preload("res://scripts/native_phone_input_hitboxes.gd").hit(context,point,16).is_empty()
static func next_aim(current:bool,over_field:bool,over_phone_keep_region:bool,has_response:bool)->bool:
 if current:return over_field or over_phone_keep_region
 return over_field and has_response

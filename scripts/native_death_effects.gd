extends "res://scripts/native_combat_effects.gd"
## Source ordinary-death FSM. External Actor references deliberately remain
## distinct from this Spell's own hierarchy, including Actor/Spells damage UI.
var controller: Node
const ACTOR="__death_actor"
const BODY="__death_body"
const MESH="__death_mesh"

func setup_death(owner_game: Node,source_assets,owner_controller: Node,source_routes: Dictionary):
 controller=owner_controller;super.setup(owner_game,source_assets);routes=source_routes
 particle_script=preload("res://scripts/native_death_particles.gd")

func begin(record: Dictionary,actor: Dictionary,owner_serial: int) -> Dictionary:
 var unit: Dictionary=record.unit
 var effect: Dictionary=_spawn(str(routes["minion_death/root"].root_key),unit.pos,"minion_death/root",owner_serial)
 if effect.is_empty():return effect
 effect.actor=actor;effect.follow_unit=unit;effect.unit_id=int(unit.id);effect.card_id=str(unit.key);effect.side=int(unit.side)
 effect.context={"key":unit.key,"side":unit.side,"source":unit.pos,"target":{"type":"unit","unit":unit,"pos":unit.pos}}
 effect.source_origin=record.start;effect.actor_clip={};effect.source_moves=[];effect.source_shakes=[];effect.renderer_visibility={};effect.body_hidden=false
 if not actor.is_empty():
  var body: Node3D=actor.paths.get("RootObject")
  effect.body=body;effect.body_origin=body.position if is_instance_valid(body) else Vector3.ZERO
  var mesh_node: Node3D=actor.paths.get("RootObject/Card_InPlay_Ally/Mesh")
  effect.actor_mesh_key=mesh_node.get_meta("source_key","") if is_instance_valid(mesh_node) else ""
  var mesh: MeshInstance3D=actor.renderers.get(effect.actor_mesh_key)
  if is_instance_valid(mesh):
   var material: Material=mesh.get_surface_override_material(0)
   if material is ShaderMaterial:
    effect.portrait=material.get_shader_parameter("_MainTex")
    if effect.portrait==null:effect.portrait=material.get_shader_parameter("main_tex")
   elif material is StandardMaterial3D:effect.portrait=material.albedo_texture
  for materials in effect.state.materials.values():
   for material in materials:game.native_damage._compensate_reflected_culling(material)
 _project(effect)
 _start_event(effect,"__start__",0.0)
 _start_event(effect,"Birth",0.0)
 return effect

func _target_key(effect: Dictionary,action: Dictionary) -> String:
 var params: Dictionary=action.params
 var target: Dictionary=params.get("gameObject",params.get("m_GameObject",{}))
 var value=_value(effect,target.get("gameObject",{}))
 if value is String:return value
 if action.get("target_object_key")!=null:return str(action.target_object_key)
 return effect.root_key if int(target.get("ownerOption",0))==0 else ""

func _action(effect: Dictionary,action: Dictionary,moment: float):
 if not bool(action.get("enabled",true)):return
 var params: Dictionary=action.params;var key: String=_target_key(effect,action)
 match str(action.class_name):
  "SpellInitActorVariables":
   for pair in [["m_actorObject",ACTOR],["m_rootObject",BODY],["m_rootObjectMesh",MESH]]:
    var name: String=str(params.get(pair[0],{}).get("name",""))
    if name!="":effect.variables[name]=pair[1]
  "GetCardPortraitTextureAction":
   var name: String=str(params.get("storedTexture",{}).get("name",""))
   effect.variables[name]=assets.load_texture(str(assets.portrait_by_card[effect.card_id])) if assets.portrait_by_card.has(effect.card_id) and not game.headless else effect.get("portrait")
   effect.events.append({"event":"source_portrait_read","card_id":effect.card_id,"time":moment})
  "SetMaterial":
   if key!=MESH:effect.unsupported.append("SetMaterial target "+key);return
   var source_key: String=str(action.get("reference_keys",{}).get("params.material.value",""))
   effect.death_material_key=source_key
   effect.events.append({"event":"source_material_replaced","source_key":source_key,"material_index":int(_value(effect,params.get("materialIndex",{}),0)),"time":moment})
   if game.headless:return
   var mesh: MeshInstance3D=effect.actor.renderers.get(effect.actor_mesh_key)
   if not is_instance_valid(mesh):effect.unsupported.append("Actor.GetRootObjectMesh unavailable");return
   var index: int=int(_value(effect,params.get("materialIndex",{}),0))
   var material: Material=assets.material(source_key)
   # This existing Actor portrait surface was winding-adapted by v31. Preserve
   # its geometry and backend convention; do not flip source indices again.
   mesh.set_surface_override_material(index,material);effect.actor.materials[effect.actor_mesh_key][index]=material
   effect.death_material=material
  "SetMaterialTexture":
   if key!=MESH:effect.unsupported.append("SetMaterialTexture target "+key);return
   var texture=_value(effect,params.get("texture",{}))
   var property: String=str(_value(effect,params.get("namedTexture",{}),"_MainTex"))
   if effect.get("death_material") is ShaderMaterial and texture is Texture2D:
    effect.death_material.set_shader_parameter(property,texture)
    assets.endgame_textures.bind_source_sampler(effect.death_material,property,texture,assets)
    effect.portrait_bound=true
   effect.events.append({"event":"source_portrait_bound","property":property,"card_id":effect.card_id,"time":moment})
  "AnimationPlaythroughAction":
   if key==ACTOR:
    effect.actor_clip={"name":str(_value(effect,params.get("m_AnimName",{}),"")),"start":moment}
    effect.events.append({"event":"source_actor_clip","clip":effect.actor_clip.name,"time":moment})
   else:super._action(effect,action,moment)
  "iTweenShakePosition":
   if key!=BODY:effect.unsupported.append("iTweenShakePosition target "+key);return
   effect.source_shakes.append({"start":moment+float(_value(effect,params.get("delay"),0.0)),"duration":float(_value(effect,params.get("time"),0.0)),"amount":Curves.vec(_value(effect,params.get("vector"),{})),"space":int(params.get("space",0)),"step":-1,"offset":Vector3.ZERO})
   effect.events.append({"event":"source_body_shake","time":moment,"duration":float(_value(effect,params.get("time"),0.0))})
  "iTweenMoveTo":
   var node: Node3D=effect.state.get("nodes",{}).get(key)
   if int(params.get("space",1))!=1:effect.unsupported.append("iTweenMoveTo nonlocal target "+key);return
   if is_instance_valid(node):effect.source_moves.append({"node":node,"origin":node.position,"destination":Curves.vec(_value(effect,params.get("vectorPosition"),{})),"start":moment+float(_value(effect,params.get("delay"),0.0)),"duration":float(_value(effect,params.get("time"),0.0)),"ease":int(params.get("easeType",21)),"stop_on_exit":bool(_value(effect,params.get("stopOnExit"),false))})
   effect.events.append({"event":"source_collision_plane_move","source_key":key,"time":moment,"begin":moment+float(_value(effect,params.get("delay"),0.0)),"duration":float(_value(effect,params.get("time"),0.0))})
  "SetVisibilityRecursiveAction":
   var visible: bool=bool(_value(effect,params.get("visible"),true))
   if key==BODY:
    effect.body_hidden=not visible
    if is_instance_valid(effect.get("body")):effect.body.visible=visible
    effect.events.append({"event":"source_body_visibility","visible":visible,"time":moment})
   else:
    for child_key in _descendants(key):
     effect.renderer_visibility[child_key]=visible
     var node: Node3D=effect.state.get("nodes",{}).get(child_key)
     if is_instance_valid(node):node.set_meta("source_renderer_enabled",visible)
     if effect.particles.has(child_key):effect.particles[child_key].node.source_renderer.m_Enabled=visible
    super._action(effect,action,moment)
  "AudioPlaythroughAction":
   controller.dispatch_body_audio(effect,moment)
   effect.events.append({"event":"source_audio_birth_dispatch","source_event":"@actor/type_5","unit_id":effect.unit_id,"time":moment})
  "InvokeMethod":
   if str(_value(effect,params.get("behaviour"),""))=="ProjectedShadow" and str(_value(effect,params.get("methodName"),""))=="DisableShadow":
    effect.events.append({"event":"source_projected_shadow_disable","source_key":key,"time":moment})
   else:super._action(effect,action,moment)
  _:super._action(effect,action,moment)

func _project(effect: Dictionary):
 super._project(effect)
 if not is_instance_valid(effect.get("projection")) or effect.get("actor",{}).is_empty():return
 var actor: Node3D=effect.actor.root
 if is_instance_valid(actor):effect.projection.global_transform=actor.global_transform

func _sample_animations(effect: Dictionary,time: float):
 super._sample_animations(effect,time)
 for move in effect.get("source_moves",[]):
  if not is_instance_valid(move.node) or time<float(move.start):continue
  var t: float=clampf((time-float(move.start))/maxf(float(move.duration),0.000001),0.0,1.0)
  move.node.position=move.origin.lerp(move.destination,_ease(t,int(move.ease)))

func _sample(effect: Dictionary):
 super._sample(effect)
 if not effect.get("actor",{}).is_empty() and is_instance_valid(effect.actor.root):
  if not effect.actor_clip.is_empty():assets.sample_clip(effect.actor,str(effect.actor_clip.name),maxf(0.0,float(effect.age)-float(effect.actor_clip.start)))
  var body: Node3D=effect.get("body")
  if is_instance_valid(body):
   body.visible=not bool(effect.body_hidden)
   var source_world_offset: Vector3=_shake_offset(effect)
   var board_basis:=Basis(Vector3.RIGHT,Vector3(0,sin(PI/12.0),cos(PI/12.0)),Vector3(0,cos(PI/12.0),-sin(PI/12.0)))*PROJECTION_SCALE
   if SourceProjection.from_game(game)!=null:board_basis=SourceProjection.REFLECTION
   body.position=effect.body_origin+body.get_parent().global_basis.inverse()*(board_basis*source_world_offset)

func _shake_offset(effect: Dictionary) -> Vector3:
 var offset:=Vector3.ZERO
 for shake in effect.source_shakes:
  var age: float=float(effect.age)-float(shake.start)
  if age<0.0 or age>=float(shake.duration):continue
  # Native iTween random-frame sampling is replaced by a fixed visual-only
  # clock. Source amplitude/duration/decay are retained; never use game.rng.
  var step: int=int(floor(age*120.0))
  while int(shake.step)<step:
   shake.step+=1
   var amount: Vector3=shake.amount*(1.0-float(shake.step)/120.0/float(shake.duration))
   shake.offset=Vector3(visual_rng.randf_range(-amount.x,amount.x),visual_rng.randf_range(-amount.y,amount.y),visual_rng.randf_range(-amount.z,amount.z))
  offset+=shake.offset
 return offset

func _audit(effect: Dictionary) -> Dictionary:
 var result: Dictionary=super._audit(effect)
 result.unit_id=effect.get("unit_id",-1);result.card_id=effect.get("card_id","");result.side=effect.get("side",-1);result.body_hidden=effect.get("body_hidden",false);result.portrait_bound=effect.get("portrait_bound",false);result.death_material_key=effect.get("death_material_key","")
 result.actor_clip=effect.get("actor_clip",{}).duplicate(true)
 if effect.get("death_material") is ShaderMaterial:
  result.portrait_parameters={"_ValueRange":effect.death_material.get_shader_parameter("_ValueRange"),"_Transistion":effect.death_material.get_shader_parameter("_Transistion"),"_Color":effect.death_material.get_shader_parameter("_Color")}
 for particle in result.particles:
  for issue in particle.get("unsupported",[]):
   var name: String="particle:"+str(particle.source_key)+":"+str(issue)
   if not result.unsupported.has(name):result.unsupported.append(name)
 return result

func release(effect: Dictionary):
 if is_instance_valid(effect.get("body")):effect.body.position=effect.get("body_origin",Vector3.ZERO)
 _dispose(effect)

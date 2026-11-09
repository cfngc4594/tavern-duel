extends SceneTree
const Base=preload("res://scripts/native_combat_particles.gd")
const Death=preload("res://scripts/native_death_particles.gd")
const Effects=preload("res://scripts/native_death_effects.gd")
const Assets=preload("res://scripts/native_death_assets.gd")
var failed:=false
var checks:=0
var meshes:=0
func require(ok:bool,label:String):
 if not ok:failed=true;push_error("DEATH_INITIAL_GEOMETRY_FAIL "+label)
func compare(a,b,label:String,geometry:bool=true):
 require(var_to_bytes(a.particles)==var_to_bytes(b.particles),label+" particles")
 require(a.rng.state==b.rng.state and a.death_rng.state==b.death_rng.state,label+" RNG")
 for field in ["emitted_count","live_count","active","collision_count","screen_size_clamped","simulation_time","stop_time","death_events","subemitter_emitted","pending_events","speed_segments","last_emitter","last_local_scale"]:
  require(var_to_bytes(a.get(field))==var_to_bytes(b.get(field)),label+" "+field)
 if geometry:
  require(a.mesh.get_surface_count()==b.mesh.get_surface_count(),label+" surfaces")
  for i in mini(a.mesh.get_surface_count(),b.mesh.get_surface_count()):
   require(var_to_bytes(a.mesh.surface_get_arrays(i))==var_to_bytes(b.mesh.surface_get_arrays(i)),label+" mesh");meshes+=1
  require(a.mesh_instance.visible==b.mesh_instance.visible,label+" visibility")
 require(a.subemitter_templates.size()==b.subemitter_templates.size(),label+" templates")
 for i in mini(a.subemitter_templates.size(),b.subemitter_templates.size()):compare(a.subemitter_templates[i].solver,b.subemitter_templates[i].solver,label+" child",true)
 checks+=1
func _initialize():call_deferred("run")
func run():
 var assets=Assets.new();assets.setup(null,"res://assets/original_death_v35/")
 var world:=Node3D.new();root.add_child(world)
 var state:Dictionary=assets.instantiate("cab-69c88b234dfa427e02d1fcee9337ae34:5210564580019615545",world)
 var effects=Effects.new();root.add_child(effects);effects.assets=assets
 var count:=0
 for key in state.particles:
  var spec:Dictionary=state.particles[key]
  spec.node.set_meta("source_renderer_enabled",true)
  for scenario in ["normal","speed","stop","destroy"]:
   var a=Death.new();var b=Death.new()
   Base.death_initial_geometry_defer_enabled=false
   effects._setup_particle(a,spec,{"projection":world,"serial":71,"particles":{},"_sampling_particle_setup":true})
   Base.death_initial_geometry_defer_enabled=true
   effects._setup_particle(b,spec,{"projection":world,"serial":71,"particles":{},"_sampling_particle_setup":true})
   require(b.mesh.get_surface_count()==0,"initial geometry deferred")
   require(not b.defer_initial_geometry and not b._skip_initial_geometry,"one-shot reset")
   compare(a,b,key+" setup",false)
   if scenario=="speed":a.set_playback_speed(.7,0.0);b.set_playback_speed(.7,0.0)
   if scenario=="stop":a.stop_emitting(0.0);b.stop_emitting(0.0)
   if scenario=="destroy":a.source_destroy();b.source_destroy()
   for age in [0.0,.017,.5,.9,.21,1.2]:
    a.seek(age);b.seek(age);compare(a,b,key+scenario+str(age))
   a.free();b.free()
  # Enabled global flag alone must never defer independent setup or spawn.
  var direct=Death.new();var eager=Death.new()
  Base.death_initial_geometry_defer_enabled=false;direct.setup(spec,assets,world,99)
  Base.death_initial_geometry_defer_enabled=true
  effects._setup_particle(eager,spec,{"projection":world,"serial":0,"particles":{}})
  var spawn_reference=Death.new();Base.death_initial_geometry_defer_enabled=false;spawn_reference.setup(spec,assets,world,0)
  Base.death_initial_geometry_defer_enabled=true;compare(spawn_reference,eager,"spawn outside sample")
  spawn_reference.free()
  var independent=Death.new();independent.setup(spec,assets,world,99)
  compare(direct,independent,"independent")
  require(not eager.defer_initial_geometry and not eager._skip_initial_geometry,"outside sample not armed")
  direct.free();eager.free();independent.free();count+=1
 # The caller helper must not arm a derived/unknown particle adapter.
 var derived:=GDScript.new();derived.source_code='extends "res://scripts/native_death_particles.gd"\n'
 require(derived.reload()==OK,"unknown subclass compiles")
 var unknown=derived.new();var unknown_reference=derived.new()
 var first:Dictionary=state.particles.values()[0]
 Base.death_initial_geometry_defer_enabled=false;unknown_reference.setup(first,assets,world,391)
 Base.death_initial_geometry_defer_enabled=true
 effects._setup_particle(unknown,first,{"projection":world,"serial":1,"particles":{},"_sampling_particle_setup":true})
 compare(unknown_reference,unknown,"unknown subclass fallback")
 unknown.free();unknown_reference.free()
 Base.death_initial_geometry_defer_enabled=false
 world.free();effects.free()
 if not failed:print("DEATH_INITIAL_GEOMETRY_PASS sources=",count," checks=",checks," meshes=",meshes," exact simulation/RNG; same-frame speed/stop/destroy, coarse dt/rewind, independent fallback")
 quit(1 if failed else 0)

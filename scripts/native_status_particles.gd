extends "res://scripts/native_combat_particles.gd"
## Source status Spell owns a reusable ParticleSystem. Clear removes particles,
## StopEmitting ends births, and Play resumes/restarts emission without destroying
## the native compatibility solver or consuming the historical rules RNG.
var play_restarts:=0
var clear_count:=0
var authored_delay:=0.0
const EdgeSampler=preload("res://scripts/native_status_edge_sampler.gd")
var edge_sampler
func _is_frozen_hero_edge() -> bool:
 return source_key==EdgeSampler.SYSTEM_KEY and int(raw.get("ShapeModule",{}).get("type",-1))==6 and int(raw.get("ShapeModule",{}).get("placementMode",-1))==1
func _validate_used_fields() -> void:
 super._validate_used_fields()
 if _is_frozen_hero_edge():
  unsupported.erase("ShapeModule mesh placement other than Vertex/Triangle")
  compatibility_notes.append("FX_Shatter placementMode1 maps to managed Edge1 through an explicit adapter, not a recovered native serialization contract; unique indexed edges per surface, length-weighted PCG selection and linear interpolation are compatibility algorithms")
  if int(raw.ShapeModule.get("m_MeshSpawn",{}).get("mode",0))!=0:_unsupported("FX_Shatter non-random mesh spawn")
func _load_shape_mesh(spec: Dictionary,assets) -> void:
 super._load_shape_mesh(spec,assets)
 if not _is_frozen_hero_edge():return
 if shape_mesh_key!=EdgeSampler.MESH_KEY:
  _unsupported("FX_Shatter original HeroFrameEmitter2 mesh mismatch");return
 var original_mesh: ArrayMesh=assets.geometry(shape_mesh_key)
 if original_mesh==null:return
 edge_sampler=EdgeSampler.new();edge_sampler.build(original_mesh,raw.ShapeModule)
 if edge_sampler.edges.is_empty():_unsupported("FX_Shatter has no nonzero source mesh edges")
func _sample_shape() -> Dictionary:
 if not _is_frozen_hero_edge():return super._sample_shape()
 if edge_sampler==null:return {}
 var sample: Dictionary=edge_sampler.sample(rng)
 if sample.is_empty():return {}
 var shape: Dictionary=raw.ShapeModule
 sample.point+=sample.direction*float(shape.get("m_MeshNormalOffset",0.0))
 if not bool(shape.get("m_UseMeshColors",true)):sample.color=Color.WHITE
 var basis:=Basis.from_euler(Curves.vec(shape.get("m_Rotation",{}))*PI/180.0,EULER_ORDER_YXZ)
 sample.point=basis*(sample.point*Curves.vec(shape.get("m_Scale",{"x":1,"y":1,"z":1})))+Curves.vec(shape.get("m_Position",{}))
 sample.direction=basis*sample.direction
 return sample
func setup(spec: Dictionary,assets,parent_root: Node3D,seed_value: int) -> void:
 super.setup(spec,assets,parent_root,seed_value)
 authored_delay=start_delay
func clear_particles(seconds: float=-1.0) -> void:
 var at: float=elapsed_seconds if seconds<0.0 else maxf(seconds,0.0)
 seek(at)
 particles.clear();live_count=0;mesh.clear_surfaces();clear_count+=1
 # Clear is not Stop/Destroy: retain emission timing, pending future births,
 # speed segments, renderer/source identity, and the local random stream.
func source_play(seconds: float=-1.0) -> void:
 var at: float=elapsed_seconds if seconds<0.0 else maxf(seconds,0.0)
 seek(at)
 if source_destroyed:return
 var now: float=_to_sim_time(at)
 var stopped: bool=is_finite(stop_time) or (not bool(raw.get("looping",false)) and now>start_delay+duration and live_count==0)
 if emission_playing and not stopped:return
 # Existing particles retain absolute birth times and finish normally. Only
 # the restarted emitter's new period uses the new source Play origin.
 start_delay=now+authored_delay;next_cycle=0;pending_events.clear()
 stop_time=INF;emission_playing=true;runtime_emission_fraction=0.0
 play_restarts+=1
 seek(at)
func get_audit() -> Dictionary:
 var result: Dictionary=super.get_audit()
 result.play_restarts=play_restarts;result.clear_count=clear_count
 result.status_lifecycle="Clear != Stop != Destroy; source Play on reusable system; native solver/RNG scheduling remains compatibility"
 if edge_sampler!=null:result.edge_compatibility={"mesh":shape_mesh_key,"edges":edge_sampler.edges.size(),"length":edge_sampler.total_length,"zero_length_skipped":edge_sampler.skipped_zero_length,"serialized_mapping_verified":false,"native_sampling_recovered":false}
 return result

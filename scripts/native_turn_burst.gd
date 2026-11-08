extends Node3D
# Original FX_Burst data + original shader; explicitly compatible CPU particle solver, not Unity native simulation.
const BASE='res://assets/native_turn_burst/'
const SOLVER_STEP=1.0/60.0 # Compatibility integration cadence, NOT a recovered original-client frame rate.
var mesh=ArrayMesh.new()
var material:ShaderMaterial
var raw:Dictionary
var source:Dictionary
var particles:Array=[]
var active=false
var elapsed_seconds=0.0
var seed_value=0
var audit={}
var emitter_basis=Basis(Quaternion(.5,-.5,.5,-.5))
var emitter_position=Vector3(0,0,.07976150512695312)
var viewport_ref:SubViewport
func setup(viewport:SubViewport,root:Node3D):
 root.add_child(self);viewport_ref=viewport
 raw=JSON.parse_string(FileAccess.get_file_as_string(BASE+'FX_Burst.raw.json')).components[1].data
 source=JSON.parse_string(FileAccess.get_file_as_string(BASE+'FX_Burst.emission_mesh.json'))
 material=ShaderMaterial.new();material.shader=load(BASE+'original_burst.gdshader');material.set_shader_parameter('main_tex',load(BASE+'FX_Burst.texture.png'))
 var mi=MeshInstance3D.new();mi.mesh=mesh;mi.material_override=material;mi.name='OriginalBurstSharedGeometry';add_child(mi)
 # Keep same mesh Resource for the RGB/mask/shadow duplicates. Rebuild its surfaces in place.
 _rebuild()
 audit={'source':'Original TurnIndicator/FX_Burst 6006776399460560140','count':80,'shape':'mesh vertices, original80vertices; random selection','original_texture':'StarBurst1 -479225815140450812','shader':'240134070624251049 pass0 SrcAlpha One','scaling':'Shape: emitter .1 affects spawn positions only; no invented size/speed scaling','simulation':'World; generated positions expressed in banner reference frame, parent screen animation is project mapping','rng':'Godot PCG, explicit seed optional; NOT Unity autoRandomSeed stream','size_curve':'original unweighted cubic Hermite min/max, lifetime random blend','velocity_solver':'Compatibility fixed1/60 total-speed damping written back to persistent channel; animatedVelocity recomputed each step; native clamp writeback/integrator unverified','billboard':'view-facing in fixed orthographic banner camera; no source rotation','shared_geometry':true,'native_pixel_equivalence':false}
func restart(seed:int=-1):
 seed_value=seed if seed>=0 else int(Time.get_ticks_usec())
 var rng=RandomNumberGenerator.new();rng.seed=seed_value
 particles.clear();elapsed_seconds=0.0;active=true
 var init=raw.InitialModule
 for i in range(int(raw.EmissionModule.m_Bursts[0].countCurve.scalar)):
  var vi=rng.randi_range(0,source.positions.size()-1)
  var v=source.positions[vi];var n=source.normals[vi]
  var spawn=emitter_position+emitter_basis*(Vector3(v[0],v[1],v[2])*.10000000149011612)
  var speed=_random_constant(init.startSpeed,rng)
  var velocity=emitter_basis*(Vector3(n[0],n[1],n[2]).normalized()*speed)
  var animated_velocity=emitter_basis*Vector3(_random_constant(raw.VelocityModule.x,rng),_random_constant(raw.VelocityModule.y,rng),_random_constant(raw.VelocityModule.z,rng))
  var tint=Color.WHITE
  if source.colors!=null and source.colors.size()>vi:
   var c=source.colors[vi];tint=Color(c[0],c[1],c[2],c[3])
  particles.append({'spawn':spawn,'velocity0':velocity,'animated_velocity':animated_velocity,'life':_random_constant(init.startLifetime,rng),'size':_random_constant(init.startSize,rng),'size_mix':rng.randf(),'limit':_random_constant(raw.ClampVelocityModule.magnitude,rng),'color':tint,'vertex':vi})
 audit.seed=seed_value;_rebuild()
func _random_constant(c:Dictionary,rng:RandomNumberGenerator)->float:
 return rng.randf_range(float(c.minScalar),float(c.scalar)) if int(c.minMaxState)==3 else float(c.scalar)
func advance(delta:float):
 if active:set_elapsed(elapsed_seconds+maxf(delta,0.0))
func set_elapsed(time:float):
 elapsed_seconds=maxf(time,0.0)
 if material:material.set_shader_parameter('elapsed_seconds',elapsed_seconds)
 active=elapsed_seconds<1.0 and not particles.is_empty();_rebuild()
func cancel():
 active=false;particles.clear();_rebuild()
func _curve(keys:Array,t:float)->float:
 if keys.is_empty():return 0.0
 if t<=float(keys[0].time):return float(keys[0].value)
 if t>=float(keys[-1].time):return float(keys[-1].value)
 for i in range(keys.size()-1):
  var a=keys[i];var b=keys[i+1]
  if t<=float(b.time):
   var h=float(b.time)-float(a.time);var u=(t-float(a.time))/h
   return (2*u*u*u-3*u*u+1)*float(a.value)+(u*u*u-2*u*u+u)*h*float(a.outSlope)+(-2*u*u*u+3*u*u)*float(b.value)+(u*u*u-u*u)*h*float(b.inSlope)
 return 0.0
func _position_at(p:Dictionary,t:float)->Vector3:
 # Recompute from spawn so seek and the three shared render passes never diverge.
 var pos:Vector3=p.spawn;var persistent_velocity:Vector3=p.velocity0;var left=t
 while left>0.0000001:
  var dt=minf(SOLVER_STEP,left)
  # Unity documents animatedVelocity as recomputed every frame, separate from StartSpeed.
  var animated_velocity:Vector3=p.animated_velocity
  var vel=persistent_velocity+animated_velocity
  var speed=vel.length()
  if speed>float(p.limit):
   var excess=(speed-float(p.limit))*pow(1.0-float(raw.ClampVelocityModule.dampen),dt/SOLVER_STEP)
   vel=vel.normalized()*(float(p.limit)+excess)
  pos+=vel*dt
  # Explicit compatibility policy: store correction in persistent channel, not the animated value.
  # Native LimitVelocity writeback channel and timestep law remain unverified.
  persistent_velocity=vel-animated_velocity
  left-=dt
 return pos
func _rebuild():
 mesh.clear_surfaces()
 var vertices=PackedVector3Array();var uvs=PackedVector2Array();var colors=PackedColorArray();var indices=PackedInt32Array()
 if not active:return
 var curve=raw.SizeModule.curve
 # Render-target padding must not enlarge particles. Keep original application logical
 # camera width .72 at 900x500 => logical height .4; source maxParticleSize .5 => .2.
 # This is the established sample projection limit, NOT an original Unity camera measurement.
 var max_size=.5*(.72*500.0/900.0)
 for p in particles:
  if elapsed_seconds>=float(p.life):continue
  var age=elapsed_seconds/float(p.life)
  var size=float(p.size)*lerpf(_curve(curve.minCurve.m_Curve,age),_curve(curve.maxCurve.m_Curve,age),float(p.size_mix))
  size=minf(maxf(size,0.0),max_size)
  var center=_position_at(p,elapsed_seconds);var tint:Color=p.color;tint.a*=1.0-age
  var start=vertices.size();var half=size*.5
  for offset in [Vector3(-half,-half,0),Vector3(-half,half,0),Vector3(half,half,0),Vector3(half,-half,0)]:
   vertices.append(center+offset);colors.append(tint)
  uvs.append_array(PackedVector2Array([Vector2(0,1),Vector2(0,0),Vector2(1,0),Vector2(1,1)]))
  indices.append_array(PackedInt32Array([start,start+2,start+1,start,start+3,start+2]))
 if vertices.is_empty():return
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
func get_audit():
 var out=audit.duplicate(true);out.elapsed=elapsed_seconds;out.active=active;out.spawn_count=particles.size();out.shared_mesh_rid=str(mesh.get_rid());return out

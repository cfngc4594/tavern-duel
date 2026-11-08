extends SceneTree
class TestAssets extends 'res://scripts/native_combat_assets.gd':
 func material(_key: String,_texture_override: Texture2D=null) -> Material:return null
func _initialize():call_deferred('run')
func run():
 var a=TestAssets.new();a.setup()
 var system: Dictionary={}
 for key in a.objects:
  if str(key).ends_with(':-448261635012032771'):system=a.objects[key].duplicate(true)
 var go: String=system.refs['.m_GameObject'];var renderer: Dictionary=a.component(go,'ParticleSystemRenderer')
 system.data.lengthInSec=3.0;system.data.looping=false;system.data.prewarm=false;system.data.startDelay={'minMaxState':0,'scalar':0.0};system.data.EmissionModule.enabled=true;system.data.EmissionModule.m_Bursts=[];system.data.EmissionModule.rateOverTime={'minMaxState':0,'scalar':0.0};system.data.SubModule.enabled=false
 var parent=Node3D.new();root.add_child(parent);var node=Node3D.new();parent.add_child(node)
 var p=load('res://scripts/native_combat_particles.gd').new();p.setup({'system':system,'renderer':renderer,'node':node},a,parent,731)
 p.set_emission_rate(10,0);p.seek(.25);assert(p.emitted_count==2)
 p.set_emission_rate(20,.25);p.seek(.5);assert(p.emitted_count==7)
 p.set_emission_rate(0,.5);p.seek(1);assert(p.emitted_count==7)
 p.set_emission_rate(10,1);p.seek(1.25);assert(p.emitted_count==10)
 p.stop_emitting(1.25);p.seek(2);assert(p.emitted_count==10)
 print('DYNAMIC_EMISSION_RATE 5 checks PASS')
 parent.queue_free();await process_frame;quit()

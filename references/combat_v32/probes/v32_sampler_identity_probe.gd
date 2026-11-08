extends SceneTree
func _initialize():call_deferred('run')
func run():
 var owners: Array=[];var shaders: Array=[];var ids: Dictionary={};var codes: Dictionary={}
 var original=load('res://shaders/native_combat_additive.gdshader')
 for i in range(12):
  var sampler=preload('res://scripts/native_combat_samplers.gd').new();owners.append(sampler)
  var shader=sampler.variant(original,{'_MainTex':{'source_key':'audit_identity_'+str(i),'filter':2,'wrap_u':1,'wrap_v':1,'mip_count':1,'bias':-0.5}})
  shaders.append(shader);ids[shader.get_instance_id()]=true;codes[shader.code.sha256_text()]=true
 print('SAMPLER_IDENTITIES ',JSON.stringify({'instances':12,'shader_ids':ids.size(),'unique_codes':codes.size()}))
 quit()

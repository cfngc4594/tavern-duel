extends SceneTree
const Transmission=preload("res://scripts/native_combat_transmission.gd")
class EmptyScriptedMaterial extends StandardMaterial3D:
 pass
class ScriptedMaterial extends StandardMaterial3D:
 @export var array_value: Array=[1,{"a":2}]
 @export var dict_value: Dictionary={"nested":[3]}
var checks=0
func _initialize():call_deferred("run")
func sample(a,b,source,label):
 a._material_seen.clear();b._material_seen.clear()
 var x=a.transmission_material(source);var y=b.transmission_material(source)
 assert(x.get_class()==y.get_class(),label+" class")
 for prop in y.get_property_list():
  if (int(prop.usage)&PROPERTY_USAGE_STORAGE)==0 or prop.name in ["next_pass","resource_path","resource_name","script"]:continue
  assert(x.get(prop.name)==y.get(prop.name),label+" property "+str(prop.name))
 assert(x.render_priority==y.render_priority)
 if source.next_pass!=null:
  assert(x.next_pass.albedo_color==y.next_pass.albedo_color,label+" next pass")
 assert(x.get_meta("test_meta",-999)==y.get_meta("test_meta",-999),label+" metadata")
 checks+=1
 return x
func alternate(value,prop):
 match typeof(value):
  TYPE_BOOL:return not value
  TYPE_INT:
   if prop.hint==PROPERTY_HINT_FLAGS:return 0 if value!=0 else 1
   return 0 if value!=0 else 1
  TYPE_FLOAT:
   if prop.hint==PROPERTY_HINT_RANGE:
    var range_values=String(prop.hint_string).split(",")
    if range_values.size()>=2:
     var lo=float(range_values[0]);var hi=float(range_values[1])
     return lo if value!=lo else minf(hi,lo+(hi-lo)*.25)
   return .5 if value!=.5 else .25
  TYPE_COLOR:return Color(.2,.4,.7,.3)
  TYPE_VECTOR2:return Vector2(.4,.7)
  TYPE_VECTOR3:return Vector3(.4,.7,.9)
  TYPE_VECTOR4:return Vector4(.4,.7,.9,.2)
 return value
func run():
 var a=Transmission.new();var b=Transmission.new();b.base_storage_cache_enabled=false
 root.add_child(a);root.add_child(b)
 for source in [StandardMaterial3D.new(),ORMMaterial3D.new()]:
  sample(a,b,source,"initial")
  var id=source.get_instance_id()
  assert(a._base_property_records.has(id))
  for prop in source.get_property_list():
   if (int(prop.usage)&PROPERTY_USAGE_STORAGE)==0 or prop.name in ["next_pass","resource_path","resource_name","script"]:continue
   var old=source.get(prop.name);var value=alternate(old,prop)
   if value!=old:
    source.set(prop.name,value)
    sample(a,b,source,"direct native setter "+str(prop.name))
    source.set(prop.name,old)
    sample(a,b,source,"restore "+str(prop.name))
  for alpha in range(5):
   source.transparency=alpha;source.albedo_color=Color(.3,.4,.5,.15+.15*alpha)
   source.albedo_texture=GradientTexture2D.new()
   source.normal_enabled=true;source.normal_texture=GradientTexture2D.new()
   source.blend_mode=alpha;source.cull_mode=alpha%3
   source.render_priority=alpha;source.set_meta("test_meta",alpha)
   source.next_pass=StandardMaterial3D.new();source.next_pass.albedo_color=Color(.2,.3,.4,.2)
   sample(a,b,source,"alpha/texture/nextpass")
   source.albedo_texture=null;source.normal_texture=null;source.next_pass=null
   sample(a,b,source,"null resets")
  source.notify_property_list_changed()
  assert(not a._base_property_records.has(id) and not a._base_source_values.has(id))
  sample(a,b,source,"property list invalidation")
  # Transmission overrides must not poison the cached original values.
  source.shading_mode=BaseMaterial3D.SHADING_MODE_PER_PIXEL
  source.emission_enabled=true;source.albedo_color=Color(.8,.7,.6,.5)
  sample(a,b,source,"source values before overrides")
  sample(a,b,source,"same values after overrides")
  assert(a._base_source_values[id].albedo_color==source.albedo_color)
  assert(a._base_source_values[id].emission_enabled==true)
  # Only blend mode changes; source color stays identical across both directions.
  for blend in [BaseMaterial3D.BLEND_MODE_MIX,BaseMaterial3D.BLEND_MODE_MUL,BaseMaterial3D.BLEND_MODE_MIX,BaseMaterial3D.BLEND_MODE_MUL]:
   source.blend_mode=blend
   sample(a,b,source,"unchanged source color MIX/MUL transition")
  # Enabling/disabling reference mode must discard stale change snapshots.
  a.base_storage_cache_enabled=false;sample(a,b,source,"cache off")
  assert(not a._base_property_records.has(id))
  source.roughness=.37;a.base_storage_cache_enabled=true
  sample(a,b,source,"cache on")
 var scripted=ScriptedMaterial.new()
 sample(a,b,scripted,"script fallback")
 assert(not a._base_property_records.has(scripted.get_instance_id()))
 scripted.array_value[1].a=9;scripted.dict_value.nested.append(7)
 sample(a,b,scripted,"script mutable array/dict fallback")
 # A target created from a scripted source retains that script after the source
 # removes it. Do not enable cached native setters on this scripted mirror.
 scripted.set_script(null)
 sample(a,b,scripted,"initial script removed, target remains scripted")
 assert(a.material_cache[scripted.get_instance_id()].get_script()!=null)
 assert(not a._base_property_records.has(scripted.get_instance_id()))
 # Script attachment/removal on the same native object changes the safe path.
 var changed=StandardMaterial3D.new();sample(a,b,changed,"before script")
 changed.set_script(EmptyScriptedMaterial)
 sample(a,b,changed,"script attached")
 assert(not a._base_property_records.has(changed.get_instance_id()))
 changed.set_script(null);sample(a,b,changed,"script removed")
 assert(a._base_property_records.has(changed.get_instance_id()))
 for id in a._base_property_records:
  assert(a._base_property_records[id].reference is WeakRef)
 root.remove_child(a)
 assert(a._base_property_records.is_empty() and a._base_source_values.is_empty(),"tree exit releases records/signals")
 a.free();b.free()
 print("TRANSMISSION_BASE_STORAGE_PASS ",checks," all native storage properties, dynamic setters, alpha/texture/null, script fallback/changes, property-list invalidation")
 quit()
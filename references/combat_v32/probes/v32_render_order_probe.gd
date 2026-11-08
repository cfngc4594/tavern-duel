extends SceneTree
func _initialize():call_deferred('run')
func run():
 var assets=preload('res://scripts/native_combat_assets.gd').new();assets.setup();var checks:=0;var failures: Array=[];var tuples: Array=[];var materials: Array=[]
 var previous: int=-129
 for order in assets.source_sorting_orders:
  for queue in assets.source_render_queues:
   var mat:=ShaderMaterial.new();mat.set_meta('source_render_queue',queue);assets.apply_render_order(mat,order)
   checks+=1
   if mat.render_priority<=previous or mat.render_priority>127:failures.append('non-monotonic tuple')
   previous=mat.render_priority;tuples.append({'sorting_order':order,'render_queue':queue,'priority':previous})
 for key in assets.objects:
  if assets.objects[key].type!='Material':continue
  var a=assets.material(key);var b=assets.material(key);var baseline: int=b.render_priority
  assets.apply_render_order(a,2);var once: int=a.render_priority;assets.apply_render_order(a,2)
  checks+=3
  if once!=a.render_priority:failures.append('priority compounded')
  if b.render_priority!=baseline:failures.append('shared mutation')
  assets.apply_render_order(a,0)
  if a.render_priority!=baseline:failures.append('restore rank')
  materials.append({'source_key':key,'queue':a.get_meta('source_render_queue'),'priority':baseline})
 var result={'checks':checks,'failures':failures,'tuples':tuples,'materials':materials,'boundary':'Ordering is exact for current combat source tuples. Their bridge to the existing fixed board/card renderer keeps (sortingOrder0,Transparent3000) at Godot priority0; not a migration of whole original scene sorting.'}
 print('V32_RENDER_ORDER ',JSON.stringify({'checks':checks,'tuples':tuples.size(),'failures':failures}))
 FileAccess.open('/tmp/v32_render_order_probe.json',FileAccess.WRITE).store_string(JSON.stringify(result,'  '));quit(0 if failures.is_empty() else 1)

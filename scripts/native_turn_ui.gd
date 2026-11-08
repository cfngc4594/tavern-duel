extends Node
# Original 37.0 EndTurnButton mesh, UV, hierarchy and animation endpoints.
# Static pose renderer. Unlit presentation is compatibility, NOT recovered source scene lighting.
const BASE='res://assets/native_turn_ui/'
var _source_scene_attached:=false
var state_textures={}
var viewports=[]
var frame_count=0
var source={}
var audit={}
var dynamic_instance={}
var current_request=''
var settled_state=''
var clip_queue=[]
var active_clip={}
var clip_elapsed=0.0
var transition_serial=0
var settle_draws=0
var transitions=[]
var glyph_sample={}
var glyphs={}
var glyph_atlas:Texture2D
var label_audit=[]
func setup(_game):
 if not state_textures.is_empty():return
 source=JSON.parse_string(FileAccess.get_file_as_string(BASE+'board_ui.json'))
 glyph_sample=JSON.parse_string(FileAccess.get_file_as_string(BASE+'font36/glyphs-bounds.json'))
 for glyph in glyph_sample.glyphs:glyphs[glyph.character]=glyph
 glyph_atlas=load(BASE+'font36/atlas_rgba.png')
 for state in ['yellow','green','gray']:_build_state(state)
 _build_state('yellow',true)
 audit={'source':'37.0.0.255130.254477 original EndTurnButton','mesh_id':'-5618430085840305839','texture_id':'-2803162062817682347','states':['yellow=ENDTURN_YOUR_TURN','green=ENDTURN_NO_MORE_PLAYS','gray=ENDTURN_WAITING'],'geometry':'Original 150 vertices, UV and hierarchy; source animation endpoint transforms','lighting':'Compatibility unlit original texture; source DiffuseColor scene SH/light not recovered','text':'Actual sampled Unity font36 CharacterInfo UV/advance/atlas on original text-node transforms; Godot geometry/rasterization and Chinese string routing remain compatibility.','animation':'Original unweighted Hermite source curves; static API plus opt-in dynamic texture, latest request cancels prior sequence; no fabricated interpolation' ,'layout':'Standalone orthographic viewport, game places resulting texture; source board anchor omitted'}
 set_process(true)
func _process(delta):
 _sync_dynamic_viewport_attachment()
 frame_count+=1
 if frame_count==12:
  for vp in viewports:
   if dynamic_instance.is_empty() or vp!=dynamic_instance.viewport:vp.render_target_update_mode=SubViewport.UPDATE_DISABLED
 if not active_clip.is_empty():advance_animation(delta)
 elif settle_draws>0:
  settle_draws-=1
  if settle_draws==0 and not dynamic_instance.is_empty():dynamic_instance.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
func _canonical(state):
 var key=str(state).to_lower()
 if key in ['waiting','enemy','disabled','endturn_waiting']:return 'gray'
 if key in ['ready','no_more_plays','endturn_no_more_plays']:return 'green'
 if key in ['your_turn','available','endturn_your_turn']:return 'yellow'
 return key if key in ['yellow','green','gray'] else 'yellow'
func get_animated_button_texture(state):
 request_state(state)
 return state_textures.get('dynamic')
func request_state(state):
 var target=_canonical(state)
 if target==current_request:return false
 var previous=current_request
 transition_serial+=1;current_request=target;clip_queue.clear();active_clip={};clip_elapsed=0.0
 _sync_dynamic_viewport_attachment()
 dynamic_instance.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED if _source_scene_attached else SubViewport.UPDATE_ALWAYS;settle_draws=3
 if previous=='':
  _set_endpoint(target);settled_state=target
  transitions.append({'serial':transition_serial,'target':target,'initial_endpoint':true});return true
 if target=='gray':clip_queue=['ENDTURN_NMP_2_WAITING' if previous=='green' else 'ENDTURN_WAITING']
 elif target=='yellow':clip_queue=['ENDTURN_YOUR_TURN']
 else:clip_queue=['ENDTURN_NO_MORE_PLAYS'] if previous=='yellow' and settled_state=='yellow' else ['ENDTURN_YOUR_TURN','ENDTURN_NO_MORE_PLAYS']
 transitions.append({'serial':transition_serial,'target':target,'source_sequence':clip_queue.duplicate()})
 if transitions.size()>32:transitions.pop_front()
 _start_next_clip();return true
func _state(name):
 for entry in source.states:
  if entry.name==name:return entry
 return {}
func _set_endpoint(state):
 dynamic_instance.node.position=Vector3.ZERO;dynamic_instance.node.quaternion=Quaternion.IDENTITY
 var name={'yellow':'ENDTURN_YOUR_TURN','green':'ENDTURN_NO_MORE_PLAYS','gray':'ENDTURN_WAITING'}[state]
 var entry=_state(name);_apply_clip(entry,float(entry.duration))
func _start_next_clip():
 if clip_queue.is_empty():
  active_clip={};settled_state=current_request;settle_draws=3;return
 active_clip=_state(clip_queue.pop_front());clip_elapsed=0.0;_apply_clip(active_clip,0.0)
func advance_animation(delta):
 var remaining=maxf(delta,0.0)
 while not active_clip.is_empty():
  var duration=float(active_clip.duration);var step=minf(remaining,maxf(0.0,duration-clip_elapsed))
  clip_elapsed+=step;remaining-=step;_apply_clip(active_clip,clip_elapsed)
  if clip_elapsed+0.0000001<duration:break
  _start_next_clip()
  if remaining<=0.0:break
func sample_channel(channel,time):
 var keys=channel['keys']
 if keys.is_empty():return 0.0
 if time<=float(keys[0].time):return float(keys[0].value)
 if time>=float(keys[-1].time):return float(keys[-1].value)
 for i in range(keys.size()-1):
  var a=keys[i];var b=keys[i+1]
  if time>float(b.time):continue
  var dt=float(b.time)-float(a.time)
  if dt<=0.0:return float(b.value)
  if int(a.get('outTangentInfinity',0))!=0 or int(b.get('inTangentInfinity',0))!=0:return float(a.value)
  # All recovered button keys have weightedMode=0; do not silently invent weighted-curve support.
  assert(int(a.get('weightedMode',0))==0 and int(b.get('weightedMode',0))==0)
  var u=(time-float(a.time))/dt;var u2=u*u;var u3=u2*u
  return (2*u3-3*u2+1)*float(a.value)+(u3-2*u2+u)*dt*float(a.outTangent)+(-2*u3+3*u2)*float(b.value)+(u3-u2)*dt*float(b.inTangent)
 return float(keys[-1].value)
func _apply_clip(entry,time):
 if entry.is_empty():return
 var offset=dynamic_instance.offset
 for track in entry.tracks:
  if track.node!=source.endTurnMeshNode:continue
  var values=[]
  for channel in track.channels:values.append(sample_channel(channel,time))
  if track.kind=='position':dynamic_instance.node.position=Vector3(values[0],values[1],values[2])
  elif track.kind=='rotation':
   var q=Quaternion(values[0],values[1],values[2],values[3]);dynamic_instance.node.quaternion=q.normalized() if q.length_squared()>0.000001 else Quaternion.IDENTITY
  elif track.kind=='_MainTex.offset.x':offset.x=values[0]
  elif track.kind=='_MainTex.offset.y':offset.y=values[0]
 dynamic_instance.offset=offset;dynamic_instance.material.set_shader_parameter('source_offset',Vector2(offset.x,-offset.y))
func get_animation_audit():
 return {'request':current_request,'settled_state':settled_state,'serial':transition_serial,'clip':active_clip.get('name',''),'elapsed':clip_elapsed,'pending':clip_queue.duplicate(),'transitions':transitions.duplicate(true),'playing':not active_clip.is_empty()}
func get_button_texture(state):
 var key=str(state).to_lower()
 if key in ['waiting','enemy','disabled','endturn_waiting']:key='gray'
 if key in ['ready','no_more_plays','endturn_no_more_plays']:key='green'
 if key in ['your_turn','available','endturn_your_turn']:key='yellow'
 return state_textures.get(key,state_textures.get('yellow'))
func get_audit():
 var result=audit.duplicate(true);result.animation_runtime=get_animation_audit();result.native_labels=label_audit.duplicate(true);return result
func v3(d):return Vector3(d.x,d.y,d.z)
func _build_state(state,dynamic=false):
 var vp=SubViewport.new();vp.name='OriginalEndTurn_'+state;vp.size=Vector2i(384,224);vp.transparent_bg=true;vp.own_world_3d=true;vp.msaa_3d=Viewport.MSAA_2X;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(vp);viewports.append(vp)
 var root=Node3D.new();root.scale.z=-1;vp.add_child(root)
 var wanted=[source.endTurnRoot,'-3077616787339791772',source.endTurnMeshNode,'-7261576005060709788','8698471071363183204'];var nodes={}
 for id in wanted:
  var spec
  for n in source.nodes:
   if n.id==id:spec=n;break
  var node=Node3D.new();node.name=spec.name;nodes[id]=node
  if id==source.endTurnRoot:root.add_child(node)
  else:nodes[spec.parent].add_child(node)
  node.position=v3(spec.position);node.quaternion=Quaternion(spec.rotation.x,spec.rotation.y,spec.rotation.z,spec.rotation.w);node.scale=v3(spec.scale)
 for spec in source.labels:
  if spec.role in ['endTurn','enemyTurn']:_build_label(nodes[spec.node],spec,'结束回合' if spec.role=='endTurn' else '对手回合')
 var mesh_node=nodes[source.endTurnMeshNode]
 var state_name={'yellow':'ENDTURN_YOUR_TURN','green':'ENDTURN_NO_MORE_PLAYS','gray':'ENDTURN_WAITING'}[state]
 var offset=Vector2.ZERO
 # No-more-plays clip lacks rotation: source YOUR_TURN identity is preserved, not a guessed flip.
 for entry in source.states:
  if entry.name!=state_name:continue
  for track in entry.tracks:
   if track.node!=source.endTurnMeshNode:continue
   var values=[]
   for channel in track.channels:values.append(channel['keys'][-1]['value'])
   if track.kind=='position':mesh_node.position=Vector3(values[0],values[1],values[2])
   elif track.kind=='rotation':mesh_node.quaternion=Quaternion(values[0],values[1],values[2],values[3])
   elif track.kind=='_MainTex.offset.x':offset.x=values[0]
   elif track.kind=='_MainTex.offset.y':offset.y=values[0]
 var d=JSON.parse_string(FileAccess.get_file_as_string(BASE+'Button_EndTurn.json'));var mesh=ArrayMesh.new();var ps=PackedVector3Array();var uv=PackedVector2Array();var normals=PackedVector3Array()
 for i in range(0,d.vertices.size(),3):ps.append(Vector3(d.vertices[i],d.vertices[i+1],d.vertices[i+2]))
 for i in range(0,d.normals.size(),3):normals.append(Vector3(d.normals[i],d.normals[i+1],d.normals[i+2]))
 for i in range(0,d.uv.size(),2):uv.append(Vector2(d.uv[i],1.0-d.uv[i+1]))
 for surface in d.surfaces:
  var a=[];a.resize(Mesh.ARRAY_MAX);a[Mesh.ARRAY_VERTEX]=ps;a[Mesh.ARRAY_NORMAL]=normals;a[Mesh.ARRAY_TEX_UV]=uv
  var ix=PackedInt32Array(surface.indices)
  for i in range(0,ix.size(),3):
   var h=ix[i+1];ix[i+1]=ix[i+2];ix[i+2]=h
  a[Mesh.ARRAY_INDEX]=ix;mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
 var shader=Shader.new();shader.code='shader_type spatial; render_mode unshaded,cull_back,depth_draw_opaque,fog_disabled; uniform sampler2D source_tex:source_color,filter_linear,repeat_enable; uniform vec2 source_offset; vec3 inv(vec3 c){vec3 target=pow((c+vec3(.055))/1.055,vec3(2.4));vec3 lo=vec3(0);vec3 hi=vec3(1);for(int i=0;i<20;i++){vec3 m=(lo+hi)*.5;vec3 y=m*(m*(m*.305306011+.682171111)+.012522878);vec3 t=step(y,target);lo=mix(lo,m,t);hi=mix(m,hi,t);}return mix((lo+hi)*.5,vec3(0),lessThanEqual(c,vec3(0)));}void fragment(){ALBEDO=inv(texture(source_tex,UV+source_offset).rgb);}'
 var mat=ShaderMaterial.new();mat.shader=shader;mat.set_shader_parameter('source_tex',load(BASE+'Board_EndTurnButton.png'));mat.set_shader_parameter('source_offset',Vector2(offset.x,-offset.y))
 var mi=MeshInstance3D.new();mi.mesh=mesh;mi.material_override=mat;mesh_node.add_child(mi)
 var cam=Camera3D.new();cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.keep_aspect=Camera3D.KEEP_WIDTH;cam.size=2.05;cam.position=Vector3(0,6,0);cam.rotation_degrees=Vector3(-90,0,0);cam.current=true;vp.add_child(cam)
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(0,0,0,0);vp.add_child(env)
 state_textures['dynamic' if dynamic else state]=vp.get_texture()
 if dynamic:dynamic_instance={'viewport':vp,'node':mesh_node,'material':mat,'offset':offset,'source_root':nodes[source.endTurnRoot],'reflection_root':root}

func _build_label(parent,spec,text):
 var advance=0.0
 for ch in text:
  if not glyphs.has(ch) or not glyphs[ch].available:push_error('Missing actual native turn glyph '+ch);return
  advance+=float(glyphs[ch].advance)
 var character_size=float(spec.characterSize)*.01
 var measured_width=advance*.1*character_size
 var measured_height=36.0*1030.0/1024.0*.1*character_size
 # Original ResizeToFit decrement .95, min character size .01; no glyph rectangle guessed.
 var fit_steps=0
 while (measured_width>float(spec.width) or measured_height>float(spec.height)) and character_size>.01 and fit_steps<50:
  character_size=maxf(.01,character_size*.95);fit_steps+=1;measured_width=advance*.1*character_size;measured_height=36.0*1030.0/1024.0*.1*character_size
 var baseline=-36.0*900.0/1024.0+36.0*1030.0/1024.0*.5
 var ps=PackedVector3Array();var uv=PackedVector2Array();var ix=PackedInt32Array();var cursor=0.0
 for ch in text:
  var g=glyphs[ch];var start=ps.size();var points=[Vector2(g.minX,g.minY),Vector2(g.maxX,g.minY),Vector2(g.maxX,g.maxY),Vector2(g.minX,g.maxY)];var corners=[g.uvBottomLeft,g.uvBottomRight,g.uvTopRight,g.uvTopLeft]
  for i in range(4):ps.append(Vector3(cursor+points[i].x-advance*.5,points[i].y+baseline,0)*character_size*.1);uv.append(Vector2(corners[i].x,1.0-corners[i].y))
  for i in [0,1,2,0,2,3]:ix.append(start+i)
  cursor+=g.advance
 var a=[];a.resize(Mesh.ARRAY_MAX);a[Mesh.ARRAY_VERTEX]=ps;a[Mesh.ARRAY_TEX_UV]=uv;a[Mesh.ARRAY_INDEX]=ix
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
 var mat=ShaderMaterial.new();mat.shader=load('res://assets/native_cards/source_glyph_spatial.gdshader');mat.set_shader_parameter('glyph_atlas',glyph_atlas);mat.set_shader_parameter('text_mode',0);mat.set_shader_parameter('text_tint',Color(0,0,0,1));mat.render_priority=20
 var mi=MeshInstance3D.new();mi.name='OriginalCharacterInfo_'+spec.role;mi.mesh=mesh;mi.material_override=mat;parent.add_child(mi)
 if label_audit.size()<2:label_audit.append({'role':spec.role,'text':text,'font_size':36,'character_size':character_size,'fit_steps':fit_steps,'source_node':spec.node,'font_sample':'actual Unity6000.3.10f1 Metal CharacterInfo; not original-client screenshot','source_text_pass':'normal black, no outline/AA','compositing':'Godot text RGB source-alpha over opaque button; viewport silhouette alpha is compatibility, not original full-board target'})

func attach_source_scene(parent:Node3D,source_pose:Transform3D)->bool:
 # Original hierarchy is kept raw Unity; reflection parent applies Z once.
 if dynamic_instance.is_empty() or not is_instance_valid(parent):return false
 var root:Node3D=dynamic_instance.reflection_root
 if root.get_parent()!=parent:root.reparent(parent,false)
 root.transform=Transform3D(Basis(Vector3.RIGHT,Vector3.UP,-Vector3.BACK),Vector3.ZERO)
 dynamic_instance.source_root.transform=source_pose
 _sync_dynamic_viewport_attachment()
 return true

func _sync_dynamic_viewport_attachment():
 # Phone mode moves the actual geometry into the shared scene. Its abandoned
 # texture target has no consumers there; animation still advances normally.
 if dynamic_instance.is_empty():return
 var root=dynamic_instance.get("reflection_root")
 var viewport=dynamic_instance.get("viewport")
 if not is_instance_valid(root) or not is_instance_valid(viewport):return
 var attached:bool=root.get_parent()!=null and root.get_parent()!=viewport
 if attached:
  viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 elif _source_scene_attached:
  # Restore the standalone desktop target if its original geometry returns.
  viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
  settle_draws=maxi(settle_draws,3)
 _source_scene_attached=attached

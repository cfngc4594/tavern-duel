extends RefCounted
const SourceStore=preload('res://original_board/scripts/board_source_store.gd')
## Original formulas, explicit backend/lighting boundary. No arbitrary PBR fallback.
var owner_probe
var routes:Dictionary={}
var animated:Array=[]
var default_textures:Dictionary={}
var lighting_materials:Array=[]
var source_ambient=Color.WHITE
var source_directional_intensity=0.0
var source_light_color=Vector3.ONE
const ROUTES={
 'Hero/Diffuse/Diffuse':'source_diffuse.gdshader',
 'Hero/Diffuse/DiffuseColor':'source_diffuse_color.gdshader',
 'Hero/Diffuse/Diffuse Render Late Split':'source_split.gdshader',
 'Hero/Diffuse/Diffuse Render Late Split Mask':'source_split_mask.gdshader',
 'Hero/FX_Wind_Diffuse':'source_wind.gdshader',
 'Hero/Unlit/Unlit_Transparent2uvScrollMaskScroll':'source_water.gdshader'
}
func setup(probe):
 owner_probe=probe
 var a=probe.config.lighting.ambient_target_raw_rgba
 source_ambient=Color(a.r,a.g,a.b,a.a)
 source_directional_intensity=float(probe.config.lighting.directional_intensity_normal_play_target)
 var c=probe.data.light.data.m_Color
 source_light_color=Vector3(c.r,c.g,c.b)

func register_lighting_material(mat:ShaderMaterial):
 if mat==null or mat.shader==null:return
 for row in lighting_materials:
  if row.material==mat:return
 var names={}
 for u in mat.shader.get_shader_uniform_list():names[str(u.name)]=true
 var row={'material':mat,'ambient':names.has('_UnitySHW'),'directional':names.has('_MainLightColor')}
 lighting_materials.append(row)
 _apply_lighting_to_material(row)

func apply_source_lighting(ambient:Color,energy:float):
 source_ambient=ambient;source_directional_intensity=energy
 for row in lighting_materials:_apply_lighting_to_material(row)

func _apply_lighting_to_material(row:Dictionary):
 # These shader routes are unshaded Godot materials with translated source
 # lighting formulas. Updating the DirectionalLight3D alone has no effect.
 var mat:ShaderMaterial=row.material
 if row.ambient:mat.set_shader_parameter('_UnitySHW',Vector3(source_ambient.r,source_ambient.g,source_ambient.b))
 if row.directional:mat.set_shader_parameter('_MainLightColor',source_light_color*source_directional_intensity)

func get_source_lighting()->Dictionary:
 return {'ambient':source_ambient,'directional_intensity':source_directional_intensity,'registered_materials':lighting_materials.size()}

func close():
 lighting_materials.clear();animated.clear();default_textures.clear();owner_probe=null
func build(key):
 var d=owner_probe.data.materials[key]
 var s=owner_probe.data.shaders[d.shader]
 var record={'source_id':key,'name':d.name,'source_shader':d.shader,'source_shader_name':s.name,'source_shader_sha256':s.source_sha256,'status':'omitted','limitations':[]}
 if not ROUTES.has(s.name):
  record.reason='No verified adapter for this shader yet; renderer explicitly omitted rather than generic fallback.'
  routes[key]=record;owner_probe.audit.materials.append(record);return null
 var mat=ShaderMaterial.new();mat.shader=load('res://original_board/shaders/'+ROUTES[s.name]);mat.resource_name=d.name
 var uniforms={}
 for u in mat.shader.get_shader_uniform_list():uniforms[str(u.name)]=true
 for prop in s.properties:
  var n=str(prop.m_Name)
  if not uniforms.has(n):continue
  var typ=int(prop.m_Type)
  if typ==0 or typ==1:mat.set_shader_parameter(n,Vector4(prop['m_DefValue[0]'],prop['m_DefValue[1]'],prop['m_DefValue[2]'],prop['m_DefValue[3]']))
  elif typ==2 or typ==3:mat.set_shader_parameter(n,float(prop['m_DefValue[0]']))
  elif typ==4:mat.set_shader_parameter(n,_default_texture(prop.m_DefTexture.m_DefaultName))
 for n in d.floats:
  if uniforms.has(n):mat.set_shader_parameter(n,float(d.floats[n]))
 for n in d.ints:
  if uniforms.has(n):mat.set_shader_parameter(n,int(d.ints[n]))
 for n in d.colors:
  if uniforms.has(n):
   var c=d.colors[n];mat.set_shader_parameter(n,Vector4(c.r,c.g,c.b,c.a))
 var bindings=[]
 for row in d.textures:
  if uniforms.has(row.name) and not row.texture.is_empty():
   var tex=_texture(row.texture)
   if tex==null:owner_probe.audit.errors.append('Texture failed '+row.texture);return null
   mat.set_shader_parameter(row.name,tex)
   bindings.append({'slot':row.name,'source_texture':row.texture,'source_settings':owner_probe.data.textures[row.texture].source_settings})
  var st=row.name+'_ST'
  if uniforms.has(st):mat.set_shader_parameter(st,Vector4(row.scale.x,row.scale.y,row.offset.x,row.offset.y))
 # Flat ambient input is a declared compatibility projection of the exact raw Board ambient.
 # Do not claim unity_SH coefficients have been recovered.
 register_lighting_material(mat)
 var g=owner_probe.source_light.global_basis.z.normalized()
 var u=Vector3(g.x,g.y,-g.z)
 mat.set_shader_parameter('_MainLightPosition',Vector4(u.x,u.y,u.z,0.0))
 mat.set_shader_parameter('_GodotToSourceWorld',Transform3D(Basis(Vector3(1,0,0),Vector3(0,1,0),Vector3(0,0,-1)),Vector3.ZERO))
 mat.set_shader_parameter('_UnityLightDataZ',1.0)
 mat.set_shader_parameter('_SourceAdditionalCount',0)
 record.status='translated source opaque formula';record.route=ROUTES[s.name];record.textures=bindings
 record.limitations=['Unshadowed variant; URP shadow atlas/features not reproduced.','Flat ambient RGB mapped into SH.w compatibility input; original evaluated SH probe unknown.','Original main light raw color/intensity; Unity/Godot color bridge not validated against native board pixels.','No additional lights selected in standalone base MOP probe.','Sampler is bilinear/repeat; source sampler settings retained in audit.']
 if s.name=='Hero/FX_Wind_Diffuse':animated.append(mat);record.time='source _Time.x = elapsed/20; original vertex COLOR.r and local-space deformation'
 if s.name=='Hero/Unlit/Unlit_Transparent2uvScrollMaskScroll':
  animated.append(mat);record.status='translated source alpha-blended water formula';record.time='source _Time.x = elapsed/20';record.limitations.append('Source SrcAlpha/OneMinusSrcAlpha RGB; framebuffer alpha behavior and Glow secondary pass not replicated.')
 routes[key]=record;owner_probe.audit.materials.append(record)
 return mat
func _default_texture(name):
 if default_textures.has(name):return default_textures[name]
 var image=Image.create(1,1,false,Image.FORMAT_RGBA8)
 image.fill(Color.BLACK if name=='black' else Color.WHITE)
 var tex=ImageTexture.create_from_image(image);default_textures[name]=tex;return tex
func _texture(key):
 if owner_probe.textures.has(key):return owner_probe.textures[key]
 if not owner_probe.data.textures.has(key):return null
 var d=owner_probe.data.textures[key]
 var image=SourceStore.image_for(owner_probe,str(d.file))
 if image==null or image.is_empty():return null
 var tex=ImageTexture.create_from_image(image);owner_probe.textures[key]=tex;return tex
func advance(seconds):
 for mat in animated:mat.set_shader_parameter('_SourceTime',seconds)

static func _load_source_png(path:String)->Image:
 # Read original PNG bytes from res:// even when packed in an Android PCK.
 # No format conversion, resampling, mip generation or pixel mutation.
 if not FileAccess.file_exists(path):return null
 var image=Image.new()
 if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))!=OK:return null
 return image

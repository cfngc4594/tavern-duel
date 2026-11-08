shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_back, fog_disabled;
// Exact vertex/fragment arithmetic from SphereGlowFresnel blob1/3.
// Godot backend color/additive accumulation bridge is separate from source math.
uniform vec4 _Color=vec4(1.0);
uniform float _ElectricityBrightness=1.0;
uniform mat4 _GodotToSourceWorld=mat4(1.0);
varying float source_fresnel;
vec3 source_backend_inverse(vec3 c) {
 vec3 target=pow((c+vec3(0.055))/1.055,vec3(2.4));
 vec3 lo=vec3(0.0); vec3 hi=vec3(1.0);
 for(int i=0;i<20;i++) {
  vec3 m=(lo+hi)*0.5;
  vec3 y=m*(m*(m*0.305306011+0.682171111)+0.012522878);
  vec3 take=step(y,target);lo=mix(lo,m,take);hi=mix(m,hi,take);
 }
 return mix((lo+hi)*0.5,vec3(0.0),lessThanEqual(c,vec3(0.0)));
}

void vertex() {
 vec3 source_world=(_GodotToSourceWorld*MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 vec3 source_camera=(_GodotToSourceWorld*vec4(CAMERA_POSITION_WORLD,1.0)).xyz;
 // Original uses input local normal directly, not a transformed world normal.
 source_fresnel=clamp(1.0-dot(NORMAL,normalize(source_camera-source_world)),0.0,1.0);
}
void fragment() {
 float facing=1.0-source_fresnel;
 vec4 result=clamp(facing*facing*_Color*_ElectricityBrightness,vec4(0.0),vec4(1.0));
 ALBEDO=source_backend_inverse(clamp(result.rgb*result.a,vec3(0.0),vec3(1.0)));
 ALPHA=0.0;
}

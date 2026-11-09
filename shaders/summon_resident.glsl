#[compute]
#version 450
#extension GL_ARB_gpu_shader_fp64 : require
// Opt-in BlueRays 6590410617251757833 only. CPU retains emission/RNG and
// display curves; checkpoints stay on the global RenderingDevice.
// Match the original FP64 integration clock and float32 Vector3 arithmetic.
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

struct Particle {
 double age; double birth; double life; double cap;
 vec4 position; vec4 velocity; vec4 initial_velocity; vec4 shape;
}; // std430 stride 96; vec4 offsets 32, 48, 64, 80.
struct Display {
 vec4 base; vec4 right; vec4 up; vec4 normal; vec4 color;
}; // std430 stride 80; base.w is the CPU lifetime/stop-time mask.
layout(set=0,binding=0,std430) restrict buffer States { Particle p[]; };
layout(set=0,binding=1,std430) restrict readonly buffer RenderParameters { Display r[]; };
layout(set=0,binding=2,rgba32f) uniform restrict writeonly image2D output_data;
layout(set=0,binding=3,std430) restrict readonly buffer Globals {
 double now; double unused;
 vec4 basis_x; vec4 basis_y; vec4 basis_z;
 uvec4 counts;
} g;

const double STEP=1.0LF/120.0LF;
const double EPSILON=0.00000001LF;

vec3 capped_velocity(vec3 input_velocity,double cap) {
 precise vec3 velocity=input_velocity+vec3(0.0);
 precise float xx=velocity.x*velocity.x;
 precise float yy=velocity.y*velocity.y;
 precise float zz=velocity.z*velocity.z;
 precise float xy=xx+yy;
 precise float xyz=xy+zz;
 // FP64 sqrt then narrow matches CPU sqrtf on the validated device; native
 // GPU float sqrt differed by an ULP and accumulated checkpoint error.
 precise float speed=float(sqrt(double(xyz)));
 if(double(speed)>cap) {
  // dampen=1, but retain lerpf(speed,cap,1) operation order, not cap/speed.
  precise double delta=cap-double(speed);
  precise double weighted=delta*1.0LF;
  precise double limited=double(speed)+weighted;
  precise double factor=limited/double(speed);
  velocity=velocity*float(factor);
 }
 return velocity;
}

void clear_slot(int slot) {
 for(int column=0;column<5;column++)imageStore(output_data,ivec2(column,slot),vec4(0.0));
}

void main() {
 uint i=gl_GlobalInvocationID.x;
 if(i>=g.counts.x)return;
 int slot=int(i);
 precise double until=g.now-p[i].birth;
 if(r[i].base.w<0.5 || until<0.0LF || until>=p[i].life) {
  clear_slot(slot);
  return;
 }
 precise double age=p[i].age;
 precise vec3 position=p[i].position.xyz;
 precise vec3 velocity=p[i].velocity.xyz;
 if(until+EPSILON<age) {
  age=0.0LF;
  position=vec3(0.0);
  velocity=p[i].initial_velocity.xyz;
 }
 // The CPU eligibility check limits life to 10 seconds. Keep a final guard
 // against malformed/non-advancing clocks before entering the GPU loop.
 if(isnan(until) || isinf(until) || isnan(age) || isinf(age) ||
    until-age>10.0LF || age+STEP<=age) {
  clear_slot(slot);
  return;
 }
 while(age+STEP<=until+EPSILON) {
  velocity=capped_velocity(velocity,p[i].cap);
  precise vec3 scaled=velocity*1.0;
  precise vec3 movement=scaled*float(STEP);
  position=position+movement;
  age=age+STEP;
 }
 // Persist only full-step checkpoints, never the render-only fractional step.
 p[i].age=age;
 p[i].position=vec4(position,0.0);
 p[i].velocity=vec4(velocity,0.0);
 precise vec3 display_position=position;
 if(until>age+EPSILON) {
  precise double dt=until-age;
  precise vec3 display_velocity=capped_velocity(velocity,p[i].cap);
  precise vec3 scaled=display_velocity*1.0;
  precise vec3 movement=scaled*float(dt);
  display_position=display_position+movement;
 }
 // Godot Basis.xform is three row dot products, with (x+y)+z order.
 precise vec3 bx=g.basis_x.xyz*display_position.x;
 precise vec3 by=g.basis_y.xyz*display_position.y;
 precise vec3 bz=g.basis_z.xyz*display_position.z;
 precise vec3 xy=bx+by;
 precise vec3 transformed=xy+bz;
 precise vec3 center=r[i].base.xyz+transformed;
 imageStore(output_data,ivec2(0,slot),vec4(center,1.0));
 imageStore(output_data,ivec2(1,slot),r[i].right);
 imageStore(output_data,ivec2(2,slot),r[i].up);
 imageStore(output_data,ivec2(3,slot),r[i].normal);
 imageStore(output_data,ivec2(4,slot),r[i].color);
}

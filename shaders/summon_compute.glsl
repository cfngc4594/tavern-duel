#[compute]
#version 450
#extension GL_ARB_gpu_shader_fp64 : require
// Experimental constant full-step checkpoint kernel. No random/emit/mesh work.
// Float64 scalars preserve the GDScript integration clock/rotation. Vector3
// arithmetic is explicitly float32, with precise intermediates disabling FMA.
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
struct Particle {
 double age; double until; double rotation; double rotation_step;
 double cap; double amount;
 vec4 position; vec4 velocity;
};
layout(set=0,binding=0,std430) restrict buffer Particles { Particle p[]; };
layout(push_constant,std430) uniform Params { uint count; uint pad0; uint pad1; uint pad2; } params;
void main() {
 uint i=gl_GlobalInvocationID.x;
 if(i>=params.count)return;
 const double STEP=1.0LF/120.0LF;
 const double EPSILON=0.00000001LF;
 precise double age=p[i].age;
 precise double rotation=p[i].rotation;
 precise vec3 position=p[i].position.xyz;
 precise vec3 velocity=p[i].velocity.xyz;
 while(age+STEP<=p[i].until+EPSILON) {
  velocity=velocity+vec3(0.0);
  if(p[i].cap>=0.0LF) {
   precise float xx=velocity.x*velocity.x;
   precise float yy=velocity.y*velocity.y;
   precise float zz=velocity.z*velocity.z;
   precise float xy=xx+yy;
   precise float xyz=xy+zz;
   precise float speed=sqrt(xyz);
   if(double(speed)>p[i].cap) {
    precise double delta=p[i].cap-double(speed);
    precise double weighted=delta*p[i].amount;
    precise double limited=double(speed)+weighted;
    precise double factor=limited/double(speed);
    velocity=velocity*float(factor);
   }
  }
  if(p[i].position.w>0.5)rotation=rotation+p[i].rotation_step;
  precise vec3 scaled=velocity*1.0;
  precise vec3 movement=scaled*float(STEP);
  position=position+movement;
  age=age+STEP;
 }
 p[i].age=age;p[i].rotation=rotation;
 p[i].position=vec4(position,0.0);p[i].velocity=vec4(velocity,0.0);
}

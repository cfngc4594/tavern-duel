# Official Godot 4.7 compute API review

The user's objection is justified: our synchronous checkpoint prototype is a
poor real-time integration design, even though it executes valid GPU work and
passes correctness checks. Its slowdown must not be generalized to compute
shaders or to Godot's GPU-resident rendering path.

## What the official documentation actually recommends

- [4.7 compute tutorial](https://docs.godotengine.org/en/4.7/tutorials/shaders/compute_shaders.html#execute-a-compute-shader): immediate sync in the introductory example exists to obtain results immediately. The text recommends allowing 2–3 frames before synchronization for CPU/GPU overlap.
- [4.7 RenderingDevice](https://docs.godotengine.org/en/4.7/classes/class_renderingdevice.html): synchronous buffer readback blocks; asynchronous readback returns later, with frame-queue latency and transfer costs still present. submit/sync are local-device APIs. Global RD is the device drawing the screen; local RD is a secondary device.
- [4.7 RenderingServer](https://docs.godotengine.org/en/4.7/classes/class_renderingserver.html#class-renderingserver-method-call-on-render-thread): global rendering-internal access belongs on the render thread through call_on_render_thread.
- [4.7 Texture2DRD](https://docs.godotengine.org/en/4.7/classes/class_texture2drd.html): a texture created on RD can be consumed directly by materials/meshes.
- [Official Compute Texture demo](https://godotengine.org/asset-library/asset/2764), [current source](https://github.com/godotengine/godot-demo-projects/blob/master/compute/texture/water_plane/water_plane.gd): uses the global device, schedules compute on the render thread, retains/cycles GPU textures and exposes them through Texture2DRD. It does not perform per-frame CPU readback or immediate sync. The current master source is an example, not a claim that it is pinned to our engine build.
- [Compositor documentation](https://docs.godotengine.org/en/latest/tutorials/rendering/compositor.html): render callbacks can insert compute at defined 3D pipeline stages. This is another scheduling option, not permission to assume a post-processing callback is the correct stage for particle geometry.

The 4.7 pages were checked specifically against the installed 4.7.1 API, not
merely inferred from latest documentation. Latest was also consulted and carries
an explicit unstable-version warning.

## Concrete problems in our code

`scripts/summon_compute.gd` creates local RD at line45, packs every eligible batch
at lines96–99, immediately submits/synchronizes at line120, and synchronously
reads it back at line131. This serializes the CPU with many tiny GPU jobs.

`native_summon_particles.gd` then still iterates every particle at line443,
evaluates its rendering state and constructs new vertex/color/UV arrays at
line476, rebuilding ArrayMesh surfaces at line486. We moved a narrow integration
loop, not the remaining expensive CPU-side rendering preparation.

The measured warm phase had 83 dispatches and about 1.8ms of GPU command time,
but 215–229ms CPU bridge time. That evidence is consistent with the API warnings;
it is not evidence that computation on the GPU is inherently unsuitable.

Runtime shader compilation also adds cold initialization cost. A production
version should use imported RDShaderFile/SPIR-V and initialize before the action,
while keeping resource availability validation. That alone would not remove the
warm transfer bottleneck.

## A better next experiment

1. Keep CPU RNG/emission ordering as the reference; upload spawn records once and
   small time/transform/stop commands thereafter. Retain simulation state on GPU.
2. Use the **global** RD on the render thread, not a local RID handed to a material.
   Global-device resources must be created on that same device. Let the engine
   schedule work and resource dependencies; do not call local-only submit/sync.
3. Integrate eligible particles into persistent storage. Write render attributes
   into a float data texture, expose through Texture2DRD, and read it in a vertex
   shader on fixed indexed quads (or a carefully validated instanced mesh).
   Preserve original billboard, stretch, UV, color, transparency/depth and particle
   ordering. Vertex generation must no longer depend on same-frame CPU readback.
4. Read back only in validation/debug runs, asynchronously or after a paused
   deterministic sequence. Compare with the CPU reference and do separate timed
   runs without readback. Resource retirement and per-frame ownership must avoid
   races; a GPU barrier is not a CPU fence.
5. Start with one real eligible source in the battlecry scene, default off with
   CPU fallback. Validate appearance/action timing before expanding coverage.

Simply deleting sync is incorrect because the current CPU mesh builder immediately
needs those results. Replacing readback with async without redesign would add
particle-frame lag or consume stale state. A worker thread can overlap independent
CPU work but cannot remove that same-frame dependency. Delaying effects by 2–3
frames is not an acceptable invisible optimization here.

GPU residence is not an automatic speedup guarantee: the kernel is currently
small, other CPU systems remain, FP64 support varies, and packing all rendering
attributes may uncover further cost. No precision/quality reduction is assumed.
The original Forward+/Compatibility color differences also remain a separate
issue. This investigation changes no production rendering path or system setting.

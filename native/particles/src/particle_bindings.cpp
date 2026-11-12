#include "particle_kernel.hpp"

#include <godot_cpp/core/class_db.hpp>

void TavernParticleKernel::_bind_methods() {
    godot::ClassDB::bind_method(
            godot::D_METHOD("advance", "raw", "particles", "indices", "now", "compatibility_basis",
                    "gravity", "emitter_frame", "emitter_motion", "plane_samples", "constant_steps"),
            &TavernParticleKernel::advance, DEFVAL(false));
    godot::ClassDB::bind_method(
            godot::D_METHOD("trail_geometry", "raw", "particles", "indices", "states", "now", "frame", "motion",
                    "axes", "camera", "focal_max", "clamp_max"),
            &TavernParticleKernel::trail_geometry);
}

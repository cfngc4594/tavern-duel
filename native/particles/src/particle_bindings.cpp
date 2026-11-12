#include "particle_kernel.hpp"

#include <godot_cpp/core/class_db.hpp>

void TavernParticleKernel::_bind_methods() {
    godot::ClassDB::bind_method(
            godot::D_METHOD("advance", "raw", "particles", "indices", "now", "compatibility_basis",
                    "gravity", "emitter_frame", "emitter_motion", "plane_samples", "constant_steps"),
            &TavernParticleKernel::advance, DEFVAL(false));
}

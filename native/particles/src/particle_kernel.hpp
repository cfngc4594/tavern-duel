#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/basis.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/transform3d.hpp>

class TavernParticleKernel : public godot::RefCounted {
    GDCLASS(TavernParticleKernel, godot::RefCounted)

protected:
    static void _bind_methods();

public:
    godot::Array advance(const godot::Dictionary &raw, const godot::Array &particles,
            const godot::Array &indices, double now, const godot::Basis &compatibility_basis,
            const godot::Vector3 &gravity, const godot::Transform3D &emitter_frame,
            const godot::Basis &emitter_motion, const godot::Array &plane_samples, bool constant_steps);

    godot::Array trail_geometry(const godot::Dictionary &raw, const godot::Array &particles,
            const godot::Array &indices, const godot::Dictionary &states, double now,
            const godot::Transform3D &frame, const godot::Basis &motion, const godot::Basis &axes,
            const godot::Transform3D &camera, double focal_max, double clamp_max);
};

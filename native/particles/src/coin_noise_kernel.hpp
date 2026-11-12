#pragma once

#include <array>
#include <cstdint>

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>

class TavernCoinNoiseKernel : public godot::RefCounted {
    GDCLASS(TavernCoinNoiseKernel, godot::RefCounted)

    std::array<uint8_t, 512> permutation{};
    std::array<godot::Vector3, 16> gradients{};
    bool configured = false;

    bool derivative(const godot::Vector3 &position, double frequency, godot::Vector2 &result) const;

protected:
    static void _bind_methods();

public:
    bool configure(const godot::PackedInt32Array &permutation_values, const godot::PackedVector3Array &gradient_values);
    godot::Variant curl(const godot::Vector3 &position, const godot::Vector3 &offset, double scroll, double frequency) const;
};

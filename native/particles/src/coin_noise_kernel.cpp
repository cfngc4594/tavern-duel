#include "coin_noise_kernel.hpp"

#include <algorithm>
#include <cmath>

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/vector3i.hpp>

using godot::Vector2;
using godot::Vector3;
using godot::Vector3i;

void TavernCoinNoiseKernel::_bind_methods() {
    godot::ClassDB::bind_method(godot::D_METHOD("configure", "permutation", "gradients"), &TavernCoinNoiseKernel::configure);
    godot::ClassDB::bind_method(godot::D_METHOD("curl", "position", "offset", "scroll", "frequency"), &TavernCoinNoiseKernel::curl);
}

bool TavernCoinNoiseKernel::configure(const godot::PackedInt32Array &permutation_values, const godot::PackedVector3Array &gradient_values) {
    configured = false;
    if (permutation_values.size() != 512 || gradient_values.size() != 16) {
        return false;
    }
    for (int i = 0; i < 512; ++i) {
        const int value = permutation_values[i];
        if (value < 0 || value > 255) {
            return false;
        }
        permutation[i] = static_cast<uint8_t>(value);
    }
    for (int i = 0; i < 16; ++i) {
        if (!gradient_values[i].is_finite()) {
            return false;
        }
        gradients[i] = gradient_values[i];
    }
    configured = true;
    return true;
}

bool TavernCoinNoiseKernel::derivative(const Vector3 &position, double frequency, Vector2 &result) const {
    // The reference's Vector2/3 operations round to real_t, while scalar
    // GDScript expressions evaluate in double. Keep these boundaries explicit.
    const Vector3 q = position * static_cast<godot::real_t>(frequency);
    constexpr double cell_limit = 2147483648.0;
    if (!q.is_finite() || std::abs(double(q.x)) >= cell_limit || std::abs(double(q.y)) >= cell_limit || std::abs(double(q.z)) >= cell_limit) {
        return false;
    }
    const Vector3i cell(static_cast<int32_t>(std::floor(q.x)), static_cast<int32_t>(std::floor(q.y)), static_cast<int32_t>(std::floor(q.z)));
    const Vector3 t = q - Vector3(cell.x, cell.y, cell.z);
    Vector3 u;
    Vector3 du;
    for (int axis = 0; axis < 3; ++axis) {
        const double value = t[axis];
        u[axis] = value * value * value * (value * (value * 6.0 - 15.0) + 10.0);
        du[axis] = 30.0 * value * value * (value * (value - 2.0) + 1.0);
    }
    Vector2 gradient;
    for (int x = 0; x < 2; ++x) {
        const int ix = permutation[(cell.x & 255) + x];
        const double wx = x ? double(u.x) : 1.0 - double(u.x);
        for (int y = 0; y < 2; ++y) {
            const int iy = permutation[ix + (cell.y & 255) + y];
            const double wy = y ? double(u.y) : 1.0 - double(u.y);
            for (int z = 0; z < 2; ++z) {
                const Vector3 &g = gradients[permutation[iy + (cell.z & 255) + z] & 15];
                const double dot = g.dot(t - Vector3(x, y, z));
                const double wz = z ? double(u.z) : 1.0 - double(u.z);
                gradient.x = double(gradient.x) + (double(g.x) * wx + dot * double(du.x) * (x ? 1.0 : -1.0)) * wy * wz;
                gradient.y = double(gradient.y) + (double(g.y) * wy + dot * double(du.y) * (y ? 1.0 : -1.0)) * wx * wz;
            }
        }
    }
    result = gradient * static_cast<godot::real_t>(frequency);
    return true;
}

godot::Variant TavernCoinNoiseKernel::curl(const Vector3 &position, const Vector3 &offset, double scroll, double frequency) const {
    if (!configured || !std::isfinite(frequency)) {
        return godot::Variant();
    }
    const Vector3 p = position + offset;
    const double f = std::max(frequency, 0.000001);
    Vector2 a;
    Vector2 b;
    Vector2 c;
    if (!derivative(Vector3(p.z, p.y, double(p.x) + scroll), f, a) ||
            !derivative(Vector3(double(p.x) + 100.0, p.z, double(p.y) + scroll), f, b) ||
            !derivative(Vector3(p.y, double(p.x) + 100.0, double(p.z) + scroll), f, c)) {
        return godot::Variant();
    }
    return Vector3(double(c.x) - b.y, double(a.x) - c.y, double(b.x) - a.y);
}

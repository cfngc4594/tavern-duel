#include "particle_kernel.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <limits>
#include <vector>

#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace {
using namespace godot;

constexpr double step = 1.0 / 120.0;
constexpr double epsilon = 0.00000001;
constexpr double infinity = std::numeric_limits<double>::infinity();

double lerp(double from, double to, double weight) {
    return from + (to - from) * weight;
}

double number(const Variant &value, double fallback = 0.0) {
    if (value.get_type() == Variant::NIL) {
        return fallback;
    }
    if (value.get_type() == Variant::STRING) {
        const String string = String(value).to_lower();
        if (string == "infinity" || string == "+infinity" || string == "inf" || string == "+inf") {
            return infinity;
        }
        if (string == "-infinity" || string == "-inf") {
            return -infinity;
        }
        return string.to_float();
    }
    return value;
}

bool enabled(const Dictionary &module) {
    return module.get("enabled", false);
}

struct Key {
    double time;
    double value;
    double in_slope;
    double out_slope;
    bool in_step;
    bool out_step;
};

bool read_keys(const Dictionary &curve, std::vector<Key> &out) {
    const Array keys = curve.get("m_Curve", Array());
    out.reserve(keys.size());
    for (int64_t index = 0; index < keys.size(); ++index) {
        const Dictionary key = keys[index];
        if (int64_t(key.get("weightedMode", 0)) != 0) {
            return false;
        }
        const double in_slope = number(key.get("inSlope", key.get("inTangent", 0.0)));
        const double out_slope = number(key.get("outSlope", key.get("outTangent", 0.0)));
        out.push_back({number(key.get("time", 0.0)), number(key.get("value", 0.0)),
                in_slope, out_slope,
                std::isinf(in_slope) || int64_t(key.get("inTangentInfinity", 0)) != 0,
                std::isinf(out_slope) || int64_t(key.get("outTangentInfinity", 0)) != 0});
    }
    return true;
}

double sample_keys(const std::vector<Key> &keys, double time) {
    if (keys.empty()) {
        return 1.0;
    }
    if (time <= keys.front().time) {
        return keys.front().value;
    }
    if (time >= keys.back().time) {
        return keys.back().value;
    }
    for (size_t index = 1; index < keys.size(); ++index) {
        const Key &a = keys[index - 1];
        const Key &b = keys[index];
        if (time > b.time) {
            continue;
        }
        const double span = b.time - a.time;
        if (span <= 0.0) {
            return b.value;
        }
        if (a.out_step || b.in_step) {
            return a.value;
        }
        const double t = (time - a.time) / span;
        const double t2 = t * t;
        const double t3 = t2 * t;
        return (2 * t3 - 3 * t2 + 1) * a.value + (t3 - 2 * t2 + t) * span * a.out_slope
                + (-2 * t3 + 3 * t2) * b.value + (t3 - t2) * span * b.in_slope;
    }
    return keys.back().value;
}

struct Curve {
    int mode = 0;
    double high = 0.0;
    double low = 0.0;
    std::vector<Key> min_keys;
    std::vector<Key> max_keys;

    bool load(const Dictionary &curve) {
        mode = curve.get("minMaxState", 0);
        high = number(curve.get("scalar", 0.0));
        low = number(curve.get("minScalar", high));
        switch (mode) {
            case 0:
            case 3:
                return true;
            case 1:
                return read_keys(curve.get("maxCurve", Dictionary()), max_keys);
            case 2:
                return read_keys(curve.get("maxCurve", Dictionary()), max_keys)
                        && read_keys(curve.get("minCurve", Dictionary()), min_keys);
            default:
                return false;
        }
    }

    double sample(double time, double mix) const {
        switch (mode) {
            case 1:
                return sample_keys(max_keys, time) * high;
            case 2:
                return lerp(sample_keys(min_keys, time) * high, sample_keys(max_keys, time) * high, mix);
            case 3:
                return lerp(low, high, mix);
            default:
                return high;
        }
    }

    bool constant_zero() const { return mode == 0 && high == 0.0; }

    bool finite_constant() const {
        return std::isfinite(high) && (mode == 0 || (mode == 3 && std::isfinite(low)));
    }
};

using Curves = std::array<Curve, 3>;
constexpr std::array<const char *, 3> axes = {"x", "y", "z"};

bool read_components(Curves &out, const Dictionary &module, const std::array<const char *, 3> &names = axes) {
    for (size_t axis = 0; axis < names.size(); ++axis) {
        if (!out[axis].load(module.get(names[axis], Dictionary()))) {
            return false;
        }
    }
    return true;
}

Vector3 sample_components(const Curves &curves, double time, const Vector3 &mix) {
    return {real_t(curves[0].sample(time, mix.x)), real_t(curves[1].sample(time, mix.y)), real_t(curves[2].sample(time, mix.z))};
}

bool constant_zero(const Curves &curves) {
    return std::all_of(curves.begin(), curves.end(), [](const Curve &curve) { return curve.constant_zero(); });
}

bool finite_constants(const Curves &curves) {
    return std::all_of(curves.begin(), curves.end(), [](const Curve &curve) { return curve.finite_constant(); });
}

struct Plane {
    Vector3 normal;
    Vector3 position;
};

struct Plan {
    Curves linear, orbital, orbital_offset, force, axis_limit;
    Curve radial, speed_modifier, inherit, gravity, magnitude_limit, drag, rotation, speed_rotation;
    Curve collision_size, collision_dampen, collision_bounce, collision_loss;
    bool velocity_on = false, velocity_world = false, zero_linear = false, zero_spatial = false;
    bool inherit_on = false, force_on = false, force_world = false, force_random = false;
    bool limit_on = false, separate_axes = false, drag_size = false, drag_speed = false;
    bool rotation_on = false, speed_rotation_on = false, world = false;
    bool size_on = false, interior_collisions = true;
    double dampen = 0.0, speed_min = 0.0, speed_span = 1.0;
    double radius_scale = 1.0, min_kill = 0.0, max_kill = infinity;
    Basis compatibility;
    Vector3 gravity_vector;
    Transform3D frame;
    Basis emitter_motion;
    std::vector<Plane> planes;

    bool supports_constant_steps() const {
        return planes.empty() && !inherit_on && !speed_rotation_on
                && (!velocity_on || (finite_constants(linear) && speed_modifier.finite_constant() && zero_spatial))
                && (!limit_on || (!separate_axes && magnitude_limit.finite_constant() && drag.constant_zero()))
                && (!force_on || finite_constants(force)) && gravity.finite_constant()
                && (!rotation_on || rotation.finite_constant());
    }

    bool load(const Dictionary &raw) {
        world = int64_t(raw.get("moveWithTransform", 0)) == 1;
        const Dictionary velocity = raw.get("VelocityModule", Dictionary());
        velocity_on = enabled(velocity);
        velocity_world = velocity.get("inWorldSpace", false);
        speed_modifier.high = 1.0;
        if (velocity_on && (!read_components(linear, velocity)
                    || !read_components(orbital, velocity, {"orbitalX", "orbitalY", "orbitalZ"})
                    || !read_components(orbital_offset, velocity, {"orbitalOffsetX", "orbitalOffsetY", "orbitalOffsetZ"})
                    || !radial.load(velocity.get("radial", Dictionary()))
                    || (velocity.has("speedModifier") && !speed_modifier.load(velocity["speedModifier"])))) {
            return false;
        }
        zero_linear = constant_zero(linear);
        zero_spatial = constant_zero(orbital) && radial.constant_zero();

        const Dictionary inherited = raw.get("InheritVelocityModule", Dictionary());
        inherit_on = enabled(inherited) && world && int64_t(inherited.get("m_Mode", 0)) == 0;
        const Dictionary forcing = raw.get("ForceModule", Dictionary());
        force_on = enabled(forcing);
        force_world = forcing.get("inWorldSpace", false);
        force_random = forcing.get("randomizePerFrame", false);
        const Dictionary initial = raw.get("InitialModule", Dictionary());
        if ((inherit_on && !inherit.load(inherited.get("m_Curve", Dictionary())))
                || (force_on && !read_components(force, forcing))
                || !gravity.load(initial.get("gravityModifier", Dictionary()))) {
            return false;
        }

        const Dictionary limit = raw.get("ClampVelocityModule", Dictionary());
        limit_on = enabled(limit);
        separate_axes = limit.get("separateAxis", false);
        drag_size = limit.get("multiplyDragByParticleSize", false);
        drag_speed = limit.get("multiplyDragByParticleVelocity", false);
        dampen = std::clamp(number(limit.get("dampen", 0.0)), 0.0, 1.0);
        if (limit_on && (!(separate_axes ? read_components(axis_limit, limit)
                                        : magnitude_limit.load(limit.get("magnitude", Dictionary())))
                    || !drag.load(limit.get("drag", Dictionary())))) {
            return false;
        }

        const Dictionary spinning = raw.get("RotationModule", Dictionary());
        const Dictionary by_speed = raw.get("RotationBySpeedModule", Dictionary());
        rotation_on = enabled(spinning);
        speed_rotation_on = enabled(by_speed);
        const Dictionary range = by_speed.get("range", Dictionary());
        speed_min = number(range.get("x", 0.0));
        speed_span = std::max(number(range.get("y", 1.0)) - speed_min, epsilon);
        if ((rotation_on && !rotation.load(spinning.get("curve", Dictionary())))
                || (speed_rotation_on && !speed_rotation.load(by_speed.get("curve", Dictionary())))) {
            return false;
        }

        if (planes.empty()) {
            return true;
        }
        const Dictionary size = raw.get("SizeModule", Dictionary());
        const Dictionary collision = raw.get("CollisionModule", Dictionary());
        size_on = enabled(size);
        radius_scale = number(collision.get("radiusScale", 1.0));
        interior_collisions = collision.get("interiorCollisions", true);
        min_kill = number(collision.get("minKillSpeed", 0.0));
        max_kill = number(collision.get("maxKillSpeed", infinity));
        return (!size_on || collision_size.load(size.get("curve", Dictionary())))
                && collision_dampen.load(collision.get("m_Dampen", Dictionary()))
                && collision_bounce.load(collision.get("m_Bounce", Dictionary()))
                && collision_loss.load(collision.get("m_EnergyLossOnCollision", Dictionary()));
    }
};

struct State {
    double age;
    Vector3 position;
    Vector3 velocity;
    double rotation;
    Vector3 render_velocity;
    double kill_age = infinity;
    double collision_loss = 0.0;
    int64_t collision_hits = 0;
};

// Reuse the String variants across the batch. Literal lookups otherwise
// allocate and convert the same keys for each particle and draw state.
struct ParticleKeys {
    const Variant birth = "birth", life = "life", size = "size", rotation = "rotation";
    const Variant limit_mix = "limit_mix", rotation_mix = "rotation_mix", gravity_mix = "gravity_mix";
    const Variant inherit_mix = "inherit_mix", size_mix = "size_mix", velocity_mix = "velocity_mix", force_mix = "force_mix";
    const Variant velocity = "velocity", inherited_velocity = "inherited_velocity", shape_point = "shape_point";
    const Variant start = "start", motion_basis = "motion_basis";
    const Variant sim_age = "sim_age", displacement = "displacement", sim_velocity = "sim_velocity";
    const Variant sim_rotation = "sim_rotation", sim_render_velocity = "sim_render_velocity";
    const Variant kill_age = "kill_age", collision_loss = "collision_loss", collision_hits = "collision_hits";
    const Variant age = "age", position = "position", render_velocity = "render_velocity";
};

struct Particle {
    double life;
    double size;
    double rotation;
    double limit_mix;
    double rotation_mix;
    double gravity_mix;
    double inherit_mix;
    double size_mix;
    Vector3 velocity;
    Vector3 velocity_mix;
    Vector3 force_mix;
    Vector3 inherited_velocity;
    Vector3 shape_point;
    Vector3 start;
    Basis motion;

    Particle(const Dictionary &p, const ParticleKeys &key, const Plan &plan, double lifetime, bool rewind) :
            life(lifetime), size(plan.limit_on || !plan.planes.empty() ? double(p[key.size]) : 0.0),
            rotation(rewind ? double(p[key.rotation]) : 0.0),
            limit_mix(plan.limit_on || !plan.planes.empty() ? double(p[key.limit_mix]) : 0.0),
            rotation_mix(plan.rotation_on || plan.speed_rotation_on ? double(p[key.rotation_mix]) : 0.0),
            gravity_mix(plan.gravity.mode != 0 ? double(p[key.gravity_mix]) : 0.0),
            inherit_mix(plan.inherit_on ? double(p[key.inherit_mix]) : 0.0),
            size_mix(plan.size_on ? double(p[key.size_mix]) : 0.0),
            velocity(rewind ? Vector3(p[key.velocity]) : Vector3()),
            velocity_mix(plan.velocity_on ? Vector3(p[key.velocity_mix]) : Vector3()),
            force_mix(plan.force_on ? Vector3(p[key.force_mix]) : Vector3()),
            inherited_velocity(plan.inherit_on ? Vector3(p[key.inherited_velocity]) : Vector3()),
            shape_point(!plan.zero_spatial || !plan.planes.empty() ? Vector3(p[key.shape_point]) : Vector3()),
            start(plan.world && !plan.planes.empty() ? Vector3(p[key.start]) : Vector3()),
            motion(plan.velocity_world || plan.force_world || plan.inherit_on || !plan.gravity.constant_zero()
                            || (plan.world && !plan.planes.empty())
                    ? Basis(p[key.motion_basis])
                    : Basis()) {}
};

Vector3 linear_velocity(const Plan &plan, const Particle &p, double time) {
    if (!plan.velocity_on) {
        return {};
    }
    const double determinant = plan.velocity_world ? p.motion.determinant() : 1.0;
    if (plan.zero_linear && std::isfinite(determinant) && std::abs(determinant) > epsilon) {
        return {};
    }
    const Vector3 sample = sample_components(plan.linear, time, p.velocity_mix);
    return plan.velocity_world ? p.motion.inverse().xform(plan.compatibility.xform(sample)) : sample;
}

Vector3 spatial_velocity(const Plan &plan, const Particle &p, const Vector3 &displacement, double time) {
    if (!plan.velocity_on || plan.zero_spatial) {
        return {};
    }
    const Vector3 omega = sample_components(plan.orbital, time, p.velocity_mix);
    const double radial = plan.radial.sample(time, p.velocity_mix.x);
    if (omega.is_zero_approx() && std::abs(radial) < epsilon) {
        return {};
    }
    const Vector3 offset = sample_components(plan.orbital_offset, time, p.velocity_mix);
    if (plan.velocity_world) {
        const Basis to_source = plan.compatibility.inverse() * p.motion;
        const Vector3 relative = to_source.xform(p.shape_point + displacement) - offset;
        return to_source.inverse().xform(omega.cross(relative) + relative.normalized() * real_t(radial));
    }
    const Vector3 relative = p.shape_point + displacement - offset;
    return omega.cross(relative) + relative.normalized() * real_t(radial);
}

Vector3 inherited_velocity(const Plan &plan, const Particle &p, double time) {
    return plan.inherit_on ? p.motion.inverse().xform(p.inherited_velocity) * real_t(plan.inherit.sample(time, p.inherit_mix)) : Vector3();
}

Vector3 force_mix(const Vector3 &seed, int64_t step_index) {
    Vector3 result;
    for (int axis = 0; axis < 3; ++axis) {
        int64_t value = (int64_t(double(seed[axis]) * 2147483647.0) + std::max<int64_t>(0, step_index) * 104729 + (axis + 1) * 15485863) & 0x7fffffff;
        value = ((value ^ (value >> 16)) * 1103515245 + 12345) & 0x7fffffff;
        value = ((value ^ (value >> 13)) * 1103515245 + 12345) & 0x7fffffff;
        result[axis] = real_t(double(value) / 2147483648.0);
    }
    return result;
}

Vector3 acceleration(const Plan &plan, const Particle &p, double time, int64_t step_index) {
    Vector3 result;
    if (plan.force_on) {
        result = sample_components(plan.force, time, plan.force_random ? force_mix(p.force_mix, step_index) : p.force_mix);
        if (plan.force_world) {
            result = p.motion.inverse().xform(plan.compatibility.xform(result));
        }
    }
    const double gravity = plan.gravity.sample(time, p.gravity_mix);
    if (std::abs(gravity) > epsilon) {
        result += p.motion.inverse().xform(plan.compatibility.xform(plan.gravity_vector) * real_t(gravity));
    }
    return result;
}

void resolve_collisions(const Plan &plan, const Particle &p, const Vector3 &previous, State &next, double time) {
    if (plan.planes.empty()) {
        return;
    }
    const Basis &motion = plan.world ? p.motion : plan.emitter_motion;
    const Vector3 origin = plan.world ? p.start : plan.frame.xform(p.shape_point);
    const Vector3 old_center = origin + motion.xform(previous);
    Vector3 center = origin + motion.xform(next.position);
    Vector3 velocity = motion.xform(next.velocity);
    const double size = plan.size_on ? p.size * plan.collision_size.sample(time, p.size_mix) : p.size;
    const double radius = std::abs(size) * 0.5
            * std::max(motion.get_column(0).length(), std::max(motion.get_column(1).length(), motion.get_column(2).length()))
            * plan.radius_scale;
    for (const Plane &plane : plan.planes) {
        const double distance = plane.normal.dot(center - plane.position);
        if (distance >= radius || plane.normal.dot(velocity) >= 0.0) {
            continue;
        }
        const double old_distance = plane.normal.dot(old_center - plane.position);
        if (old_distance < -radius && !plan.interior_collisions) {
            continue;
        }
        center += plane.normal * real_t(radius - distance);
        const double dampen = std::clamp(plan.collision_dampen.sample(time, p.limit_mix), 0.0, 1.0);
        const double bounce = plan.collision_bounce.sample(time, p.limit_mix);
        const Vector3 normal_velocity = plane.normal * velocity.dot(plane.normal);
        velocity = (velocity - normal_velocity) * real_t(1.0 - dampen) - normal_velocity * real_t(bounce);
        next.collision_loss += std::clamp(plan.collision_loss.sample(time, p.limit_mix), 0.0, 1.0);
        next.kill_age = std::min(next.kill_age, p.life * std::max(0.0, 1.0 - next.collision_loss));
        const double speed = velocity.length();
        if (speed < plan.min_kill || speed > plan.max_kill) {
            next.kill_age = next.age;
        }
        ++next.collision_hits;
    }
    const Basis inverse = motion.inverse();
    next.position = inverse.xform(center - origin);
    const Vector3 delta = inverse.xform(velocity) - next.velocity;
    next.velocity += delta;
    next.render_velocity += delta;
}

void integrate(const Plan &plan, const Particle &p, State &state, double dt) {
    const double previous_time = state.age / p.life;
    const double time = std::clamp((state.age + dt) / p.life, 0.0, 1.0);
    Vector3 velocity = state.velocity;
    velocity += linear_velocity(plan, p, time) - linear_velocity(plan, p, previous_time);
    velocity += inherited_velocity(plan, p, time) - inherited_velocity(plan, p, previous_time);
    velocity += acceleration(plan, p, time, int64_t(std::floor((state.age + epsilon) / step))) * real_t(dt);
    if (plan.limit_on) {
        const double amount = 1.0 - std::pow(1.0 - plan.dampen, dt / step);
        if (plan.separate_axes) {
            for (size_t axis = 0; axis < axes.size(); ++axis) {
                const double cap = std::max(0.0, plan.axis_limit[axis].sample(time, p.limit_mix));
                const double component = velocity[axis];
                velocity[axis] = real_t(lerp(component, std::clamp(component, -cap, cap), amount));
            }
        } else {
            const double cap = std::max(0.0, plan.magnitude_limit.sample(time, p.limit_mix));
            const double speed = velocity.length();
            if (speed > cap) {
                velocity *= real_t(lerp(speed, cap, amount) / speed);
            }
        }
        double drag = std::max(0.0, plan.drag.sample(time, p.limit_mix));
        if (drag > 0.0) {
            if (plan.drag_size) {
                drag *= p.size;
            }
            if (plan.drag_speed) {
                drag *= velocity.length();
            }
            velocity *= real_t(std::max(0.0, 1.0 - drag * dt));
        }
    }
    if (plan.rotation_on) {
        state.rotation += plan.rotation.sample(time, p.rotation_mix) * dt;
    }
    if (plan.speed_rotation_on) {
        const double speed_time = std::clamp((velocity.length() - plan.speed_min) / plan.speed_span, 0.0, 1.0);
        state.rotation += plan.speed_rotation.sample(speed_time, p.rotation_mix) * dt;
    }
    const double multiplier = plan.velocity_on ? plan.speed_modifier.sample(time, p.velocity_mix.x) : 1.0;
    const Vector3 previous = state.position;
    state.render_velocity = (velocity + spatial_velocity(plan, p, previous, time)) * real_t(multiplier);
    state.position += state.render_velocity * real_t(dt);
    state.velocity = velocity;
    state.age += dt;
    resolve_collisions(plan, p, previous, state, time);
}

void advance_constant_steps(const Plan &plan, const Particle &p, State &state, double until) {
    if (state.age + step > until + epsilon) {
        return;
    }

    const bool random_force = plan.force_on && plan.force_random;
    const Vector3 acceleration_step = random_force ? Vector3() : acceleration(plan, p, 0.0, 0) * real_t(step);
    const Vector3 additive = linear_velocity(plan, p, 0.0);
    const Vector3 additive_delta = additive - additive;
    const double multiplier = plan.speed_modifier.sample(0.0, p.velocity_mix.x);
    const double cap = std::max(0.0, plan.magnitude_limit.sample(0.0, p.limit_mix));
    const double amount = 1.0 - std::pow(1.0 - plan.dampen, 1.0);
    const double rotation_step = plan.rotation.sample(0.0, p.rotation_mix) * step;

    while (state.age + step <= until + epsilon) {
        if (plan.velocity_on) {
            state.velocity += additive_delta;
            state.velocity += Vector3();
        }
        if (random_force) {
            const double time = std::clamp((state.age + step) / p.life, 0.0, 1.0);
            const int64_t step_index = int64_t(std::floor((state.age + epsilon) / step));
            state.velocity += acceleration(plan, p, time, step_index) * real_t(step);
        } else {
            state.velocity += acceleration_step;
        }
        if (plan.limit_on) {
            const double speed = state.velocity.length();
            if (speed > cap) {
                state.velocity *= real_t(lerp(speed, cap, amount) / speed);
            }
        }
        if (plan.rotation_on) {
            state.rotation += rotation_step;
        }
        state.render_velocity = plan.velocity_on ? (state.velocity + Vector3()) * real_t(multiplier) : state.velocity;
        state.position += state.render_velocity * real_t(step);
        state.age += step;
    }
}

Dictionary display_state(const State &state, const ParticleKeys &key) {
    Dictionary result;
    result[key.age] = state.age;
    result[key.position] = state.position;
    result[key.velocity] = state.velocity;
    result[key.rotation] = state.rotation;
    result[key.render_velocity] = state.render_velocity;
    result[key.kill_age] = state.kill_age;
    result[key.collision_loss] = state.collision_loss;
    result[key.collision_hits] = state.collision_hits;
    return result;
}

struct Sample {
    Dictionary particle;
    double age;
    double lifetime;
};

struct GradientTrack {
    std::array<double, 8> times{};
    std::array<Color, 8> colors{};
    int count = 0;

    bool load(const Dictionary &gradient, bool alpha) {
        count = gradient.get(alpha ? "m_NumAlphaKeys" : "m_NumColorKeys", 0);
        if (count < 0 || count > int(colors.size())) {
            return false;
        }
        for (int index = 0; index < count; ++index) {
            const String suffix = String::num_int64(index);
            const Dictionary color = gradient.get("key" + suffix, Dictionary());
            colors[index] = Color(number(color.get("r", 1.0)), number(color.get("g", 1.0)),
                    number(color.get("b", 1.0)), number(color.get("a", 1.0)));
            times[index] = number(gradient.get(String(alpha ? "atime" : "ctime") + suffix, 0)) / 65535.0;
        }
        return true;
    }

    Color sample(double time, bool hold) const {
        if (count == 0) {
            return Color(1, 1, 1, 1);
        }
        int index = 0;
        while (index + 1 < count && time >= times[index + 1]) {
            ++index;
        }
        const int next = std::min(index + 1, count - 1);
        const double span = times[next] - times[index];
        const double weight = !hold && span > 0.0 ? std::clamp((time - times[index]) / span, 0.0, 1.0) : 0.0;
        return colors[index].lerp(colors[next], weight);
    }
};

Dictionary advance_one(const Plan &plan, const ParticleKeys &key, Sample &sample, bool constant_steps) {
    Dictionary &data = sample.particle;
    const double age = sample.age;
    const double previous_age = data[key.sim_age];
    const bool rewind = age + epsilon < previous_age;
    const Particle particle(data, key, plan, sample.lifetime, rewind);
    State state;
    if (rewind) {
        const Vector3 velocity = particle.velocity + linear_velocity(plan, particle, 0.0)
                + inherited_velocity(plan, particle, 0.0);
        state = {0.0, {}, velocity, particle.rotation, velocity + spatial_velocity(plan, particle, {}, 0.0)};
    } else {
        state = {previous_age, data[key.displacement], data[key.sim_velocity], data[key.sim_rotation],
                data[key.sim_render_velocity], data[key.kill_age], data[key.collision_loss], data[key.collision_hits]};
    }
    if (constant_steps) {
        advance_constant_steps(plan, particle, state, age);
    } else {
        while (state.age + step <= age + epsilon) {
            integrate(plan, particle, state, step);
        }
    }

    // Seek commits whole steps only. Fractional motion is for this draw.
    data[key.sim_age] = state.age;
    data[key.displacement] = state.position;
    data[key.sim_velocity] = state.velocity;
    data[key.sim_rotation] = state.rotation;
    data[key.sim_render_velocity] = state.render_velocity;
    data[key.kill_age] = state.kill_age;
    data[key.collision_loss] = state.collision_loss;
    data[key.collision_hits] = state.collision_hits;
    if (age > state.age + epsilon) {
        integrate(plan, particle, state, age - state.age);
    }
    return display_state(state, key);
}

} // namespace

godot::Array TavernParticleKernel::advance(const Dictionary &raw, const Array &particles, const Array &indices,
        double now, const Basis &compatibility_basis, const Vector3 &gravity,
        const Transform3D &emitter_frame, const Basis &emitter_motion, const Array &plane_samples, bool constant_steps) {
    Plan plan;
    plan.compatibility = compatibility_basis;
    plan.gravity_vector = gravity;
    plan.frame = emitter_frame;
    plan.emitter_motion = emitter_motion;
    for (int64_t i = 0; i < plane_samples.size(); ++i) {
        const Dictionary plane = plane_samples[i];
        plan.planes.push_back({plane["normal"], plane["position"]});
    }
    if (!std::isfinite(now) || !plan.load(raw) || (constant_steps && !plan.supports_constant_steps())) {
        return {};
    }

    const ParticleKeys key;
    std::vector<Sample> batch;
    batch.reserve(indices.size());
    // Check the entire batch before mutating a single particle.
    for (int64_t i = 0; i < indices.size(); ++i) {
        const int64_t index = indices[i];
        if (index < 0 || index >= particles.size()) {
            return {};
        }
        const Variant &value = particles[index];
        if (value.get_type() != Variant::DICTIONARY) {
            return {};
        }
        const Dictionary particle = value;
        const double age = now - double(particle[key.birth]);
        const double previous_age = particle[key.sim_age];
        const double lifetime = particle[key.life];
        if (!std::isfinite(age) || age < 0.0 || !std::isfinite(previous_age)
                || !(lifetime > 0.0) || age > lifetime) {
            return {};
        }
        batch.push_back({particle, age, lifetime});
    }
    Array states;
    states.resize(indices.size());
    for (size_t i = 0; i < batch.size(); ++i) {
        states[i] = advance_one(plan, key, batch[i], constant_steps);
    }
    return states;
}

godot::Array TavernParticleKernel::trail_geometry(const Dictionary &raw, const Array &particles,
        const Array &indices, const Dictionary &states, double now, const Transform3D &frame,
        const Basis &motion, const Basis &axes, const Transform3D &camera, double focal_max, double clamp_max) {
    const Dictionary size_module = raw.get("SizeModule", Dictionary());
    const Dictionary color_module = raw.get("ColorModule", Dictionary());
    const Dictionary size_curve = size_module.get("curve", Dictionary());
    const Dictionary gradient = color_module.get("gradient", Dictionary());
    const Dictionary keys = gradient.get("maxGradient", Dictionary());
    Curve size;
    GradientTrack rgb;
    GradientTrack alpha;
    if (!enabled(size_module) || !enabled(color_module) || int(gradient.get("minMaxState", -1)) != 1
            || !size.load(size_curve) || !rgb.load(keys, false) || !alpha.load(keys, true)) {
        return {};
    }
    const bool hold = int(keys.get("m_Mode", 0)) == 1;
    const Vector3 right = axes.get_column(0);
    const Vector3 up = axes.get_column(1);
    const Vector3 normal = axes.get_column(2);
    const double scale_x = motion.get_column(0).length();
    const double scale_y = motion.get_column(1).length();
    const int64_t vertex_count = indices.size() * 4;
    PackedVector3Array vertices;
    PackedVector3Array normals;
    PackedColorArray colors;
    PackedVector2Array uvs;
    vertices.resize(vertex_count);
    normals.resize(vertex_count);
    colors.resize(vertex_count);
    uvs.resize(vertex_count);
    Vector3 *vertex_data = vertices.ptrw();
    Vector3 *normal_data = normals.ptrw();
    Color *color_data = colors.ptrw();
    Vector2 *uv_data = uvs.ptrw();
    constexpr std::array<Vector2, 4> corners = {Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)};
    const ParticleKeys fields;
    const StringName shape_point("shape_point");
    const StringName source_color("color");
    const StringName size_mix("size_mix");
    for (int64_t slot = 0; slot < indices.size(); ++slot) {
        const int64_t index = indices[slot];
        if (index < 0 || index >= particles.size()) {
            return {};
        }
        const Dictionary p = particles[index];
        const Dictionary state = states.get(index, Dictionary());
        const double age = now - double(p[fields.birth]);
        const double life = p[fields.life];
        if (state.is_empty() || age < 0.0 || age >= life || age >= double(state[fields.kill_age])
                || int(state[fields.collision_hits]) != 0) {
            return {};
        }
        const double normalized = age / life;
        const double width = double(p[fields.size]) * size.sample(normalized, p[size_mix]);
        const Vector3 center = frame.xform(Vector3(p[shape_point])) + motion.xform(Vector3(state[fields.position]));
        const double rotation = state[fields.rotation];
        const Vector3 x = right.rotated(normal, rotation) * width * scale_x * 0.5;
        const Vector3 y = up.rotated(normal, rotation) * width * scale_y * 0.5;
        // Use the same conservative bound as the script. Leave the entire
        // batch to the script if a particle needs an exact screen projection.
        const double radius = double(x.length()) + double(y.length());
        const Vector3 local_center = camera.xform_inv(center);
        const double depth = -local_center.z;
        const double off_axis = std::max(std::abs(local_center.x), std::abs(local_center.y));
        if (depth <= radius || !(focal_max * radius * (1.0 + off_axis / depth) / (depth - radius) < clamp_max * 0.98)) {
            return {};
        }
        const Color tint = rgb.sample(normalized, hold);
        const Color color = Color(p[source_color]) * Color(tint.r, tint.g, tint.b, alpha.sample(normalized, hold).a);
        const int64_t start = slot * 4;
        vertex_data[start] = center + (-x + y);
        vertex_data[start + 1] = center + (x + y);
        vertex_data[start + 2] = center + (x - y);
        vertex_data[start + 3] = center + (-x - y);
        for (int64_t corner = 0; corner < 4; ++corner) {
            normal_data[start + corner] = normal;
            color_data[start + corner] = color;
            uv_data[start + corner] = corners[corner];
        }
    }
    return Array::make(vertices, normals, colors, uvs);
}
